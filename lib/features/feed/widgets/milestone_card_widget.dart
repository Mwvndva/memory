import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/design_system/design_system.dart';

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

    // Copied because shuffle mutates in place, and the token list is const.
    final palette = [...MemoryColors.celebration];
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
    final style = rand.nextInt(
      3,
    ); // 0: Memphis/Confetti, 1: Wavy Lines, 2: Rings/Stars

    if (style == 0) {
      // Confetti & Memphis shapes
      for (int i = 0; i < 35; i++) {
        shapesList.add(
          PatternShape(
            type: ShapeType
                .values[rand.nextInt(ShapeType.values.length - 1)], // skip wave
            x: rand.nextDouble(),
            y: rand.nextDouble(),
            size: rand.nextDouble() * 20 + 8,
            color: Colors.white.withValues(
              alpha: rand.nextDouble() * 0.35 + 0.15,
            ),
            rotation: rand.nextDouble() * 2 * pi,
          ),
        );
      }
    } else if (style == 1) {
      // Wavy patterns + sparkles
      for (int i = 0; i < 5; i++) {
        shapesList.add(
          PatternShape(
            type: ShapeType.wave,
            x: 0,
            y: rand.nextDouble(),
            size: rand.nextDouble() * 5 + 2, // stroke width
            color: Colors.white.withValues(
              alpha: rand.nextDouble() * 0.25 + 0.1,
            ),
            rotation: rand.nextDouble() * 8 - 4, // frequency factor or shift
          ),
        );
      }
      for (int i = 0; i < 15; i++) {
        shapesList.add(
          PatternShape(
            type: ShapeType.sparkle,
            x: rand.nextDouble(),
            y: rand.nextDouble(),
            size: rand.nextDouble() * 14 + 8,
            color: Colors.white.withValues(
              alpha: rand.nextDouble() * 0.45 + 0.25,
            ),
            rotation: rand.nextDouble() * 2 * pi,
          ),
        );
      }
    } else {
      // Hypnotic Rings & Stars
      for (int i = 0; i < 6; i++) {
        shapesList.add(
          PatternShape(
            type: ShapeType.ring,
            x: rand.nextDouble(),
            y: rand.nextDouble(),
            size: rand.nextDouble() * 80 + 30,
            color: Colors.white.withValues(
              alpha: rand.nextDouble() * 0.2 + 0.05,
            ),
            rotation: 0,
          ),
        );
      }
      for (int i = 0; i < 15; i++) {
        shapesList.add(
          PatternShape(
            type: ShapeType.star,
            x: rand.nextDouble(),
            y: rand.nextDouble(),
            size: rand.nextDouble() * 18 + 10,
            color: Colors.white.withValues(
              alpha: rand.nextDouble() * 0.4 + 0.2,
            ),
            rotation: rand.nextDouble() * 2 * pi,
          ),
        );
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
            Rect.fromCenter(
              center: Offset.zero,
              width: shape.size,
              height: shape.size,
            ),
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
            final py =
                startY + amplitude * sin((px / wavelength) * 2 * pi + phase);
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

class MilestoneCardWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarProvider = user.avatarBytes != null
        ? MemoryImage(user.avatarBytes!) as ImageProvider
        : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
        ? NetworkImage(formatImageUrl(user.avatarUrl!)) as ImageProvider
        : null;

    final nameInitial = user.firstName.isNotEmpty
        ? user.firstName[0].toUpperCase()
        : (user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U');

    return Container(
      width: 310,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MemoryRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MemoryRadius.xl),
        child: Stack(
          children: [
            // Procedurally painted background pattern
            Positioned.fill(
              child: CustomPaint(painter: MilestoneCardPainter(designData)),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Milestone Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MemorySpacing.gutter,
                      vertical: MemorySpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(MemoryRadius.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$milestone-DAY STREAK!',
                      style: MemoryTypography.button.copyWith(
                        color: Colors.white,
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
                        child: MemoryAvatar(
                          radius: 50,
                          dark: ref.watch(isDarkProvider),
                          image: avatarProvider,
                          initial: nameInitial,
                        ),
                      ),
                      const SizedBox(height: MemorySpacing.xxl),
                      // Large bold username
                      Text(
                        '@${user.username.isNotEmpty ? user.username : "memory_user"}',
                        textAlign: TextAlign.center,
                        style: MemoryTypography.headlineLarge.copyWith(
                          color: Colors.white,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom Translucent Congratulatory bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MemorySpacing.gutter,
                      vertical: MemorySpacing.xl,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(MemoryRadius.xl),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: MemoryTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        height: 1.35,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
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
