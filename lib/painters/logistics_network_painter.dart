// Modern LogisticsNetworkPainter for the provider interface background
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LogisticsNetworkPainter extends CustomPainter {
  final Color color;
  final double opacity;
  
  LogisticsNetworkPainter({
    required this.color, 
    this.opacity = 0.6
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    final nodePaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
      
    final random = math.Random(12); // Fixed seed for consistent pattern
    
    // Draw logistics themed decorations
    _drawShippingRoutes(canvas, size, paint.color);
    
    // Create network nodes
    final nodes = <Offset>[];
    for (int i = 0; i < 15; i++) {
      nodes.add(Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height
      ));
    }
    
    // Draw connections between close nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = (nodes[i] - nodes[j]).distance;
        if (distance < size.width / 3) {
          // Adjust opacity based on distance
          final lineOpacity = 1 - (distance / (size.width / 3));
          paint.color = color.withOpacity(opacity * lineOpacity);
          
          // Draw dashed line for shipping routes effect
          _drawDashedLine(canvas, nodes[i], nodes[j], paint);
        }
      }
    }
    
    // Draw nodes with pulsing effect
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      // Vary node sizes based on node index
      final nodeSize = 2 + random.nextDouble() * 4;
      
      // Draw outer glow
      final glowPaint = Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node, nodeSize * 2, glowPaint);
      
      // Draw node
      canvas.drawCircle(node, nodeSize, nodePaint);
    }
  }
  
  void _drawShippingRoutes(Canvas canvas, Size size, Color color) {
    final Paint routePaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Draw curved shipping routes
    final path = Path();
    
    // Route 1 - curved path across the screen
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.1, 
      size.width, size.height * 0.3
    );
    
    // Route 2 - another curved path
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.9, 
      size.width, size.height * 0.6
    );
    
    // Route 3 - connecting path
    path.moveTo(size.width * 0.2, 0);
    path.quadraticBezierTo(
      size.width * 0.4, size.height * 0.5, 
      size.width * 0.8, size.height
    );
    
    canvas.drawPath(path, routePaint);
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final dashWidth = 5;
    final dashSpace = 5;
    final distance = (end - start).distance;
    final dashCount = distance / (dashWidth + dashSpace);
    
    final dx = (end.dx - start.dx) / dashCount;
    final dy = (end.dy - start.dy) / dashCount;
    
    Offset currentPoint = start;
    
    for (int i = 0; i < dashCount; i++) {
      final isEven = i % 2 == 0;
      
      if (isEven) {
        final p2 = Offset(
          currentPoint.dx + dx,
          currentPoint.dy + dy,
        );
        canvas.drawLine(currentPoint, p2, paint);
      }
      
      currentPoint = Offset(
        currentPoint.dx + dx,
        currentPoint.dy + dy,
      );
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
