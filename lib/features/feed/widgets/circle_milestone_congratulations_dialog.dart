import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memory_app/design_system/design_system.dart';

import 'circle_milestone_card_widget.dart';
import 'milestone_card_widget.dart';
import 'package:memory_app/core/error_handler.dart';

const _circle7Messages = [
  "Your circle has reached 7 members! A perfect crew for sharing moments. 👥✨",
  "7 users in your circle! The vibe check is complete. Let the memories flow! 🎉",
  "Look at this amazing circle of 7! Together, we keep the stories alive. ❤️",
  "A full house of 7 in the circle! Sharing moments just got 7x better. 🌟",
];

const _circle30Messages = [
  "Incredible! Your circle has reached 30 members. A massive web of shared lives. 👥🌍✨",
  "30 members in your circle! You've built a whole community of memory keepers. 🏆",
  "A circle of 30! Every memory shared is woven into a beautiful community canvas. 🎨💖",
  "30 users strong! Your circle is thriving and full of moments waiting to be captured. 📸🔥",
];

class CircleMilestoneCongratulationsDialog extends StatefulWidget {
  final String circleOwnerUsername;
  final int milestone;
  final List<CircleMemberWithMemories> members;

  const CircleMilestoneCongratulationsDialog({
    super.key,
    required this.circleOwnerUsername,
    required this.milestone,
    required this.members,
  });

  @override
  State<CircleMilestoneCongratulationsDialog> createState() =>
      _CircleMilestoneCongratulationsDialogState();
}

class _CircleMilestoneCongratulationsDialogState
    extends State<CircleMilestoneCongratulationsDialog> {
  late final CardDesignData _designData;
  late final String _message;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _designData = CardDesignData.generate(widget.milestone);
    final messages = widget.milestone == 30
        ? _circle30Messages
        : _circle7Messages;
    _message = messages[Random().nextInt(messages.length)];

    // Celebrate! Fire a confetti burst once the dialog is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showConfetti(context);
    });
  }

  Future<void> _shareCard(String platform) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("RenderRepaintBoundary not found");
      }

      // Capture image at high quality
      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to convert image to bytes");
      }
      final bytes = byteData.buffer.asUint8List();

      // Write bytes to a temp file
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/circle_${widget.milestone}_milestone_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Trigger standard native share sheet containing image
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Check out @${widget.circleOwnerUsername}\'s circle milestone of ${widget.milestone} users on Memory App! 👥🎉',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing milestone card: $e');
      if (mounted) {
        showAppError(context, 'Could not generate shareable card: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Repaint Boundary wraps the CircleMilestoneCardWidget
              PopIn(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: CircleMilestoneCardWidget(
                    circleOwnerUsername: widget.circleOwnerUsername,
                    milestone: widget.milestone,
                    members: widget.members,
                    designData: _designData,
                    message: _message,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sharing Actions Box
              Container(
                width: 310,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share circle milestone!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Single native OS Share button
                    GestureDetector(
                      onTap: () => _shareCard('System'),
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: _isSharing
                            ? const MemoryLoading(
                                size: 16,
                                color: MemoryColors.ink,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.share_rounded,
                                    color: MemoryColors.ink,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Share Card',
                                    style: TextStyle(
                                      color: MemoryColors.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Keep Sharing! 👥✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
}
