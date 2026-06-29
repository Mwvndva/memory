import 'package:flutter/material.dart';
import 'dart:math';

class AuthBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw base Memory Yellow
    final basePaint = Paint()..color = const Color(0xFFFADA5E);
    canvas.drawRect(Offset.zero & size, basePaint);

    // 2. Draw soft radial gradient for premium visual depth
    final rect = Offset.zero & size;
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        center: Alignment.center,
        radius: 1.1,
      ).createShader(rect);
    canvas.drawRect(rect, radialPaint);

    // 3. Draw extremely subtle irregular branded texture (ghost shapes and M monograms)
    final rand = Random(42); 
    final shapesCount = 14;

    for (int i = 0; i < shapesCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final scale = rand.nextDouble() * 30 + 20; // sizes between 20 and 50
      final opacity = rand.nextDouble() * 0.02 + 0.02; // opacity 2% to 4%
      final rotation = rand.nextDouble() * pi / 4; // slight rotation angle

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (i % 2 == 0) {
        // Draw monograms ("M")
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'M',
            style: TextStyle(
              fontSize: scale,
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: opacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        // Center alignment translation
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      } else {
        // Draw simple ghost shape proxy via custom path
        final path = Path();
        final r = scale / 2;
        
        // Draw simple dome top and wavy bottom mascot proxy shape
        path.moveTo(-r, r);
        path.quadraticBezierTo(-r, -r, 0, -r);
        path.quadraticBezierTo(r, -r, r, r);
        // wavy base
        path.quadraticBezierTo(r * 0.5, r * 0.7, 0, r);
        path.quadraticBezierTo(-r * 0.5, r * 0.7, -r, r);
        path.close();

        final shapePaint = Paint()
          ..color = Colors.black.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, shapePaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
