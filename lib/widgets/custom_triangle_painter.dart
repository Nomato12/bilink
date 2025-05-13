import 'package:flutter/material.dart';

/// A custom triangle painter to use as a dropdown arrow icon
/// This class creates a simple downward-pointing triangle that can replace the default icons
class CustomTrianglePainter extends CustomPainter {
  final Color color;
  
  CustomTrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
