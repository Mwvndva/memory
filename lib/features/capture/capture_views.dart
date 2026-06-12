import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import '../../repositories/memory_repository.dart';

class CameraCaptureView extends ConsumerStatefulWidget {
  const CameraCaptureView({super.key});

  @override
  ConsumerState<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends ConsumerState<CameraCaptureView> {
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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras[0],
          ResolutionPreset.medium,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _captureCaption.dispose();
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
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

    // Navigate back to feed
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);

    return Scaffold(
      body: Container(
        decoration: _softBackground(dark),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              24,
              28,
              94 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What made you smile today?',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _capturePreview()),
                const SizedBox(height: 12),
                Center(
                  child: _hasRecording
                      ? _pill(
                          'Send to circle',
                          _sendToCircle,
                          dark,
                          color: kCoral,
                          foreground: Colors.white,
                          width: 282,
                        )
                      : GestureDetector(
                          onTap: _toggleRecording,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kCoral,
                              border: Border.all(
                                color: const Color(0xFFFFE7DD),
                                width: 10,
                              ),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.circle,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _capturePreview() {
    return GestureDetector(
      onTap: _hasRecording ? () => setState(() => _captureCaptionOpen = true) : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF4A2B27), Color(0xFFA84538)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                          ),
                        ),
                        child: const Center(
                          child: Text(
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
              else
                // Fallback static viewfinder
                const Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: Colors.white24,
                    size: 54,
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

              // 3. Fallback notice if emulator/fallback is active
              if (!_hasRecording && !_isCameraInitialized)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Fallback Viewfinder Active',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 4. Caption editor overlay
              if (_hasRecording && _captureCaptionOpen) _captureCaptionEditor(),
            ],
          ),
        ),
      ),
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
              : const [Color(0xFFFFF4E4), Color(0xFFEFFFF8)],
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

