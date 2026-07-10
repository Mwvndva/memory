import 'dart:math';
import 'package:flutter/material.dart';

import 'package:memory_app/core/api_config.dart';
import 'milestone_card_widget.dart';
import 'package:memory_app/design_system/design_system.dart';

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
    final totalMemories = members
        .map((m) => m.memoryCount)
        .fold(0, (a, b) => a + b);
    final avgMemories = N > 0 ? (totalMemories / N) : 0.0;

    final sizes = <double>[];
    double maxR = 0.0;

    for (int i = 0; i < N; i++) {
      final mem = members[i];
      final double multiplier;
      if (avgMemories > 0) {
        multiplier =
            0.65 + 0.95 * (mem.memoryCount / (avgMemories * 2)).clamp(0.0, 1.0);
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

          final avatarProvider =
              (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
              ? NetworkImage(formatImageUrl(member.avatarUrl!)) as ImageProvider
              : null;

          final initial = member.firstName.isNotEmpty
              ? member.firstName[0].toUpperCase()
              : (member.username.isNotEmpty
                    ? member.username[0].toUpperCase()
                    : '?');

          return Positioned(
            left: 100.0 + pos.dx - (size / 2),
            top: 100.0 + pos.dy - (size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: index == 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
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
              child: MemoryAvatar(
                radius: size / 2,
                dark: false,
                image: avatarProvider,
                initial: initial,
                background: index == 0
                    ? MemoryColors.ink
                    : MemoryColors.lavender,
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
        borderRadius: BorderRadius.circular(MemoryRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MemoryRadius.xxl),
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
                vertical: MemorySpacing.xxl,
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
                      '$milestone-USER CIRCLE!',
                      style: MemoryTypography.button.copyWith(
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  // Fermat's Spiral avatar packing layout
                  _buildAvatarCluster(),

                  // Bottom Translucent Congratulatory bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MemorySpacing.gutter,
                      vertical: MemorySpacing.xl,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(MemoryRadius.lg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@$circleOwnerUsername\'s Circle',
                          style: MemoryTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: MemorySpacing.xs),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: MemoryTypography.bodySmall.copyWith(
                            color: Colors.white,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
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
          ],
        ),
      ),
    );
  }
}
