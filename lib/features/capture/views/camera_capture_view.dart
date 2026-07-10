import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/playful.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/capture/capture.dart';
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
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
    } else {
      // Start recording
      try {
        if (_isCameraInitialized && _cameraController != null) {
          await _cameraController!.startVideoRecording();
        }
        if (mounted) {
          setState(() {
            _isRecording = true;
          });
        }
      } catch (e) {
        debugPrint('Error starting video recording: $e');
      }
    }
  }

  Future<void> _sendToCircle() async {
    final captionText = _captureCaption.text.trim();
    ref.read(uploadProvider.notifier).startUpload(
      captionText,
      const [
        Color(0xFF8E2DE2),
        Color(0xFF4A00E0),
      ], // Beautiful violet/purple gradient for dynamic captures
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

  String _getUploadStageMessage(UploadStatus status) {
    switch (status) {
      case UploadStatus.preparing:
        return 'Preparing your memory...';
      case UploadStatus.validating:
        return 'Checking your upload...';
      case UploadStatus.compressing:
        return 'Compressing video...';
      case UploadStatus.generatingThumbnail:
        return 'Generating preview...';
      case UploadStatus.uploading:
        return 'Uploading your memory...';
      case UploadStatus.waitingForResponse:
        return 'Finalizing...';
      default:
        return 'Uploading...';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UploadState>(uploadProvider, (previous, next) async {
      if (next.status == UploadStatus.succeeded) {
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
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memory posted successfully to your Circle!'),
          ),
        );

        ref.read(uploadProvider.notifier).reset();
        context.go('/capture');
      } else if (next.status == UploadStatus.failed) {
        if (next.isRetryable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${next.errorMessage}'),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: kYellow,
                onPressed: () {
                  _sendToCircle();
                },
              ),
              duration: const Duration(seconds: 8),
            ),
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
          final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: dark ? kBlack : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Upload in Progress',
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Text(
                'Your memory is still uploading. Leaving will cancel the upload. Leave anyway?',
                style: TextStyle(
                  color: dark
                      ? kCream.withValues(alpha: 0.8)
                      : kCharcoal.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Continue Upload',
                    style: TextStyle(
                      color: dark ? kYellow : kBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(uploadProvider.notifier).cancelUpload();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'Leave Anyway',
                    style: TextStyle(
                      color: dark
                          ? kCream.withValues(alpha: 0.6)
                          : kCharcoal.withValues(alpha: 0.6),
                    ),
                  ),
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
                          _overlayProfileSettingsButton(
                            onTap: () => _showProfileSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Move camera frame higher
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
                                child: _overlayIconButton(
                                  icon: Icons.flip_camera_android_rounded,
                                  onTap: _switchCamera,
                                ),
                              ),

                            // Centre: capture button or send button
                            _hasRecording
                                ? _sendToCircleButton(dark)
                                : BouncyTap(
                                    onTap: _toggleRecording,
                                    pressedScale: 0.9,
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
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8,
                                                    ), // stop recording red square
                                              ),
                                            )
                                          : Container(
                                              alignment: Alignment.center,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: kYellow,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
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
                  return Positioned(
                    left: index * 14.0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                        color: f.avatar,
                      ),
                      child: Center(
                        child: Text(
                          f.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            if (friendsCount > 3) ...[
              Text(
                '+${friendsCount - 3} ',
                style: const TextStyle(
                  color: kYellow,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Memories",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (friendsCount > 0)
                  Text(
                    '$friendsCount friends posted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 8,
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
  Widget _overlayIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  // Profile settings icon button for top-right (single icon instead of twin user icon)
  Widget _overlayProfileSettingsButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
    );
  }

  // Message icon button for bottom-right with unread badge overlay
  Widget _overlayCircleMessageButton({
    required VoidCallback onTap,
    required int unreadCount,
  }) {
    final displayCount = unreadCount > 9 ? '9+' : '$unreadCount';
    return BouncyTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
            size: 28,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                child: Text(
                  displayCount,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
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
          color: kYellow,
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
                  CircularProgressIndicator(
                    value: uploadState.status == UploadStatus.uploading
                        ? uploadState.progress
                        : null,
                    color: kBlack,
                    strokeWidth: 3,
                  ),
                  const Icon(Icons.close_rounded, color: kBlack, size: 20),
                ],
              )
            : const Icon(Icons.send_rounded, color: kBlack, size: 32),
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
          Container(color: const Color(0xFF151515)),

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
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.waitingForResponse;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = size * 0.20;
        final borderRadius = BorderRadius.circular(radius);

        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(2), // 2px border outline
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: kYellow.withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: kYellow.withValues(alpha: 0.18),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 2),
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
                                  ? CircularProgressIndicator(
                                      color: dark ? kYellow : kBlack,
                                    )
                                  : const Text(
                                      'Mock Video Preview\n(Looping Simulation)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
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
                            const SizedBox(height: 12),
                            Text(
                              'No camera detected',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
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
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: dark ? kYellow : kBlack,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Starting camera...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. REC overlay indicator if recording
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          const PulseRedDot(),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REC',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. Caption editor overlay
                  if (_hasRecording && _captureCaptionOpen)
                    _captureCaptionEditor(),

                  // 5. Upload progress overlay
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: dark ? kBlack : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (dark ? Colors.white : kCharcoal)
                                    .withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getUploadStageMessage(uploadState.status),
                                  style: TextStyle(
                                    color: dark ? kCream : kCharcoal,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (uploadState.status ==
                                    UploadStatus.uploading) ...[
                                  LinearProgressIndicator(
                                    value: uploadState.progress,
                                    color: kYellow,
                                    backgroundColor:
                                        (dark ? Colors.white : kCharcoal)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${(uploadState.progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: dark ? kYellow : kBlack,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ] else ...[
                                  LinearProgressIndicator(
                                    color: kYellow,
                                    backgroundColor:
                                        (dark ? Colors.white : kCharcoal)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ],
                              ],
                            ),
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
          child: TextField(
            controller: _captureCaption,
            autofocus: true,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: _captureCaptionSize,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Add caption',
              hintStyle: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
