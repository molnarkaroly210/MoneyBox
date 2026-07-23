import 'package:flutter/material.dart';

class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final bool fillGradient;
  final double strokeWidth;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.color,
    this.fillGradient = false,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(
        data: data,
        color: color,
        fillGradient: fillGradient,
        strokeWidth: strokeWidth,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool fillGradient;
  final double strokeWidth;

  const _SparklinePainter({
    required this.data,
    required this.color,
    required this.fillGradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : maxVal - minVal;
    final padding = range * 0.15;
    final lo = minVal - padding;
    final hi = maxVal + padding;
    final span = hi - lo;

    double xOf(int i) => (i / (data.length - 1)) * size.width;
    double yOf(double v) => size.height * (1.0 - (v - lo) / span);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = xOf(i);
      final y = yOf(data[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = xOf(i - 1);
        final py = yOf(data[i - 1]);
        final cx = (px + x) / 2;
        path.cubicTo(cx, py, cx, y, x, y);
      }
    }

    if (fillGradient) {
      final fillPath = Path()..addPath(path, Offset.zero);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(70), color.withAlpha(0)],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || old.data.length != data.length || old.fillGradient != fillGradient;
}
