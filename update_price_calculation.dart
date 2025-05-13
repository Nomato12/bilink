// Script to update price calculation in nearby_vehicles_map.dart
import 'dart:io';

void main() {
  // Path to the file to modify
  final String filePath = 'd:\\bilink\\lib\\screens\\nearby_vehicles_map.dart';
  
  try {
    // Read the file
    final File file = File(filePath);
    String content = file.readAsStringSync();
    
    // Replace the price calculation line
    final String oldLine = "                'price': _calculatePrice(widget.routeDistance ?? 0, actualVehicleType),";
    final String newLine = "                'price': _calculatePrice(_routeDistanceKm > 0 ? _routeDistanceKm : (widget.routeDistance ?? 0), actualVehicleType),";
    
    // Make the replacement
    if (content.contains(oldLine)) {
      content = content.replaceAll(oldLine, newLine);
      file.writeAsStringSync(content);
      print('Successfully updated price calculation to use route distance.');
    } else {
      print('Could not find the line to replace. Check if the file has changed.');
    }
  } catch (e) {
    print('Error updating file: $e');
  }
}
