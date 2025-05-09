import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Painter for creating logistics path decorations with dotted lines
class LogisticsPathPainter extends CustomPainter {
  final Color pathColor;
  final Color dotColor;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  LogisticsPathPainter({
    required this.pathColor,
    required this.dotColor,
    this.dashWidth = 8.0,
    this.dashSpace = 4.0,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pathPaint = Paint()
      ..color = pathColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Paint dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Draw curved paths representing logistics routes
    final path1 = Path();
    path1.moveTo(size.width * 0.2, size.height * 0.3);
    path1.quadraticBezierTo(
      size.width * 0.5, size.height * 0.1,
      size.width * 0.8, size.height * 0.4,
    );

    final path2 = Path();
    path2.moveTo(size.width * 0.1, size.height * 0.6);
    path2.quadraticBezierTo(
      size.width * 0.4, size.height * 0.8,
      size.width * 0.9, size.height * 0.5,
    );

    // Draw dashed lines
    _drawDashedPath(canvas, path1, pathPaint);
    _drawDashedPath(canvas, path2, pathPaint);

    // Draw connection points
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.4), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.6), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.5), 4, dotPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashPath = Path();
    final dashPathMetrics = path.computeMetrics();

    for (final pathMetric in dashPathMetrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < pathMetric.length) {
        final double length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
            pathMetric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for creating circular wave effects
class CircleWavePainter extends CustomPainter {
  final Color color;
  final int waveCount;

  CircleWavePainter({
    required this.color,
    this.waveCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Draw concentric circles
    for (int i = 0; i < waveCount; i++) {
      final radius = maxRadius * (0.4 + (i * 0.2));
      canvas.drawCircle(center, radius, paint);
    }

    // Draw a small solid circle in the center
    canvas.drawCircle(
      center,
      maxRadius * 0.1,
      Paint()..color = color.withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for creating a network of connected dots
class LogisticsNetworkPainter extends CustomPainter {
  final Color dotColor;
  final Color lineColor;
  final int dotCount;
  final double dotRadius;
  final double maxLineDistance;

  LogisticsNetworkPainter({
    required this.dotColor,
    required this.lineColor,
    this.dotCount = 15,
    this.dotRadius = 2.0,
    this.maxLineDistance = 100.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(42); // Fixed seed for consistent pattern
    final dots = <Offset>[];

    // Generate random dots
    for (int i = 0; i < dotCount; i++) {
      dots.add(Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ));
    }

    // Draw connections between dots that are close enough
    for (int i = 0; i < dots.length; i++) {
      for (int j = i + 1; j < dots.length; j++) {
        final distance = (dots[i] - dots[j]).distance;
        if (distance < maxLineDistance) {
          // Make line opacity based on distance
          final opacity = 1.0 - (distance / maxLineDistance);
          linePaint.color = lineColor.withOpacity(opacity * 0.8);
          canvas.drawLine(dots[i], dots[j], linePaint);
        }
      }
    }

    // Draw the dots
    for (final dot in dots) {
      canvas.drawCircle(dot, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
