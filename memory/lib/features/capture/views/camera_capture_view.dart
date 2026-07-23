import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/circle/circle.dart';

List<CameraDescription>? _globalCameras;

Future<void> preloadCameras() async {
  if (_globalCameras != null && _globalCameras!.isNotEmpty) return;
  try {
    _globalCameras = await availableCameras();
  } catch (e) {
    debugPrint('Error preloading cameras: $e');
  }
}

class CameraCaptureView extends ConsumerStatefulWidget {
  const CameraCaptureView({super.key});

  @override
  ConsumerState<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends ConsumerState<CameraCaptureView>
    with WidgetsBindingObserver {
  final _captureCaption = TextEditingController();
  bool _hasRecording = false;
  bool _captureCaptionOpen = false;
  Offset _captureCaptionOffset = const Offset(78, 250);
  double _captureCaptionSize = 24;

  // Media controllers and status
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  VideoPlayerController? _videoPlayerController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _recordedVideoPath;
  int _selectedCameraIndex = 0;
  bool _isInitializing = false;
  int _lastInitMs = 0;
  FlashMode _flashMode = FlashMode.off;

  // Recording elapsed-time counter and hard cap.
  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int _maxRecordSeconds = 30;

  // Hold-to-record race guards: the finger can lift before startVideoRecording
  // resolves, so a stop requested mid-start is deferred until start completes.
  bool _startingRecording = false;
  bool _stopAfterStart = false;

  // Brief success checkmark shown after a memory finishes posting.
  bool _showSuccessTick = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Prevent concurrent initializations and rapid re-inits
    if (_isInitializing) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInitMs < 300) return; // debounce quick calls
    _lastInitMs = now;

    _isInitializing = true;
    debugPrint('[Camera] init start at ${DateTime.now().toIso8601String()}');
    try {
      if (_globalCameras == null || _globalCameras!.isEmpty) {
        _globalCameras = await availableCameras();
      }
      _cameras = _globalCameras ?? [];

      if (_cameras.isNotEmpty) {
        if (_selectedCameraIndex >= _cameras.length) {
          _selectedCameraIndex = 0;
        }

        // If an existing controller exists, ensure it's disposed first
        if (_cameraController != null) {
          final old = _cameraController!;
          _cameraController = null;
          try {
            await old.dispose();
          } catch (e) {
            debugPrint('[Camera] error disposing old controller: $e');
          }
        }

        final controller = CameraController(
          _cameras[_selectedCameraIndex],
          ResolutionPreset.medium,
          enableAudio: true,
        );
        _cameraController = controller;
        await controller.initialize();

        if (mounted && _cameraController == controller) {
          setState(() {
            _isCameraInitialized = true;
          });
          try {
            await controller.setFlashMode(_flashMode);
          } catch (e) {
            debugPrint('[Camera] error setting initial flash mode: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[Camera] Error initializing camera: $e');
    } finally {
      _isInitializing = false;
      debugPrint('[Camera] init end at ${DateTime.now().toIso8601String()}');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty || _isRecording || _hasRecording) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = nextIndex;
    });

    if (_cameraController != null) {
      final oldController = _cameraController!;
      _cameraController = null;
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('[Camera] error disposing old controller during switch: $e');
      }
    }

