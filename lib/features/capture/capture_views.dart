import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/chat_repository.dart';

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

class _CameraCaptureViewState extends ConsumerState<CameraCaptureView> with WidgetsBindingObserver {
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
      debugPrint('[Camera] disposed controller at ${DateTime.now().toIso8601String()}');
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
    } catch (_) {}
    try {
      _videoPlayerController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera on pause/inactive to avoid holding surfaces when backgrounded
    // and re-init on resume.
    debugPrint('[Camera] lifecycle state: $state');
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // dispose camera to free hardware quickly
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      // Re-init camera if needed
      if ((_cameraController == null || !_isCameraInitialized) && !_isInitializing) {
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
          finalPath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
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

  void _sendToCircle() {
    final captionText = _captureCaption.text.trim();

    // Capture dynamic memory
    ref.read(memoryProvider.notifier).addMemory(
          captionText,
          const [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Beautiful violet/purple gradient for dynamic captures
          videoPath: _recordedVideoPath,
        );

    // Stop and dispose preview player
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;

    // Reset states
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
      const SnackBar(content: Text('Memory posted successfully to your Circle!')),
    );

    // Navigate back to capture
    context.go('/capture');
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;
    final chatState = ref.watch(chatProvider);
    final unreadCount = chatState.unreadNotifications;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -300) context.go('/feed');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4C430),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              16 + bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header row: User/Person icon on the right
                Row(
                  children: [
                    const Spacer(),
                    _overlayCircleGroupButton(
                      onTap: () => context.go('/circle'),
                      unreadCount: unreadCount,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Camera card preview (not full screen) with 1:1 ratio
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _capturePreview(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bottom controls row: Grid on left, Capture in center, Flip on right
                SizedBox(
                  width: double.infinity,
                  height: 82,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid button - bottom left
                      Positioned(
                        left: 8,
                        child: _overlayIconButton(
                          icon: Icons.grid_view_rounded,
                          onTap: () => context.go('/feed'),
                        ),
                      ),

                      // Centre: capture button or send button
                      _hasRecording
                          ? _pill(
                              'Send to circle',
                              _sendToCircle,
                              dark,
                              color: dark ? kYellow : Colors.white,
                              foreground: dark ? Colors.black : Colors.black,
                              width: 200,
                            )
                          : GestureDetector(
                              onTap: _toggleRecording,
                              child: Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.red : Colors.white,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 4,
                                  ),
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.circle,
                                  color: _isRecording ? Colors.white : Colors.red,
                                  size: 30,
                                ),
                              ),
                            ),

                      // Flip camera - bottom right
                      if (!_hasRecording && !_isRecording && _cameras.length > 1)
                        Positioned(
                          right: 8,
                          child: _overlayIconButton(
                            icon: Icons.flip_camera_ios_rounded,
                            onTap: _switchCamera,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for icon buttons overlaid on the camera preview
  Widget _overlayIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // Stacked user icons button for top-right (navigates to circle) with unread badge overlay
  Widget _overlayCircleGroupButton({required VoidCallback onTap, required int unreadCount}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Bottom/back user icon (smaller, shifted up/left)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Icon(
                    Icons.people_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 20,
                  ),
                ),
                // Top/front user icon (shifted down/right)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Icon(
                    Icons.people_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _capturePreview() {
    final dark = ref.watch(isDarkProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = size * 0.30;
        final borderRadius = BorderRadius.circular(radius);

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              colors: [Color(0xFF4A2B27), Color(0xFFA84538)],
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: GestureDetector(
              onTap: _hasRecording ? () => setState(() => _captureCaptionOpen = true) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Live camera preview, video preview playback, or fallback
                  if (_hasRecording)
                    _videoPlayerController != null && _videoPlayerController!.value.isInitialized
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
                                  ? CircularProgressIndicator(color: dark ? kYellow : kBlack)
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
                        width: _cameraController!.value.previewSize?.height ?? 1080,
                        height: _cameraController!.value.previewSize?.width ?? 1920,
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
                          const _PulseRedDot(),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  if (_hasRecording && _captureCaptionOpen) _captureCaptionEditor(),
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
          _captureCaptionSize = (_captureCaptionSize * details.scale).clamp(16, 42);
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

class _PulseRedDotState extends State<_PulseRedDot> with SingleTickerProviderStateMixin {
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
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
