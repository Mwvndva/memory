import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/media/unified_media_widgets.dart';

/// A titled group of rows, e.g. "CONTACT" or "LEGAL & SUPPORT".
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.dark,
    required this.children,
  });

  final String title;
  final bool dark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 14),
          child: Text(
            title,
            style: TextStyle(
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? kBlack : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// A read-only `label — value` row inside a [ProfileSectionCard].
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.isLast,
    required this.dark,
  });

  final String label;
  final String value;
  final bool isLast;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.1,
                  ),
                  width: 0.8,
                ),
              ),
            ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row with a chevron, used for settings and legal entries.
class ProfilePolicyRow extends StatelessWidget {
  const ProfilePolicyRow({
    super.key,
    required this.title,
    required this.onTap,
    required this.isLast,
    required this.dark,
  });

  final String title;
  final VoidCallback onTap;
  final bool isLast;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: (dark ? Colors.white : kCharcoal).withValues(
                      alpha: 0.1,
                    ),
                    width: 0.8,
                  ),
                ),
              ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
              size: 11,
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded container every profile bottom sheet is wrapped in.
class ProfileActionSheet extends StatelessWidget {
  const ProfileActionSheet({
    super.key,
    required this.dark,
    required this.child,
  });

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A pill-shaped button.
class ProfilePill extends StatelessWidget {
  const ProfilePill({
    super.key,
    required this.text,
    required this.onTap,
    required this.dark,
    this.color,
    this.foreground,
    this.compact = false,
    this.width,
  });

  final String text;
  final VoidCallback onTap;
  final bool dark;
  final Color? color;
  final Color? foreground;
  final bool compact;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: compact ? 34 : 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? (dark ? kDarkCream : kCream),
          borderRadius: BorderRadius.circular(999),
          border: color == null
              ? Border.all(
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.06,
                  ),
                )
              : null,
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
}

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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kBlack : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$circleCount / $maxCircleSize',
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'in your circle',
                style: TextStyle(
                  color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 124,
            child: ProfilePill(
              text: 'Add someone',
              onTap: circleCount < maxCircleSize ? onAddPerson : () {},
              dark: dark,
              compact: true,
              color: dark ? Colors.white : kBlack,
              foreground: dark ? kBlack : Colors.white,
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
        color: kBlack,
        borderRadius: BorderRadius.circular(28),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(4),
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
                                    color: kCream,
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
                                  color: kBlack,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kCream,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    descriptiveHeading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      descriptiveWording,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kCream.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
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
                      const SizedBox(width: 4),
                      const Text(
                        'Memory • Real moments. Real friends.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderAccent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kCream,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
