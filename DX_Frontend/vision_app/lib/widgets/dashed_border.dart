import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = Colors.white38,
    this.strokeWidth = 1.2,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashGap: dashGap,
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topLeftRadius = borderRadius.topLeft.x;
    final topRightRadius = borderRadius.topRight.x;
    final bottomRightRadius = borderRadius.bottomRight.x;
    final bottomLeftRadius = borderRadius.bottomLeft.x;

    void drawDashedLine(Offset start, Offset end) {
      final totalLength = (end - start).distance;
      if (totalLength == 0) return;
      final direction = (end - start) / totalLength;
      double progress = 0;
      while (progress < totalLength) {
        final currentDash = math.min(dashWidth, totalLength - progress);
        final dashStart = start + direction * progress;
        final dashEnd = start + direction * (progress + currentDash);
        canvas.drawLine(dashStart, dashEnd, paint);
        progress += currentDash + dashGap;
      }
    }

    drawDashedLine(
      Offset(topLeftRadius, 0),
      Offset(size.width - topRightRadius, 0),
    );
    drawDashedLine(
      Offset(size.width, topRightRadius),
      Offset(size.width, size.height - bottomRightRadius),
    );
    drawDashedLine(
      Offset(size.width - bottomRightRadius, size.height),
      Offset(bottomLeftRadius, size.height),
    );
    drawDashedLine(
      Offset(0, size.height - bottomLeftRadius),
      Offset(0, topLeftRadius),
    );
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.borderRadius != borderRadius;
  }
}



