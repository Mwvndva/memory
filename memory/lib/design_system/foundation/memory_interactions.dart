import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Playful interaction toolkit — springy, tactile micro-interactions built on
/// Flutter's native animation framework (no extra packages).
///
///   • [BouncyTap]  — press-to-shrink, release-to-overshoot on any child.
///   • [PopIn]      — elastic scale + fade entrance for a widget.
///   • [showConfetti] / [ConfettiBurst] — a one-shot celebratory particle burst.
///
/// Keep the numbers here in one place so the whole app shares one "feel".
/// ─────────────────────────────────────────────────────────────────────────

/// A tap target that springs down when pressed and overshoots back with an
/// elastic bounce on release. Adds a light haptic tick by default.
///
/// Drop-in replacement for a GestureDetector/InkWell around buttons, cards,
/// list tiles, avatars — anything the user taps.
class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.93,
    this.haptic = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the child shrinks while held (0.93 ≈ a soft, premium press).
  final double pressedScale;

  /// Emit a light haptic on press. Silently ignored on platforms without one.
  final bool haptic;

  final bool enabled;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  // 0.0 = at rest (scale 1.0), 1.0 = fully pressed (scale = pressedScale).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: -0.35, // allow overshoot below 0 → scale > 1 on release
    upperBound: 1.0,
    value: 0.0,
  );

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _down(TapDownDetails _) {
    if (widget.haptic) HapticFeedback.lightImpact();
    _c.animateTo(
      1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  void _up(TapUpDetails _) {
    // elasticOut overshoots past the target → the child pops slightly above
    // its resting size before settling. That overshoot is the "bounce".
    _c.animateTo(
      0.0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.elasticOut,
    );
    widget.onTap?.call();
  }

  void _cancel() {
    _c.animateTo(
      0.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? _down : null,
      onTapUp: _active ? _up : null,
      onTapCancel: _active ? _cancel : null,
      // Wired only when there is something to long-press. Otherwise every
      // button would advertise a long-press action to a screen reader and
      // then do nothing with it.
      onLongPress: _active && widget.onLongPress != null
          ? () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final scale = 1.0 - _c.value * (1.0 - widget.pressedScale);
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Elastic "pop" entrance — the child scales up from small with an overshoot
/// and fades in. Great for dialogs, cards, badges, or staggered list items
/// (give each item an increasing [delay]).
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 620),
    this.beginScale = 0.6,
    this.curve = Curves.elasticOut,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: widget.curve));
    // Fade completes in the first ~40% so the elastic settle happens fully opaque.
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}

/// Fire a full-screen confetti burst over the current overlay. Non-blocking;
/// the entry removes itself when the animation finishes.
///
/// ```dart
/// showConfetti(context);              // celebrate!
/// ```
void showConfetti(
  BuildContext context, {
  int particles = 140,
  Duration duration = const Duration(milliseconds: 2600),
  List<Color>? colors,
  Alignment origin = const Alignment(0, -0.2),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: ConfettiBurst(
        particles: particles,
        duration: duration,
        colors: colors,
        origin: origin,
        onComplete: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

/// A one-shot confetti animation that plays once on mount. Usually inserted via
/// [showConfetti], but can be embedded directly in a Stack.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particles = 140,
    this.duration = const Duration(milliseconds: 2600),
    this.colors,
    this.origin = const Alignment(0, -0.2),
    this.onComplete,
  });

  final int particles;
  final Duration duration;
  final List<Color>? colors;
  final Alignment origin;
  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Particle> _particles;

  static const _defaultColors = [
    Color(0xFFFF1493), // hot pink
    Color(0xFFBD3EFF), // electric purple
    Color(0xFF00F5FF), // cyan
    Color(0xFF39FF14), // neon lime
    Color(0xFFFF5E00), // orange
    Color(0xFFFADA5E), // gold
    Color(0xFF63B3FF), // sky
  ];

  @override
  void initState() {
    super.initState();
    final rand = Random();
    final palette = widget.colors ?? _defaultColors;
    _particles = List.generate(widget.particles, (_) {
      // Launch upward-and-outward in a fan, then gravity takes over.
      final angle = -pi / 2 + (rand.nextDouble() - 0.5) * pi * 0.9;
      final speed = 0.55 + rand.nextDouble() * 0.9;
      return _Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: palette[rand.nextInt(palette.length)],
        size: 6 + rand.nextDouble() * 8,
        rotation: rand.nextDouble() * 2 * pi,
        angularVelocity: (rand.nextDouble() - 0.5) * 12,
        square: rand.nextBool(),
        lag: rand.nextDouble() * 0.12,
      );
    });
    _c.forward().whenComplete(() => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(
          particles: _particles,
          t: _c.value,
          origin: widget.origin,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.angularVelocity,
    required this.square,
    required this.lag,
  });

  final double vx; // normalized launch velocity (fraction of screen / sec-ish)
  final double vy;
  final Color color;
  final double size;
  final double rotation;
  final double angularVelocity;
  final bool square;
  final double lag; // small per-particle start delay for a natural spread
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.origin,
  });

  final List<_Particle> particles;
  final double t;
  final Alignment origin;

  static const _gravity = 1.6;
  static const _spread = 0.9; // scales launch velocity to screen fraction

  @override
  void paint(Canvas canvas, Size size) {
    final ox = (origin.x + 1) / 2 * size.width;
    final oy = (origin.y + 1) / 2 * size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final lt = ((t - p.lag) / (1 - p.lag)).clamp(0.0, 1.0);
      if (lt <= 0) continue;

      // Simple projectile motion in normalized space, then to pixels.
      final dx = p.vx * _spread * lt * size.width;
      final dy = (p.vy * _spread * lt + 0.5 * _gravity * lt * lt) * size.height;

      final x = ox + dx;
      final y = oy + dy;
      if (y > size.height + 40) continue;

      // Fade out over the last third of life.
      final alpha = (1.0 - (lt - 0.66) / 0.34).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.angularVelocity * lt);
      if (p.square) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
