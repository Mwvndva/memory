import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import '../../core/error_handler.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/circles_repository.dart';
import '../../models/user_profile.dart';
import '../circle/circle_views.dart';

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
    with WidgetsBindingObserver, TickerProviderStateMixin {
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

  // Recording timer
  final Stopwatch _recordingStopwatch = Stopwatch();
  late AnimationController _timerAnimationController;
  String _recordingTimeLabel = '00:00';

  // Capture button pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Memories bounce animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();

    // Capture button breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Memories bounce hint
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Timer tick controller
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3600),
    );
    _timerAnimationController.addListener(_updateTimerLabel);
  }

  void _updateTimerLabel() {
    if (!_isRecording) return;
    final elapsed = _recordingStopwatch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final newLabel = '$minutes:$seconds';
    if (newLabel != _recordingTimeLabel && mounted) {
      setState(() => _recordingTimeLabel = newLabel);
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInitMs < 300) return;
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
      debugPrint('[Camera] disposed controller at ${DateTime.now().toIso8601String()}');
    } catch (e) {
      debugPrint('[Camera] error disposing controller: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureCaption.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _timerAnimationController.dispose();
    _recordingStopwatch.stop();
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
    debugPrint('[Camera] lifecycle state: $state');
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      if ((_cameraController == null || !_isCameraInitialized) && !_isInitializing) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _initCamera();
        });
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordingStopwatch.stop();
      _timerAnimationController.stop();
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
          finalPath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          await file.saveTo(finalPath);
        }
        if (mounted) {
          setState(() {
            _isRecording = false;
            _hasRecording = true;
            _captureCaptionOpen = true;
            _recordedVideoPath = finalPath;
            _recordingTimeLabel = '00:00';
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
            _recordingTimeLabel = '00:00';
          });
        }
      }
    } else {
      try {
        if (_isCameraInitialized && _cameraController != null) {
          await _cameraController!.startVideoRecording();
        }
        if (mounted) {
          _recordingStopwatch.reset();
          _recordingStopwatch.start();
          _timerAnimationController.forward(from: 0);
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
      const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
        if (_recordedVideoPath != null) {
          try {
            final file = File(_recordedVideoPath!);
            if (file.existsSync()) {
              file.deleteSync();
              debugPrint('Local media file deleted after confirmed upload success: $_recordedVideoPath');
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
          _recordingTimeLabel = '00:00';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory posted successfully to your Circle!')),
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

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;
    final chatState = ref.watch(chatProvider);
    final unreadCount = chatState.unreadNotifications;

    final uploadState = ref.watch(uploadProvider);
    final isUploading = uploadState.status == UploadStatus.preparing ||
        uploadState.status == UploadStatus.validating ||
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.waitingForResponse;

    final circleMembers = ref.watch(circlesProvider);
    final memberCount = circleMembers.length;

    final sessionState = ref.watch(sessionProvider);
    final user = sessionState.user;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -300) context.go('/feed');
      },
      child: PopScope(
        canPop: !isUploading,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Upload in Progress',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: Text(
                'Your memory is still uploading. Leaving will cancel the upload. Leave anyway?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Continue Upload',
                      style: TextStyle(color: kYellow, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(uploadProvider.notifier).cancelUpload();
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Leave Anyway',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
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
              // Layer 0: Full-bleed camera/video preview
              _fullBleedCameraPreview(),
              // Layer 1: Gradient vignette overlays (top + bottom)
              _vignetteOverlay(),
              // Layer 2: Caption editor overlay (when active)
              if (_hasRecording && _captureCaptionOpen)
                Positioned(
                  left: _captureCaptionOffset.dx,
                  top: _captureCaptionOffset.dy,
                  child: _captureCaptionEditor(),
                ),
              // Layer 3: Upload progress overlay
              if (isUploading) _uploadOverlay(uploadState),
              // Layer 4: Top HUD
              Positioned(
                top: topPad + 10,
                left: 20,
                right: 20,
                child: _topHud(memberCount, user),
              ),
              // Layer 5: REC indicator (while recording)
              if (_isRecording)
                Positioned(
                  top: topPad + 68,
                  left: 0,
                  right: 0,
                  child: Center(child: _recIndicator()),
                ),
              // Layer 6: Bottom controls
              Positioned(
                bottom: bottomPad + 20,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_hasRecording && !_isRecording) ...[
                      _memoriesSwipeHint(),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!_hasRecording && !_isRecording && _cameras.length > 1)
                            Positioned(
                              left: 0,
                              child: _glassIconButton(
                                icon: Icons.flip_camera_android_rounded,
                                onTap: _switchCamera,
                              ),
                            ),
                          _hasRecording
                              ? _sendToCircleButton(isUploading, uploadState)
                              : _captureButton(),
                          if (!_hasRecording && !_isRecording)
                            Positioned(
                              right: 0,
                              child: _circleMessageButton(unreadCount),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullBleedCameraPreview() {
    if (_hasRecording) {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoPlayerController!.value.size.width,
            height: _videoPlayerController!.value.size.height,
            child: VideoPlayer(_videoPlayerController!),
          ),
        );
      }
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: kYellow)),
      );
    }
    if (_isCameraInitialized && _cameraController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1080,
          height: _cameraController!.value.previewSize?.width ?? 1920,
          child: CameraPreview(_cameraController!),
        ),
      );
    }
    if (_cameras.isEmpty) {
      return Container(
        color: const Color(0xFF111111),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded,
                  color: Colors.white.withValues(alpha: 0.25), size: 52),
              const SizedBox(height: 16),
              Text(
                'No camera detected',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: kYellow, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vignetteOverlay() {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB2000000), Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 260,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topHud(int memberCount, UserProfile user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (memberCount > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF5ED6B3), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      memberCount == 1
                          ? '1 in your circle'
                          : '$memberCount in your circle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => _showProfileSheet(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    user.firstName?.isNotEmpty == true
                        ? user.firstName![0].toUpperCase()
                        : user.username?.isNotEmpty == true
                            ? user.username![0].toUpperCase()
                            : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulseRedDot(),
              const SizedBox(width: 7),
              const Text(
                'REC',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              Text(
                _recordingTimeLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memoriesSwipeHint() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => context.go('/feed'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'memories',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2), width: 1.2),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _circleMessageButton(int unreadCount) {
    return GestureDetector(
      onTap: () => context.go('/circle'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1.2),
                ),
                child: const Icon(Icons.mark_unread_chat_alt_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? 1.0 : _pulseAnimation.value,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording
                      ? Colors.red.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            ),
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? Colors.red.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: _isRecording
                          ? Colors.red
                          : Colors.white.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _isRecording
                        ? Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          )
                        : Image.asset(
                            'assets/images/memory-logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sendToCircleButton(bool isUploading, UploadState uploadState) {
    return GestureDetector(
      onTap: isUploading
          ? () => ref.read(uploadProvider.notifier).cancelUpload()
          : _sendToCircle,
      child: Container(
        width: 82,
        height: 82,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kYellow,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kYellow.withValues(alpha: 0.38),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 6),
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

  Widget _uploadOverlay(UploadState uploadState) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getUploadStageMessage(uploadState.status),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    if (uploadState.status == UploadStatus.uploading) ...[
                      LinearProgressIndicator(
                        value: uploadState.progress,
                        color: kYellow,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(uploadState.progress * 100).toInt()}%',
                        style: const TextStyle(
                            color: kYellow,
                            fontSize: 13,
                            fontWeight: FontWeight.w900),
                      ),
                    ] else ...[
                      LinearProgressIndicator(
                        color: kYellow,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 6,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _captureCaptionEditor() {
    return GestureDetector(
      onScaleUpdate: (details) => setState(() {
        _captureCaptionOffset += details.focalPointDelta;
        _captureCaptionSize =
            (_captureCaptionSize * details.scale).clamp(16, 42);
      }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 220,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            child: TextField(
              controller: _captureCaption,
              autofocus: true,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _captureCaptionSize,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Add caption...',
                hintStyle: TextStyle(
                    color: Colors.white54, fontWeight: FontWeight.w500),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
        color: dark ? kDarkCream : kCream,
        gradient: LinearGradient(
          colors: dark
              ? const [kDarkCream, kCharcoal]
              : const [kYellow, kYellow],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      );

  Widget _pill(
    String text,
    VoidCallback onTap,
    bool dark, {
    Color? color,
    Color? foreground,
    bool compact = false,
    double? width,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: width ?? double.infinity,
          height: compact ? 34 : 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? (dark ? kDarkCream : kCream),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: foreground ?? (dark ? kCream : kCharcoal),
              fontSize: compact ? 10 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _PulseRedDot extends StatefulWidget {
  const _PulseRedDot();

  @override
  State<_PulseRedDot> createState() => _PulseRedDotState();
}

class _PulseRedDotState extends State<_PulseRedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
            color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}
