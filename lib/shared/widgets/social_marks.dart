import 'package:flutter/material.dart';

class InstagramMark extends StatelessWidget {
  const InstagramMark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: InstagramMarkPainter(color));
}

class InstagramMarkPainter extends CustomPainter {
  const InstagramMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.width * 0.12),
        Radius.circular(size.width * 0.26),
      ),
      stroke,
    );
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.18, stroke);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      size.width * 0.045,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant InstagramMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class WhatsAppMark extends StatelessWidget {
  const WhatsAppMark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: WhatsAppMarkPainter(color));
}

class WhatsAppMarkPainter extends CustomPainter {
  const WhatsAppMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width * 0.5, size.height * 0.45);
    canvas.drawCircle(center, size.width * 0.35, stroke);
    final tail = Path()
      ..moveTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(size.width * 0.18, size.height * 0.88)
      ..lineTo(size.width * 0.40, size.height * 0.76)
      ..close();
    canvas.drawPath(tail, fill);
    final phone = Path()
      ..moveTo(size.width * 0.38, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.62,
        size.width * 0.67,
        size.height * 0.56,
      );
    canvas.drawPath(phone, stroke);
  }

  @override
  bool shouldRepaint(covariant WhatsAppMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
