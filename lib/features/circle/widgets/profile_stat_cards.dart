import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/auth/repositories/auth_repository.dart';
import 'package:memory_app/shared/widgets/social_marks.dart';

import '../views/profile_share_card.dart';

/// The "Memories" and "Circle Pulse" streak cards, side by side.
class ProfileStatCards extends ConsumerWidget {
  const ProfileStatCards({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Memories',
            value: '${user.streakDays} days',
            colors: const [kYellow, kAmber],
            dark: dark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Circle Pulse',
            value: '${user.circlePulseDays} days',
            colors: const [kMint, kSky],
            dark: dark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.colors,
    required this.dark,
  });

  final String title;
  final String value;
  final List<Color> colors;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isStreak = title == 'Memories';
    final subtitle = isStreak ? 'Day streak' : 'Circle active';
    final accent = colors.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? kBlack
            : Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShareIcon(
                icon: isStreak
                    ? Icons.camera_alt_rounded
                    : Icons.chat_bubble_rounded,
                accent: accent,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SharePill(
                  logo: const InstagramMark(color: Colors.white),
                  bg: const Color(0xFFE1306C),
                  onTap: () => showShareCard(
                    context,
                    title: title,
                    value: value,
                    channel: 'Instagram',
                    dark: dark,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SharePill(
                  logo: const WhatsAppMark(color: Colors.white),
                  bg: const Color(0xFF25D366),
                  onTap: () => showShareCard(
                    context,
                    title: title,
                    value: value,
                    channel: 'WhatsApp',
                    dark: dark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  const _SharePill({required this.logo, required this.bg, required this.onTap});

  final Widget logo;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox(width: 17, height: 17, child: logo),
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accent, size: 16),
    );
  }
}
