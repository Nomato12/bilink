// Rename methods and fix parameters

import 'dart:io';

void main() async {
  final filePath = 'lib/widgets/service_request_card.dart';
  final backupPath = 'lib/widgets/service_request_card.dart.bak';
  
  try {
    // Backup the file
    final file = File(filePath);
    final backupFile = File(backupPath);
    await backupFile.writeAsString(await file.readAsString());
    print('✓ Created backup at $backupPath');
    
    // Read the file content
    final content = await file.readAsString();
    
    // Create a new implementation
    String newContent = content;
    
    // 1. Fix the parameter 'initialPosition' to 'location'
    if (newContent.contains('initialPosition: LatLng(clientLocation.latitude, clientLocation.longitude),')) {
      newContent = newContent.replaceAll(
        'initialPosition: LatLng(clientLocation.latitude, clientLocation.longitude),',
        'location: clientLocation,'
      );
      print('✓ Fixed initialPosition parameter');
    } else {
      print('× Could not find initialPosition parameter');
    }
    
    // 2. Rename the second _showClientLocationOnMap method to _showClientLocationOnMapRoute
    // Find the second occurrence and rename it
    final firstMethodPattern = '  void _showClientLocationOnMap(BuildContext context, GeoPoint clientLocation, String clientName, {bool showRoute = false}) async {';
    final secondMethodPattern = '  void _showClientLocationOnMap(BuildContext context, GeoPoint location, String clientName, {bool showRoute = false}) {';
    
    if (newContent.contains(secondMethodPattern)) {
      newContent = newContent.replaceFirst(
        secondMethodPattern,
        '  void _showClientLocationOnMapUsingRequestMap(BuildContext context, GeoPoint location, String clientName, {bool showRoute = false}) {'
      );
      print('✓ Renamed duplicate method');
      
      // Update all references to this method
      newContent = newContent.replaceAll(
        '_showClientLocationOnMap(context, location, clientName);', 
        '_showClientLocationOnMapUsingRequestMap(context, location, clientName);'
      );
      
      newContent = newContent.replaceAll(
        '_showClientLocationOnMap(context, location, clientName, showRoute: true);', 
        '_showClientLocationOnMapUsingRequestMap(context, location, clientName, showRoute: true);'
      );
      
      print('✓ Updated method references');
    } else {
      print('× Could not find second method');
    }
    
    // Write the fixed content back
    await file.writeAsString(newContent);
    print('✅ Successfully fixed service_request_card.dart');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