    // Small delay to let the underlying driver finish teardown (helps some devices)
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await _initCamera();
    } catch (e) {
      debugPrint('[Camera] Error switching camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _cameraController == null) return;
    final nextMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _cameraController!.setFlashMode(nextMode);
      if (mounted) {
        setState(() {
          _flashMode = nextMode;
        });
      }
    } catch (e) {
      debugPrint('[Camera] Error toggling flash mode: $e');
    }
  }

  Future<void> _disposeCameraController() async {
    if (_cameraController == null) return;
    final c = _cameraController!;
    _cameraController = null;
    setState(() {
      _isCameraInitialized = false;
    });
    try {
      await c.dispose();
      debugPrint(
        '[Camera] disposed controller at ${DateTime.now().toIso8601String()}',
      );
    } catch (e) {
      debugPrint('[Camera] error disposing controller: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _captureCaption.dispose();
    // best-effort dispose; we don't await here because dispose() cannot be async
    try {
      _cameraController?.dispose();
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }
    try {
      _videoPlayerController?.dispose();
    } catch (e) {
      debugPrint('Error disposing video player: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera on pause/inactive to avoid holding surfaces when backgrounded
    // and re-init on resume.
    debugPrint('[Camera] lifecycle state: $state');
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // dispose camera to free hardware quickly
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      // Re-init camera if needed
      if ((_cameraController == null || !_isCameraInitialized) &&
          !_isInitializing) {
        // Small delay to avoid racing with system resume
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _initCamera();
        });
      }
    }
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isRecording) {
        t.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      if (_recordSeconds >= _maxRecordSeconds) {
        t.cancel();
        _stopRecording(); // auto-stop at the 30s cap
      }
    });
  }

  String _fmtDuration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  // Hold-to-record: pointer down starts, pointer up/cancel stops.
  Future<void> _startRecording() async {
    if (_isRecording || _hasRecording || _startingRecording) return;
    _startingRecording = true;
    try {
      if (_isCameraInitialized && _cameraController != null) {
        await _cameraController!.startVideoRecording();
      }
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
        _startRecordTimer();
      }
    } catch (e) {
      debugPrint('Error starting video recording: $e');
    } finally {
      _startingRecording = false;
      // If the finger lifted while we were still starting, honour it now.
      if (_stopAfterStart) {
        _stopAfterStart = false;
        _stopRecording();
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      // Released before startVideoRecording resolved; defer the stop.
      if (_startingRecording) _stopAfterStart = true;
      return;
    }
    _recordTimer?.cancel();
    try {
      final XFile? file;
      if (_isCameraInitialized && _cameraController != null) {
        file = await _cameraController!.stopVideoRecording();
      } else {
        file = null;
      }

      String? finalPath;
      if (file != null) {
        final tempDir = await getTemporaryDirectory();
        finalPath =
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await file.saveTo(finalPath);
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _hasRecording = true;
          _captureCaptionOpen = true;
          _recordedVideoPath = finalPath;
        });

        if (finalPath != null) {
          final controller = VideoPlayerController.file(File(finalPath));
          _videoPlayerController = controller;
          try {
            await controller.initialize();
            if (mounted && _videoPlayerController == controller) {
              await controller.setLooping(true);
              await controller.play();
              setState(() {});
            } else {
              controller.dispose();
            }
          } catch (e) {
            debugPrint('Error playing preview video: $e');
            controller.dispose();
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  // Discard the captured clip and return to the live camera to retake.
  void _discardRecording() {
    _recordTimer?.cancel();
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    if (_recordedVideoPath != null) {
      try {
        final f = File(_recordedVideoPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (e) {
        debugPrint('Error deleting discarded recording: $e');
      }
    }
    setState(() {
      _hasRecording = false;
      _isRecording = false;
      _recordedVideoPath = null;
      _captureCaptionOpen = false;
      _captureCaption.clear();
      _captureCaptionOffset = const Offset(78, 250);
      _captureCaptionSize = 24;
    });
  }

  Future<void> _sendToCircle() async {
    final captionText = _captureCaption.text.trim();
    ref
        .read(uploadProvider.notifier)
        .startUpload(
          captionText,
          MemoryColors.captureGradient,
          videoPath: _recordedVideoPath,
        );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfilePanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UploadState>(uploadProvider, (previous, next) async {
      if (next.status == UploadStatus.succeeded) {
        // Show a success checkmark briefly before clearing the composer.
        setState(() => _showSuccessTick = true);
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted || !context.mounted) return;

        // Success cleanup
        if (_recordedVideoPath != null) {
          try {
            final file = File(_recordedVideoPath!);
            if (file.existsSync()) {
              file.deleteSync();
              debugPrint(
                'Local media file deleted after confirmed upload success: $_recordedVideoPath',
              );
            }
          } catch (e) {
            debugPrint('Failed to delete temporary video file: $e');
          }
        }

        _videoPlayerController?.pause();
        _videoPlayerController?.dispose();
        _videoPlayerController = null;

        setState(() {
          _hasRecording = false;
          _isRecording = false;
          _recordedVideoPath = null;
          _captureCaptionOpen = false;
          _captureCaption.clear();
          _captureCaptionOffset = const Offset(78, 250);
          _captureCaptionSize = 24;
          _showSuccessTick = false;
        });

        showAppMessage(context, 'Memory posted successfully to your Circle!');

        ref.read(uploadProvider.notifier).reset();
        context.go('/capture');
      } else if (next.status == UploadStatus.failed) {
        if (next.isRetryable) {
          MemorySnackBar.show(
            context,
            'Upload failed: ${next.errorMessage}',
            tone: MemorySnackTone.error,
            duration: const Duration(seconds: 8),
            actionLabel: 'Retry',
            onAction: _sendToCircle,
          );
        } else {
          showAppError(context, 'Failed to post memory: ${next.errorMessage}');
        }
      } else if (next.status == UploadStatus.cancelled) {
        showAppMessage(context, 'Upload cancelled.');
      }
    });

    final dark = ref.watch(isDarkProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final chatState = ref.watch(chatProvider);
    final unreadCount = chatState.unreadNotifications;

    final uploadState = ref.watch(uploadProvider);
    final isUploading =
        uploadState.status == UploadStatus.preparing ||
        uploadState.status == UploadStatus.validating ||
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.waitingForResponse;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -300) context.go('/feed');
      },
      child: PopScope(
        canPop: !isUploading,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final leave = await MemoryDialog.show<bool>(
            context: context,
            builder: (ctx) => MemoryDialog(
              title: 'Upload in Progress',
              dark: dark,
              message:
                  'Your memory is still uploading. Leaving will cancel the upload. Leave anyway?',
              actions: [
                MemoryDialogAction(
                  label: 'Continue Upload',
                  isPrimary: true,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                MemoryDialogAction(
                  label: 'Leave Anyway',
                  onPressed: () {
                    ref.read(uploadProvider.notifier).cancelUpload();
                    Navigator.of(ctx).pop(true);
                  },
                ),
              ],
            ),
          );
          if (leave == true && context.mounted) {
            context.go('/feed');
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _captureReflectionBackground(),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    12, // Tighter top padding
                    28,
                    12 + bottomPad, // Tighter bottom padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top header row: Profile settings button on the right
                      Row(
                        children: [
                          const Spacer(),
                          MemoryIconButton(
                            icon: Icons.person_rounded,
                            semanticLabel: 'Profile and settings',
                            color: Colors.white,
                            iconSize: 28,
                            onPressed: () => _showProfileSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: MemorySpacing.md,
                      ), // Move camera frame higher
                      // Camera card preview (not full screen) with taller 3:4.3 ratio
                      Center(
                        child: AspectRatio(
                          aspectRatio:
                              3 / 4.3, // Increased height slightly from 3 / 4
                          child: _capturePreview(),
                        ),
                      ),
                      const Spacer(
                        flex: 2,
                      ), // Spacing between camera and capture controls (pushed higher)
                      // Bottom controls row: Flip camera on left, Capture in center, Message icon on right
                      SizedBox(
                        width: double.infinity,
                        height: 82,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Flip camera - bottom left
                            if (!_hasRecording &&
                                !_isRecording &&
                                _cameras.length > 1)
                              Positioned(
                                left: 8,
                                child: MemoryIconButton(
                                  icon: Icons.flip_camera_android_rounded,
                                  semanticLabel: 'Switch camera',
                                  color: Colors.white,
                                  iconSize: 28,
                                  onPressed: _switchCamera,
                                ),
                              ),

                            // Retake (discard) - bottom left, once a clip exists
                            if (_hasRecording && !isUploading)
                              Positioned(
                                left: 8,
                                child: MemoryIconButton(
                                  icon: Icons.close_rounded,
                                  semanticLabel: 'Retake',
                                  color: Colors.white,
                                  iconSize: 28,
                                  onPressed: _discardRecording,
                                ),
                              ),

                            // Centre: capture button or send button
                            _hasRecording
                                ? _sendToCircleButton(dark)
                                : Listener(
                                    // Hold to record; release stops. Listener
                                    // (raw pointer) avoids the gesture arena so
                                    // finger drift won't cancel the recording.
                                    onPointerDown: (_) => _startRecording(),
                                    onPointerUp: (_) => _stopRecording(),
                                    onPointerCancel: (_) => _stopRecording(),
                                    child: AnimatedScale(
                                      scale: _isRecording ? 0.92 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      child: Container(
                                        width: 82,
                                        height: 82,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors
                                              .transparent, // Transparent gap
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            width: 4, // 4px white border
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(
                                          6,
                                        ), // minimal space/gap between white border and inner button
                                        child: _isRecording
                                            ? Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape
                                                      .circle, // circular stop button
                                                ),
                                              )
                                            : Container(
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: MemoryColors.accent,
                                                ),
                                                child: Image.asset(
                                                  'assets/images/memory-logo.png',
                                                  width: 38,
                                                  height: 38,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),

                            // Message icon button (opens Circle screen) - bottom right
                            if (!_hasRecording && !_isRecording)
                              Positioned(
                                right: 8,
                                child: _overlayCircleMessageButton(
                                  onTap: () => context.go('/circle'),
                                  unreadCount: unreadCount,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(
                        flex: 3,
                      ), // Spacing below capture button (increased to move memories pill lower)
                      // Memories button in a pill below the capture button
                      if (!_hasRecording && !_isRecording)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _memoriesPillButton(
                                onTap: () => context.go('/feed'),
                              ),
                              const SizedBox(height: 5),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withValues(alpha: 0.82),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for memories pill button below capture button
  Widget _memoriesPillButton({required VoidCallback onTap}) {
    final activeMemories = ref.watch(feedMemoriesProvider);
    // Find unique authors who posted (excluding self is typical, but we can list active friends)
    final Map<String, MemoryItem> uniqueFriends = {};
    for (final m in activeMemories) {
      if (m.person.isNotEmpty) {
        uniqueFriends[m.person] = m;
      }
    }
    final friendsList = uniqueFriends.values.toList();
    final friendsCount = friendsList.length;

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MemorySpacing.xxl,
          vertical: MemorySpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(MemoryRadius.pill),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              // Provide a finite width calculated from friends Count to prevent unbounded Stack exception
              width: (friendsCount > 3 ? 3 : friendsCount) * 14.0 + 8.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(friendsCount > 3 ? 3 : friendsCount, (
                  index,
                ) {
                  final f = friendsList[index];
                  final photoUrl = f.avatarUrl;
                  return Positioned(
                    left: index * 14.0,
                    child: Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black, // ring between overlapping avatars
                      ),
                      child: MemoryAvatar(
                        radius: 9.5,
                        dark: true,
                        imageUrl: (photoUrl == null || photoUrl.isEmpty)
                            ? null
                            : formatImageUrl(photoUrl),
                        initial: f.initial,
                        background: f.avatar,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: MemorySpacing.md),
            if (friendsCount > 3) ...[
              Text(
                '+${friendsCount - 3} ',
                style: MemoryTypography.buttonCompact.copyWith(
                  color: MemoryColors.accent,
                ),
              ),
              const SizedBox(width: MemorySpacing.xs),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Memories",
                  style: MemoryTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (friendsCount > 0)
                  Text(
                    '$friendsCount friends posted',
                    style: MemoryTypography.micro.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper for icon buttons overlaid on the camera preview
  /// The messages button, with the only count-bearing badge in the app: from
  /// the camera the user cannot see the inbox, so the number is the signal.
  Widget _overlayCircleMessageButton({
    required VoidCallback onTap,
    required int unreadCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MemoryIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          semanticLabel: unreadCount > 0
              ? 'Messages, $unreadCount unread'
              : 'Messages',
          color: Colors.white,
          iconSize: 28,
          onPressed: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            // The badge already announces itself through the button's label.
            child: ExcludeSemantics(
              child: MemoryBadge(dark: true, count: unreadCount),
            ),
          ),
      ],
    );
  }

  Widget _sendToCircleButton(bool dark) {
    final uploadState = ref.watch(uploadProvider);
    final isUploading =
        uploadState.status == UploadStatus.preparing ||
        uploadState.status == UploadStatus.validating ||
        uploadState.status == UploadStatus.compressing ||
        uploadState.status == UploadStatus.generatingThumbnail ||
        uploadState.status == UploadStatus.queued ||
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.waitingForResponse;

    return BouncyTap(
      onTap: isUploading
          ? () => ref.read(uploadProvider.notifier).cancelUpload()
          : _sendToCircle,
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MemoryColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isUploading
            ? Stack(
                alignment: Alignment.center,
                children: [
                  MemoryLoading(
                    size: 36,
                    value: uploadState.status == UploadStatus.uploading
                        ? uploadState.progress
                        : null,
                    color: MemoryColors.ink,
                  ),
                  const Icon(
                    Icons.close_rounded,
                    color: MemoryColors.ink,
                    size: 20,
                  ),
                ],
              )
            : const Icon(Icons.send_rounded, color: MemoryColors.ink, size: 32),
      ),
    );
  }

  Widget _captureReflectionBackground() {
    final isRecording = _isRecording;
    final blurVal = isRecording ? 22.0 : 16.0;
    final opacityVal = isRecording ? 0.25 : 0.15;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Duplicate camera/reflection visual basis
        if (_isCameraInitialized && _cameraController != null)
          Transform.scale(
            scale: 1.20,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.height ?? 1080,
                height: _cameraController!.value.previewSize?.width ?? 1920,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          Container(color: MemoryColors.inkRaised),

        // Dark overlay and blur filter combo
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
          child: Container(
            color: Colors.black.withValues(alpha: 1.0 - opacityVal),
          ),
        ),

        // 60% Vignette/dark gradient overlay to limit adaptive brightness and ensure control contrast
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.60),
              ],
              center: Alignment.center,
              radius: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _capturePreview() {
    final dark = ref.watch(isDarkProvider);
    final uploadState = ref.watch(uploadProvider);
    final isUploading =
        uploadState.status == UploadStatus.preparing ||
        uploadState.status == UploadStatus.validating ||
        uploadState.status == UploadStatus.compressing ||
        uploadState.status == UploadStatus.generatingThumbnail ||
        uploadState.status == UploadStatus.queued ||
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.waitingForResponse;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = size * 0.20;
        final borderRadius = BorderRadius.circular(radius);

        final yellowProgress = _isRecording ? (_recordSeconds / _maxRecordSeconds).clamp(0.0, 1.0) : 0.0;

        // The preview container with animated yellow progress border during recording
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: _isRecording ? MemoryColors.accent : Colors.transparent,
              width: 3.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius > 3.5 ? radius - 3.5 : radius),
            child: GestureDetector(
              onTap: _hasRecording
                  ? () => setState(() => _captureCaptionOpen = true)
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Live camera preview, video preview playback, or fallback
                  if (_hasRecording)
                    _videoPlayerController != null &&
                            _videoPlayerController!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoPlayerController!.value.size.width,
                              height: _videoPlayerController!.value.size.height,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          )
                        : Container(
                            color: Colors.black,
                            child: Center(
                              child: _recordedVideoPath != null
                                  ? MemoryLoading(
                                      size: 24,
                                      color: dark
                                          ? MemoryColors.accent
                                          : MemoryColors.ink,
                                    )
                                  : Text(
                                      'Mock Video Preview\n(Looping Simulation)',
                                      textAlign: TextAlign.center,
                                      style: MemoryTypography.titleMedium
                                          .copyWith(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                            ),
                          )
                  else if (_isCameraInitialized && _cameraController != null)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width:
                            _cameraController!.value.previewSize?.height ??
                            1080,
                        height:
                            _cameraController!.value.previewSize?.width ?? 1920,
                        child: CameraPreview(_cameraController!),
                      ),
                    )
                  else if (_cameras.isEmpty)
                    // Fallback for emulators with no camera hardware
                    Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 48,
                            ),
                            const SizedBox(height: MemorySpacing.xl),
                            Text(
                              'No camera detected',
                              style: MemoryTypography.bodyLarge.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Premium loader while initializing
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MemoryLoading(
                              size: 36,
                              color: dark
                                  ? MemoryColors.accent
                                  : MemoryColors.ink,
                            ),
                            const SizedBox(height: MemorySpacing.gutter),
                            Text(
                              'Starting camera...',
                              style: MemoryTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Yellow border progress animation along camera frame edge during 30s recording
                  if (_isRecording)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CameraBorderPainter(
                            progress: yellowProgress,
                            borderRadius: radius,
                          ),
                        ),
                      ),
                    ),

                  // 3. Flash toggle icon button at the bottom-right of the camera frame
                  if (!_hasRecording && !_isRecording && _isCameraInitialized && _cameraController != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: MemoryIconButton(
                        icon: _flashMode == FlashMode.torch
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        semanticLabel: 'Toggle flash',
                        color: _flashMode == FlashMode.torch
                            ? MemoryColors.accent
                            : Colors.white,
                        iconSize: 24,
                        onPressed: _toggleFlash,
                      ),
                    ),

                  // 4. Caption editor overlay
                  if (_hasRecording && _captureCaptionOpen)
                    _captureCaptionEditor(),

                  // 5. Minimal upload overlay: a spinner while posting, then a
                  // brief checkmark once the memory is confirmed posted.
                  if (isUploading || _showSuccessTick)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: Center(
                          child: _showSuccessTick
                              ? Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: MemoryColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: MemoryColors.ink,
                                    size: 40,
                                  ),
                                )
                              : MemoryLoading(
                                  size: 44,
                                  value:
                                      uploadState.status ==
                                          UploadStatus.uploading
                                      ? uploadState.progress
                                      : null,
                                  color: dark
                                      ? MemoryColors.accent
                                      : Colors.white,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _captureCaptionEditor() {
    return Positioned(
      left: _captureCaptionOffset.dx,
      top: _captureCaptionOffset.dy,
      child: GestureDetector(
        onScaleUpdate: (details) => setState(() {
          _captureCaptionOffset += details.focalPointDelta;
          _captureCaptionSize = (_captureCaptionSize * details.scale).clamp(
            16,
            42,
          );
        }),
        child: SizedBox(
          width: 210,
          child: MemoryInlineField(
            controller: _captureCaption,
            hint: 'Add caption',
            autofocus: true,
            maxLines: 2,
            textAlign: TextAlign.center,
            // The caption is pinch-resizable, so its size is state.
            style: MemoryTypography.mediaCaption.copyWith(
              color: Colors.white,
              fontSize: _captureCaptionSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _CameraBorderPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final contour = metrics.first;
    final totalLength = contour.length;

    // Start path at top-center (x = width / 2, y = 0), which is at 12.5% (0.125 * totalLength)
    final startOffset = totalLength * 0.125;
    final extractLength = totalLength * progress.clamp(0.0, 1.0);

    final extractPath = Path();
    // Counter-clockwise / right to left travel along the rounded rectangle
    for (double i = 0; i < extractLength; i += 1.0) {
      final distance = (startOffset - i + totalLength) % totalLength;
      final tangent = contour.getTangentForOffset(distance);
      if (tangent != null) {
        if (i == 0) {
          extractPath.moveTo(tangent.position.dx, tangent.position.dy);
        } else {
          extractPath.lineTo(tangent.position.dx, tangent.position.dy);
        }
      }
    }

    final paint = Paint()
      ..color = MemoryColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CameraBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius;
  }
}
