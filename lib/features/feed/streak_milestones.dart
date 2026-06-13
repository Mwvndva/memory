import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/router.dart';
import '../../core/api_config.dart';
import '../../models/user_profile.dart';
import '../../repositories/auth_repository.dart';

// Random intimate congratulatory messages
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

// Helper to format user avatars
String _formatImageUrl(String url) {
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    return url.replaceFirst(uri.authority, baseUri.authority);
  }
  return url;
}

// Procedural Card Generation Structures
enum ShapeType { rect, circle, triangle, ring, star, sparkle, wave }

class PatternShape {
  final ShapeType type;
  final double x; // normalized 0..1
  final double y; // normalized 0..1
  final double size;
  final Color color;
  final double rotation;

  PatternShape({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class CardDesignData {
  final List<Color> gradientColors;
  final Alignment beginAlignment;
  final Alignment endAlignment;
  final List<PatternShape> shapes;

  CardDesignData({
    required this.gradientColors,
    required this.beginAlignment,
    required this.endAlignment,
    required this.shapes,
  });

  factory CardDesignData.generate(int milestone) {
    final rand = Random();

    // Vibrant neon/bright color palette
    final palette = [
      const Color(0xFFFF1493), // Hot pink
      const Color(0xFFBD3EFF), // Electric purple
      const Color(0xFF00F5FF), // Electric cyan
      const Color(0xFF39FF14), // Neon lime
      const Color(0xFFFF5E00), // Vivid orange
      const Color(0xFFFFD700), // Gold yellow
      const Color(0xFFFF3366), // Coral red
      const Color(0xFF6C5DD3), // Retro lavender
    ];

    palette.shuffle(rand);
    final colors = [palette[0], palette[1], palette[2]];

    final alignments = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment.topCenter,
      Alignment.bottomCenter,
    ];
    final begin = alignments[rand.nextInt(alignments.length)];
    var end = alignments[rand.nextInt(alignments.length)];
    while (end == begin) {
      end = alignments[rand.nextInt(alignments.length)];
    }

    final shapesList = <PatternShape>[];
    final style = rand.nextInt(3); // 0: Memphis/Confetti, 1: Wavy Lines, 2: Rings/Stars

    if (style == 0) {
      // Confetti & Memphis shapes
      for (int i = 0; i < 35; i++) {
        shapesList.add(PatternShape(
          type: ShapeType.values[rand.nextInt(ShapeType.values.length - 1)], // skip wave
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          size: rand.nextDouble() * 20 + 8,
          color: Colors.white.withValues(alpha: rand.nextDouble() * 0.35 + 0.15),
          rotation: rand.nextDouble() * 2 * pi,
        ));
      }
    } else if (style == 1) {
      // Wavy patterns + sparkles
      for (int i = 0; i < 5; i++) {
        shapesList.add(PatternShape(
          type: ShapeType.wave,
          x: 0,
          y: rand.nextDouble(),
          size: rand.nextDouble() * 5 + 2, // stroke width
          color: Colors.white.withValues(alpha: rand.nextDouble() * 0.25 + 0.1),
          rotation: rand.nextDouble() * 8 - 4, // frequency factor or shift
        ));
      }
      for (int i = 0; i < 15; i++) {
        shapesList.add(PatternShape(
          type: ShapeType.sparkle,
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          size: rand.nextDouble() * 14 + 8,
          color: Colors.white.withValues(alpha: rand.nextDouble() * 0.45 + 0.25),
          rotation: rand.nextDouble() * 2 * pi,
        ));
      }
    } else {
      // Hypnotic Rings & Stars
      for (int i = 0; i < 6; i++) {
        shapesList.add(PatternShape(
          type: ShapeType.ring,
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          size: rand.nextDouble() * 80 + 30,
          color: Colors.white.withValues(alpha: rand.nextDouble() * 0.2 + 0.05),
          rotation: 0,
        ));
      }
      for (int i = 0; i < 15; i++) {
        shapesList.add(PatternShape(
          type: ShapeType.star,
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          size: rand.nextDouble() * 18 + 10,
          color: Colors.white.withValues(alpha: rand.nextDouble() * 0.4 + 0.2),
          rotation: rand.nextDouble() * 2 * pi,
        ));
      }
    }

    return CardDesignData(
      gradientColors: colors,
      beginAlignment: begin,
      endAlignment: end,
      shapes: shapesList,
    );
  }
}

class MilestoneCardPainter extends CustomPainter {
  final CardDesignData data;

  MilestoneCardPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: data.gradientColors,
        begin: data.beginAlignment,
        end: data.endAlignment,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    for (final shape in data.shapes) {
      final shapePaint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill;

      final cx = shape.x * size.width;
      final cy = shape.y * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(shape.rotation);

      switch (shape.type) {
        case ShapeType.rect:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size),
            shapePaint,
          );
          break;
        case ShapeType.circle:
          canvas.drawCircle(Offset.zero, shape.size / 2, shapePaint);
          break;
        case ShapeType.triangle:
          final path = Path();
          final r = shape.size / 2;
          path.moveTo(0, -r);
          path.lineTo(r, r);
          path.lineTo(-r, r);
          path.close();
          canvas.drawPath(path, shapePaint);
          break;
        case ShapeType.ring:
          shapePaint.style = PaintingStyle.stroke;
          shapePaint.strokeWidth = 3;
          canvas.drawCircle(Offset.zero, shape.size / 2, shapePaint);
          break;
        case ShapeType.star:
          final path = Path();
          final r = shape.size / 2;
          final innerR = r * 0.4;
          for (int i = 0; i < 10; i++) {
            final angle = i * pi / 5;
            final radius = i.isEven ? r : innerR;
            final px = radius * cos(angle);
            final py = radius * sin(angle);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, shapePaint);
          break;
        case ShapeType.sparkle:
          final path = Path();
          final r = shape.size / 2;
          path.moveTo(0, -r);
          path.quadraticBezierTo(0, 0, r, 0);
          path.quadraticBezierTo(0, 0, 0, r);
          path.quadraticBezierTo(0, 0, -r, 0);
          path.quadraticBezierTo(0, 0, 0, -r);
          path.close();
          canvas.drawPath(path, shapePaint);
          break;
        case ShapeType.wave:
          canvas.restore();
          canvas.save();
          final wavePaint = Paint()
            ..color = shape.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.size;

          final path = Path();
          final startY = shape.y * size.height;
          path.moveTo(0, startY);

          const points = 16;
          final amplitude = 12.0 + (shape.size * 2);
          final wavelength = size.width / 1.5;
          final phase = shape.rotation * 12;

          for (int i = 0; i <= points; i++) {
            final px = (i / points) * size.width;
            final py = startY + amplitude * sin((px / wavelength) * 2 * pi + phase);
            path.lineTo(px, py);
          }
          canvas.drawPath(path, wavePaint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MilestoneCardPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class MilestoneCardWidget extends StatelessWidget {
  final UserProfile user;
  final int milestone;
  final CardDesignData designData;
  final String message;

  const MilestoneCardWidget({
    super.key,
    required this.user,
    required this.milestone,
    required this.designData,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final avatarProvider = user.avatarBytes != null
        ? MemoryImage(user.avatarBytes!) as ImageProvider
        : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
            ? NetworkImage(_formatImageUrl(user.avatarUrl!)) as ImageProvider
            : null;

    final nameInitial = user.firstName.isNotEmpty
        ? user.firstName[0].toUpperCase()
        : (user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U');

    return Container(
      width: 310,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Procedurally painted background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: MilestoneCardPainter(designData),
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Milestone Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Text(
                      '$milestone-DAY STREAK!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  // Middle Avatar & Big Username
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glow background for avatar
                      Container(
                        width: 106,
                        height: 106,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: kCoral,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Text(
                                  nameInitial,
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Large bold username
                      Text(
                        '@${user.username.isNotEmpty ? user.username : "memory_user"}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom Translucent Congratulatory bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate shareable card: $e')),
        );
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
              RepaintBoundary(
                key: _boundaryKey,
                child: MilestoneCardWidget(
                  user: widget.user,
                  milestone: widget.milestone,
                  designData: _designData,
                  message: _message,
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
                    Row(
                      children: [
                        // Instagram share
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _shareCard('Instagram'),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                                        SizedBox(width: 5),
                                        Text(
                                          'Instagram',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // WhatsApp share
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _shareCard('WhatsApp'),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 15),
                                        SizedBox(width: 5),
                                        Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
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

class CircleMemberWithMemories {
  final String id;
  final String username;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final int memoryCount;

  CircleMemberWithMemories({
    required this.id,
    required this.username,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    required this.memoryCount,
  });
}

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

class CircleMilestoneCardWidget extends StatelessWidget {
  final String circleOwnerUsername;
  final int milestone;
  final List<CircleMemberWithMemories> members;
  final CardDesignData designData;
  final String message;

  const CircleMilestoneCardWidget({
    super.key,
    required this.circleOwnerUsername,
    required this.milestone,
    required this.members,
    required this.designData,
    required this.message,
  });

  Widget _buildAvatarCluster() {
    final N = members.length;
    if (N == 0) return const SizedBox();

    // Determine base avatar size based on count of members
    final baseSize = (120.0 / sqrt(N)).clamp(18.0, 56.0);
    final positions = <Offset>[];
    
    // 1. Center is Offset(0, 0) for the owner
    positions.add(Offset.zero);
    
    // 2. Generate coordinates along Fermat's spiral
    final spacing = baseSize * 1.30;
    for (int i = 1; i < N; i++) {
      final theta = i * 2.39996; // Golden angle in radians
      final r = spacing * sqrt(i);
      positions.add(Offset(r * cos(theta), r * sin(theta)));
    }
    
    // 3. Size is proportional to memory count relative to average memories
    final totalMemories = members.map((m) => m.memoryCount).fold(0, (a, b) => a + b);
    final avgMemories = N > 0 ? (totalMemories / N) : 0.0;
    
    final sizes = <double>[];
    double maxR = 0.0;
    
    for (int i = 0; i < N; i++) {
      final mem = members[i];
      final double multiplier;
      if (avgMemories > 0) {
        multiplier = 0.65 + 0.95 * (mem.memoryCount / (avgMemories * 2)).clamp(0.0, 1.0);
      } else {
        multiplier = 1.0;
      }
      final size = baseSize * multiplier;
      sizes.add(size);
      
      final dist = positions[i].distance + (size / 2);
      if (dist > maxR) {
        maxR = dist;
      }
    }
    
    // Scale factor to make all avatars fit within the 200x200 container bounds
    final double scaleFactor = maxR > 0 ? (100.0 / maxR) : 1.0;
    
    return Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(N, (index) {
          final member = members[index];
          final size = sizes[index] * scaleFactor;
          final pos = positions[index] * scaleFactor;
          
          final avatarProvider = (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
              ? NetworkImage(_formatImageUrl(member.avatarUrl!)) as ImageProvider
              : null;
              
          final initial = member.firstName.isNotEmpty
              ? member.firstName[0].toUpperCase()
              : (member.username.isNotEmpty ? member.username[0].toUpperCase() : '?');
              
          return Positioned(
            left: 100.0 + pos.dx - (size / 2),
            top: 100.0 + pos.dy - (size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: index == 0 ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  width: index == 0 ? 3.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: index == 0 ? kCoral : kLavender,
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: (size * 0.4).clamp(7.0, 24.0),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Procedurally painted background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: MilestoneCardPainter(designData),
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Milestone Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Text(
                      '$milestone-USER CIRCLE!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  // Fermat's Spiral avatar packing layout
                  _buildAvatarCluster(),

                  // Bottom Translucent Congratulatory bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@$circleOwnerUsername\'s Circle',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                            ],
                          ),
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
    );
  }
}

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
  State<CircleMilestoneCongratulationsDialog> createState() => _CircleMilestoneCongratulationsDialogState();
}

class _CircleMilestoneCongratulationsDialogState extends State<CircleMilestoneCongratulationsDialog> {
  late final CardDesignData _designData;
  late final String _message;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _designData = CardDesignData.generate(widget.milestone);
    final messages = widget.milestone == 30 ? _circle30Messages : _circle7Messages;
    _message = messages[Random().nextInt(messages.length)];
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
      final path = '${tempDir.path}/circle_${widget.milestone}_milestone_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Trigger standard native share sheet containing image
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Check out @${widget.circleOwnerUsername}\'s circle milestone of ${widget.milestone} users on Memory App! 👥🎉',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing milestone card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate shareable card: $e')),
        );
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
              RepaintBoundary(
                key: _boundaryKey,
                child: CircleMilestoneCardWidget(
                  circleOwnerUsername: widget.circleOwnerUsername,
                  milestone: widget.milestone,
                  members: widget.members,
                  designData: _designData,
                  message: _message,
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
                      'Share circle milestone!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Instagram share
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _shareCard('Instagram'),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                                        SizedBox(width: 5),
                                        Text(
                                          'Instagram',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // WhatsApp share
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _shareCard('WhatsApp'),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 15),
                                        SizedBox(width: 5),
                                        Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
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

