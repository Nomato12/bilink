import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the original image
  final ByteData data = await rootBundle.load('assets/images/Design sans titre.png');
  final Uint8List bytes = data.buffer.asUint8List();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo fi = await codec.getNextFrame();
  final ui.Image originalImage = fi.image;
  
  // Create the circular app icon
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Draw white background circle
  final Paint circlePaint = Paint()..color = Colors.white;
  canvas.drawCircle(
    Offset(512, 512),
    512,
    circlePaint,
  );
  
  // Calculate size to fit the image within the circle with some padding
  final double scale = 0.7; // Adjust this value to change the size of the logo within the circle
  final double imageSize = 1024 * scale;
  final double leftPosition = (1024 - imageSize) / 2;
  final double topPosition = (1024 - imageSize) / 2;
  
  // Draw the original image centered in the circle
  canvas.drawImageRect(
    originalImage, 
    Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
    Rect.fromLTWH(leftPosition, topPosition, imageSize, imageSize),
    Paint(),
  );
  
  final ui.Picture picture = recorder.endRecording();
  final ui.Image fullIcon = await picture.toImage(1024, 1024);
  final ByteData fullIconData = await fullIcon.toByteData(format: ui.ImageByteFormat.png) as ByteData;
  
  // Save the full app icon
  final File fullIconFile = File('assets/images/app_icon.png');
  await fullIconFile.writeAsBytes(fullIconData.buffer.asUint8List());

  // Create the foreground image (just the logo without background for adaptive icons)
  final recorderForeground = ui.PictureRecorder();
  final canvasForeground = Canvas(recorderForeground);

  // Draw the original image centered
  canvasForeground.drawImageRect(
    originalImage, 
    Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
    Rect.fromLTWH(leftPosition, topPosition, imageSize, imageSize),
    Paint(),
  );
  
  final ui.Picture pictureForeground = recorderForeground.endRecording();
  final ui.Image foregroundIcon = await pictureForeground.toImage(1024, 1024);
  final ByteData foregroundIconData = await foregroundIcon.toByteData(format: ui.ImageByteFormat.png) as ByteData;
  
  // Save the foreground icon
  final File foregroundIconFile = File('assets/images/app_icon_foreground.png');
  await foregroundIconFile.writeAsBytes(foregroundIconData.buffer.asUint8List());
  
  print('Icons generated successfully!');
  exit(0);
}
