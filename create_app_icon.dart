import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main() async {
  // Path to original image
  final String originalImagePath = 'assets/images/Design sans titre.png';
  
  // Create output directory if it doesn't exist
  Directory('assets/icons').createSync(recursive: true);
  
  // Load original image
  final File originalFile = File(originalImagePath);
  if (!originalFile.existsSync()) {
    print('Original image not found at: $originalImagePath');
    exit(1);
  }
  
  final img.Image? originalImage = img.decodeImage(originalFile.readAsBytesSync());
  if (originalImage == null) {
    print('Failed to decode original image');
    exit(1);
  }
  
  // Resize image to 1024x1024 (standard app icon size)
  final img.Image resizedImage = img.copyResize(originalImage, width: 1024, height: 1024);
  
  // Create a white circle background
  final img.Image circleIcon = img.Image(width: 1024, height: 1024);
  
  // Fill with white
  img.fill(circleIcon, color: img.ColorRgba8(255, 255, 255, 255));
  
  // Draw a white circle
  img.fillCircle(circleIcon, x: 512, y: 512, radius: 512, color: img.ColorRgba8(255, 255, 255, 255));
  
  // Calculate dimensions to place the logo centered with some padding
  final double scale = 0.8; // Adjust this value to change the size of the logo within the circle
  final int iconSize = (1024 * scale).round();
  final int leftPosition = ((1024 - iconSize) / 2).round();
  final int topPosition = ((1024 - iconSize) / 2).round();
  
  // Resize the original image to fit inside the circle with padding
  final img.Image logoImage = img.copyResize(originalImage, width: iconSize, height: iconSize);
  
  // Composite the logo onto the white circle
  img.compositeImage(
    circleIcon, 
    logoImage, 
    dstX: leftPosition, 
    dstY: topPosition,
  );
  
  // Save the final app icon
  File('assets/icons/app_icon.png').writeAsBytesSync(img.encodePng(circleIcon));
  
  // Create a foreground version (for adaptive icons)
  final img.Image foregroundIcon = img.Image(width: 1024, height: 1024, format: img.Format.rgba);
  
  // Composite only the logo for foreground (transparent background)
  img.compositeImage(
    foregroundIcon, 
    logoImage, 
    dstX: leftPosition, 
    dstY: topPosition,
  );
  
  // Save the foreground icon
  File('assets/icons/app_icon_foreground.png').writeAsBytesSync(img.encodePng(foregroundIcon));
  
  print('Icons generated successfully!');
  print('App icon saved to assets/icons/app_icon.png');
  print('App icon foreground saved to assets/icons/app_icon_foreground.png');
  print('\nUpdate your pubspec.yaml to use these icons.');
}
