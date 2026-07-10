import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/media/unified_media_widgets.dart';

// ProfileSectionCard, ProfileDetailRow, ProfilePolicyRow, ProfileActionSheet
// and ProfilePill used to live here. They were generic surfaces wearing a
// feature's name, and are now MemoryCard / MemoryListTile / MemoryActionTile /
// MemoryBottomSheet / MemoryButton in the design system.
//
// What remains is genuinely specific to the profile: the achievement card and
// the circle headcount card.

/// Shows the circle headcount and an "Add someone" action, capped at 30.
class ProfileAddPersonCard extends StatelessWidget {
  const ProfileAddPersonCard({
    super.key,
    required this.circleCount,
    required this.dark,
    required this.onAddPerson,
  });

  static const int maxCircleSize = 30;

  final int circleCount;
  final bool dark;
  final VoidCallback onAddPerson;

  @override
  Widget build(BuildContext context) {
    final isFull = circleCount >= maxCircleSize;

    return MemoryCard(
      dark: dark,
      padding: const EdgeInsets.all(MemorySpacing.xxl),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$circleCount / $maxCircleSize',
                style: MemoryTypography.onSurface(
                  MemoryTypography.headline.copyWith(fontSize: 19),
                  dark,
                ),
              ),
              Text(
                'in your circle',
                style: MemoryTypography.mutedOnSurface(
                  MemoryTypography.sectionLabel.copyWith(
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                  ),
                  dark,
                  alpha: 0.68,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 124,
            child: MemoryButton(
              label: 'Add someone',
              // A full circle disables the button rather than presenting one
              // that silently does nothing.
              onPressed: isFull ? null : onAddPerson,
              dark: dark,
              size: MemoryButtonSize.compact,
              background: dark ? Colors.white : MemoryColors.ink,
              foreground: dark ? MemoryColors.ink : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shareable achievement card shown inside the invite and share sheets.
class ProfileFunCard extends StatelessWidget {
  const ProfileFunCard({
    super.key,
    required this.title,
    required this.value,
    this.avatarUrl,
    this.avatarBytes,
    this.avatarInitial = '?',
    this.username = 'user',
    this.countryFlag = 'KE',
    this.countryRank = 1,
    this.globalRank,
  });

  /// Days below which the global leaderboard stays locked.
  static const int globalRankQualifyingDays = 30;

  final String title;
  final String value;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final String avatarInitial;
  final String username;
  final String countryFlag;
  final int countryRank;
  final int? globalRank;

  /// Bronze → Silver → Gold → Diamond, by streak length.
  static (Color tier, Color glow) _tierFor(int dayCount) {
    if (dayCount >= 365) {
      return (
        const Color(0xFF89CFF0),
        const Color(0xFF89CFF0).withValues(alpha: 0.35),
      );
    }
    if (dayCount >= 100) {
      return (
        const Color(0xFFFFD700),
        const Color(0xFFFFD700).withValues(alpha: 0.30),
      );
    }
    if (dayCount >= 30) {
      return (
        const Color(0xFFC0C0C0),
        const Color(0xFFC0C0C0).withValues(alpha: 0.25),
      );
    }
    return (
      const Color(0xFFCD7F32),
      const Color(0xFFCD7F32).withValues(alpha: 0.22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAvatar = avatarUrl != null && avatarUrl!.isNotEmpty
        ? avatarUrl
        : null;
    final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
    final dayCount = int.tryParse(cleanVal) ?? 0;

    final (tierColor, glowColor) = _tierFor(dayCount);

    final bool isStreak = title == 'Memories';
    final String descriptiveHeading = isStreak
        ? '$dayCount Day Memory Streak'
        : 'Circle Active Streak';
    final String descriptiveWording = isStreak
        ? 'Captured one Memory every day. Never missed a day. Still going.'
        : 'Your Circle hasn\'t missed a single day for $dayCount consecutive days. Collective consistency.';

    return Container(
      width: double.infinity,
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MemoryColors.ink,
        borderRadius: BorderRadius.circular(MemoryRadius.xxl),
        border: Border.all(color: tierColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle branded packaging texture.
          Positioned(
            left: 20,
            top: 20,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: 0.2,
                child: Image.asset(
                  'assets/images/memory-logo.png',
                  width: 55,
                  height: 55,
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 45,
            child: Opacity(
              opacity: 0.02,
              child: Transform.rotate(
                angle: -0.4,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 45,
            bottom: 30,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: 0.5,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 25,
            bottom: 50,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: -0.15,
                child: Image.asset(
                  'assets/images/memory-logo.png',
                  width: 45,
                  height: 45,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [tierColor.withValues(alpha: 0.06), Colors.transparent],
                radius: 1.0,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: MemorySpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(MemorySpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor, width: 3),
                    ),
                    child: ClipOval(
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                          : resolvedAvatar != null
                          ? UnifiedImageWidget(
                              imageUrl: resolvedAvatar,
                              fit: BoxFit.cover,
                              fallbackWidget: Center(
                                child: Text(
                                  avatarInitial,
                                  style: const TextStyle(
                                    color: MemoryColors.cream,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: tierColor,
                              alignment: Alignment.center,
                              child: Text(
                                avatarInitial,
                                style: const TextStyle(
                                  color: MemoryColors.ink,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: MemorySpacing.lg),
                  Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: MemoryTypography.subtitle.copyWith(
                      color: MemoryColors.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: MemorySpacing.sm),
                  Text(
                    descriptiveHeading,
                    textAlign: TextAlign.center,
                    style: MemoryTypography.headline.copyWith(color: tierColor),
                  ),
                  const SizedBox(height: MemorySpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MemorySpacing.gutter,
                    ),
                    child: Text(
                      descriptiveWording,
                      textAlign: TextAlign.center,
                      style: MemoryTypography.sectionLabel.copyWith(
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: MemoryColors.cream.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: MemorySpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: MemorySpacing.sm,
                    runSpacing: MemorySpacing.sm,
                    children: [
                      _RankChip(
                        text: '🏆 Streak Rank: #$countryRank in $countryFlag',
                        borderAccent: tierColor,
                      ),
                      if (globalRank != null ||
                          dayCount >= globalRankQualifyingDays)
                        _RankChip(
                          text: '🌍 Global Rank: #${globalRank ?? 148}',
                          borderAccent: tierColor,
                        )
                      else
                        _RankChip(
                          text:
                              '🌍 Global Rank: Locked (Reach $globalRankQualifyingDays days to qualify)',
                          borderAccent: tierColor.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/memory-logo.png',
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: MemorySpacing.xs),
                      Text(
                        'Memory • Real moments. Real friends.',
                        style: MemoryTypography.micro.copyWith(
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.text, required this.borderAccent});

  final String text;
  final Color borderAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MemorySpacing.md,
        vertical: MemorySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: MemoryRadius.allPill,
        border: Border.all(
          color: borderAccent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: MemoryTypography.micro.copyWith(
          fontSize: 9,
          color: MemoryColors.cream,
        ),
      ),
    );
  }
}
