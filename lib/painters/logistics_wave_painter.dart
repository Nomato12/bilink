import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom painter that draws a wave-like pattern for logistics UI elements
class LogisticsWavePainter extends CustomPainter {
  final Color color;
  final double amplitude;
  final double frequency;
  
  LogisticsWavePainter({
    required this.color, 
    this.amplitude = 5.0,
    this.frequency = 0.5
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    // Start at the left edge
    path.moveTo(0, 0);
    
    // Draw the top wavy line
    for (double x = 0; x <= size.width; x++) {
      double y = amplitude * math.sin((x / size.width) * 2 * math.pi * frequency);
      path.lineTo(x, y);
    }
    
    // Complete the path to fill the area
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => 
    (oldDelegate as LogisticsWavePainter).color != color ||
    (oldDelegate).amplitude != amplitude ||
    (oldDelegate).frequency != frequency;
}

/// A custom painter that draws connection points for logistics nodes
class LogisticsConnectionsPainter extends CustomPainter {
  final Color color;
  final int pointCount;
  
  LogisticsConnectionsPainter({
    required this.color,
    this.pointCount = 5
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistency
    
    final points = List.generate(pointCount, (_) {
      return Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height
      );
    });
    
    // Draw connections
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], paint);
      }
    }
    
    // Draw points
    for (final point in points) {
      canvas.drawCircle(point, 3, nodePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
