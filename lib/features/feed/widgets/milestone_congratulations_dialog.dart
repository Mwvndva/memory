import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/playful.dart';
import 'package:memory_app/core/router.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/feed/feed.dart';

import 'milestone_card_widget.dart';

const _streak7Messages = [
  "You're a memory-making machine! 7 days of pure magic. ✨",
  "Consecutive memories? You're a certified keeper of moments. Keep shining! 🌟",
  "Look at you, keeping the spark alive! 7 days of holding onto what matters. ❤️",
  "Every single day, you chose to remember. We're so proud of you! 🎉",
  "Streak level: Legendary. 7 days of building your beautiful timeline! 🚀",
  "Your memories are a gift. Thank you for showing up for 7 days straight! 🎁",
  "A full week of moments captured! You are creating your own history. 🌈",
  "7 days in a row! The circle is glowing brighter because of you. 💫",
];

const _streak30Messages = [
  "Thirty days of capturing life. You're building a masterpiece! 🎨",
  "A whole month of moments! Your future self is cheering for you. 📅✨",
  "30 days. 30 memories. You are officially unstoppable! 🔥",
  "A month of memory-making. You're woven into the fabric of time! 🌌",
  "30 days of holding onto the magic. You're a memory wizard! 🧙‍♂️✨",
  "Look at this streak! 30 days of consecutive memories. Incredible! 🏆",
  "A full month of memories. You have immortalized 30 beautiful days! 📸🌟",
  "Unbelievable consistency! 30 days of sharing your light. ☀️💛",
];
class MilestoneCongratulationsDialog extends StatefulWidget {
  final UserProfile user;
  final int milestone;

  const MilestoneCongratulationsDialog({
    super.key,
    required this.user,
    required this.milestone,
  });

  @override
  State<MilestoneCongratulationsDialog> createState() => _MilestoneCongratulationsDialogState();
}

class _MilestoneCongratulationsDialogState extends State<MilestoneCongratulationsDialog> {
  late final CardDesignData _designData;
  late final String _message;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _designData = CardDesignData.generate(widget.milestone);
    final messages = widget.milestone == 30 ? _streak30Messages : _streak7Messages;
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
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
      final path = '${tempDir.path}/${widget.milestone}_streak_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Trigger standard native share sheet containing image
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Conquered the ${widget.milestone}-day memory streak! 🌟 Capture and share your daily memories on Memory App!',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing milestone card: $e');
      if (mounted) {
        showAppError(context, 'Could not generate shareable card: ${e.toString()}');
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
              // Repaint Boundary wraps the MilestoneCardWidget
              PopIn(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: MilestoneCardWidget(
                    user: widget.user,
                    milestone: widget.milestone,
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share your achievement!',
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
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: kBlack,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share_rounded, color: kBlack, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Share Card',
                                    style: TextStyle(
                                      color: kBlack,
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
                          'Keep Going! ⚡',
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

// Global Trigger and Milestone Logic Checker
Future<void> checkMilestones(BuildContext context, WidgetRef ref, int streakDays) async {
  if (streakDays <= 0) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final user = ref.read(authProvider);
  if (!user.isAuthenticated) return;

  // Key tracking per user username
  final prefix = 'user_${user.username}_';
  final key7 = '${prefix}seen_streak_7';
  final key30 = '${prefix}seen_streak_30';

  // 1. Self-resetting flags on streak drop below milestones
  if (streakDays < 7) {
    if (prefs.getBool(key7) ?? false) {
      await prefs.setBool(key7, false);
    }
  }
  if (streakDays < 30) {
    if (prefs.getBool(key30) ?? false) {
      await prefs.setBool(key30, false);
    }
  }

  // Helper function to launch the overlay and congratulation modal
  void launchCongratulations(int milestone) {
    // Show celebratory in-app global notification
    showGlobalNotification(
      title: 'Streak Milestone! 🏆',
      body: 'You reached a $milestone-day streak! Tap to view your unique shareable card.',
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => MilestoneCongratulationsDialog(user: user, milestone: milestone),
        );
      },
    );

    // Also pop it up automatically for maximum impact
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MilestoneCongratulationsDialog(user: user, milestone: milestone),
    );
  }

  // 2. Triggering milestones
  if (streakDays >= 7 && !(prefs.getBool(key7) ?? false)) {
    await prefs.setBool(key7, true);
    // Delay slightly to prevent rendering crashes during transition
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        launchCongratulations(7);
      }
    });
  } else if (streakDays >= 30 && !(prefs.getBool(key30) ?? false)) {
    await prefs.setBool(key30, true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        launchCongratulations(30);
      }
    });
  }
}

// ─── Circle Size Milestones ──────────────────────────────────────────────────

