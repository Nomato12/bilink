// Fix duplicate _showClientLocationOnMap method and parameter mismatch issue
// in service_request_card.dart

import 'dart:io';

void main() async {
  final filePath = 'lib/widgets/service_request_card.dart';
  
  try {
    // Read the original file content
    final file = File(filePath);
    if (!await file.exists()) {
      print('Error: File not found: $filePath');
      return;
    }
    
    String content = await file.readAsString();
    
    // First remove the duplicate method definition (second implementation)
    final secondMethodStart = content.indexOf('  // Function to display client location on a map');
    final secondMethodEnd = content.indexOf('  // Show dialog with options for client location');
    
    if (secondMethodStart != -1 && secondMethodEnd != -1) {
      final beforeMethod = content.substring(0, secondMethodStart);
      final afterMethod = content.substring(secondMethodEnd);
      content = beforeMethod + afterMethod;
      print('✓ Removed duplicate _showClientLocationOnMap method');
    } else {
      print('! Could not find second implementation of _showClientLocationOnMap');
    }
    
    // Fix the initialPosition parameter issue for RequestLocationMap
    final wrongParameterText = 'initialPosition: LatLng(clientLocation.latitude, clientLocation.longitude),';
    final correctedParameterText = 'location: clientLocation,';
    
    if (content.contains(wrongParameterText)) {
      content = content.replaceAll(wrongParameterText, correctedParameterText);
      print('✓ Fixed parameter mismatch (initialPosition -> location)');
    } else {
      print('! Could not find initialPosition parameter');
    }
    
    // Write the updated content back to the file
    await file.writeAsString(content);
    print('✅ Successfully updated service_request_card.dart');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
