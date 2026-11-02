import 'package:flutter/material.dart';

/// A small, original shark mark used as the Aluminum Ainaki brand symbol.
class SharkLogo extends StatelessWidget {
  final Color color;
  final double size;

  const SharkLogo({
    super.key,
    this.color = Colors.white,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SharkPainter(color),
    );
  }
}

class _SharkPainter extends CustomPainter {
  final Color color;

  const _SharkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36;
    final sy = size.height / 36;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Body and pointed snout, facing right.
    final body = Path()
      ..moveTo(6, 18)
      ..cubicTo(10, 10, 20, 9, 26, 14)
      ..lineTo(33, 12)
      ..lineTo(29, 18)
      ..lineTo(33, 24)
      ..lineTo(24, 22)
      ..cubicTo(17, 27, 10, 24, 6, 20)
      ..close();
    canvas.drawPath(body, paint);

    // Tail fin.
    final tail = Path()
      ..moveTo(7, 18)
      ..lineTo(1, 10)
      ..lineTo(3, 18)
      ..lineTo(1, 26)
      ..lineTo(7, 20)
      ..close();
    canvas.drawPath(tail, paint);

    // Dorsal fin.
    final dorsal = Path()
      ..moveTo(14, 12)
      ..lineTo(19, 3)
      ..lineTo(24, 13)
      ..close();
    canvas.drawPath(dorsal, paint);

    // Lower fin.
    final lowerFin = Path()
      ..moveTo(17, 22)
      ..lineTo(22, 31)
      ..lineTo(25, 22)
      ..close();
    canvas.drawPath(lowerFin, paint);

    // Eye cut-out.
    final eyePaint = Paint()
      ..color = color == Colors.white ? const Color(0xFFC62828) : Colors.white
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(27.2, 16.2), 0.85, eyePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SharkPainter oldDelegate) =>
      oldDelegate.color != color;
}
