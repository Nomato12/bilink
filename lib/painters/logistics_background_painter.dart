// This is a temporary file to hold the code for creating a logistics-themed background
// The actual image should be placed in assets/images/logistics_background.jpg

import 'package:flutter/material.dart';

class LogisticsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    
    // Create a gradient background
    final Rect rect = Offset.zero & size;
    final LinearGradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF053B6D),
        Color(0xFF1565C0),
      ],
    );
    
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    // Draw network pattern
    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final Paint nodePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    // Draw a logistics network pattern
    final double spacing = size.width / 10;
    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 10; j++) {
        final Offset point = Offset(i * spacing, j * spacing);
        canvas.drawCircle(point, 3, nodePaint);
        
        if (i < 9) {
          canvas.drawLine(
            point, 
            Offset((i + 1) * spacing, j * spacing), 
            linePaint
          );
        }
        
        if (j < 9) {
          canvas.drawLine(
            point, 
            Offset(i * spacing, (j + 1) * spacing), 
            linePaint
          );
        }
        
        if (i < 9 && j < 9) {
          canvas.drawLine(
            point, 
            Offset((i + 1) * spacing, (j + 1) * spacing), 
            linePaint
          );
        }
      }
    }
    
    // Draw logistics icons
    final Paint iconPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    // Add some shipping icons or symbols
    _drawTruckIcon(canvas, Offset(size.width * 0.2, size.height * 0.3), size.width * 0.1, iconPaint);
    _drawWarehouseIcon(canvas, Offset(size.width * 0.7, size.height * 0.6), size.width * 0.15, iconPaint);
    _drawBoxesIcon(canvas, Offset(size.width * 0.4, size.height * 0.8), size.width * 0.08, iconPaint);
  }
  
  void _drawTruckIcon(Canvas canvas, Offset position, double size, Paint paint) {
    final Path path = Path();
    
    // Simple truck shape
    path.moveTo(position.dx, position.dy);
    path.lineTo(position.dx + size * 0.7, position.dy);
    path.lineTo(position.dx + size * 0.7, position.dy - size * 0.4);
    path.lineTo(position.dx + size, position.dy - size * 0.4);
    path.lineTo(position.dx + size, position.dy);
    path.lineTo(position.dx + size, position.dy + size * 0.5);
    path.lineTo(position.dx, position.dy + size * 0.5);
    path.close();
    
    // Wheels
    final wheelRadius = size * 0.15;
    canvas.drawCircle(Offset(position.dx + size * 0.2, position.dy + size * 0.5), wheelRadius, paint);
    canvas.drawCircle(Offset(position.dx + size * 0.8, position.dy + size * 0.5), wheelRadius, paint);
    
    canvas.drawPath(path, paint);
  }
  
  void _drawWarehouseIcon(Canvas canvas, Offset position, double size, Paint paint) {
    final Path path = Path();
    
    // Simple warehouse shape
    path.moveTo(position.dx, position.dy);
    path.lineTo(position.dx + size, position.dy);
    path.lineTo(position.dx + size, position.dy - size * 0.8);
    path.lineTo(position.dx + size * 0.5, position.dy - size);
    path.lineTo(position.dx, position.dy - size * 0.8);
    path.close();
    
    // Door
    final doorPath = Path();
    doorPath.moveTo(position.dx + size * 0.35, position.dy);
    doorPath.lineTo(position.dx + size * 0.65, position.dy);
    doorPath.lineTo(position.dx + size * 0.65, position.dy - size * 0.4);
    doorPath.lineTo(position.dx + size * 0.35, position.dy - size * 0.4);
    doorPath.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(doorPath, paint);
  }
  
  void _drawBoxesIcon(Canvas canvas, Offset position, double size, Paint paint) {
    // Box 1
    final box1 = Rect.fromLTWH(
      position.dx, 
      position.dy, 
      size * 0.6, 
      size * 0.6
    );
    
    // Box 2
    final box2 = Rect.fromLTWH(
      position.dx + size * 0.2, 
      position.dy - size * 0.4, 
      size * 0.6, 
      size * 0.6
    );
    
    canvas.drawRect(box1, paint);
    canvas.drawRect(box2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// This is a sample widget to use the painter
class LogisticsBackgroundWidget extends StatelessWidget {
  const LogisticsBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LogisticsBackgroundPainter(),
      size: Size(600, 800), // Adjust to desired image size
    );
  }
}
