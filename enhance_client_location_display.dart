// enhance_client_location_display.dart
// Script to enhance client location display in ClientDetailsScreen when no transport requests exist

import 'dart:io';

void main() async {
  // Path to the file to fix
  final filePath = 'lib/screens/client_details_screen.dart';
  final notificationServicePath = 'lib/services/notification_service.dart';
  
  try {
    // Update getClientTransportRequestDetails in NotificationService
    await updateNotificationService(notificationServicePath);
    print('✅ Updated NotificationService.getClientTransportRequestDetails method to handle missing requests gracefully');
    
    // Update _loadClientDetails method to better handle client location when no transport requests exist
    await updateLoadClientDetailsMethod(filePath);
    print('✅ Updated _loadClientDetails method to properly handle client location without transport requests');
    
    print('\n🎉 Client location display enhancement completed successfully!');
    print('Test the fix by viewing client details to see if their location appears correctly.');
  } catch (e) {
    print('❌ Error applying enhancement: $e');
  }
}

Future<void> updateNotificationService(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'File not found: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Find the getClientTransportRequestDetails method
  final methodStart = content.indexOf('Future<Map<String, dynamic>?> getClientTransportRequestDetails(String clientId) async {');
  if (methodStart == -1) {
    throw 'Could not find getClientTransportRequestDetails method in NotificationService';
  }
  
  // Find where the empty result is returned
  final emptyResultLineIndex = content.indexOf('print(\'No accepted transport requests found for client: \$clientId\');', methodStart);
  if (emptyResultLineIndex == -1) {
    throw 'Could not find empty result handling in getClientTransportRequestDetails';
  }
  
  // Find the return null line
  final returnNullLineIndex = content.indexOf('return null; // No transport requests found', emptyResultLineIndex);
  if (returnNullLineIndex == -1) {
    throw 'Could not find return null statement in getClientTransportRequestDetails';
  }
  
  // Define the new code to replace the empty result handling
  final newEmptyResultHandling = '''
        print('No accepted transport requests found for client: \$clientId');
        
        // Even though there are no transport requests, we can still return a basic details object
        // with hasLocationData set to false to prevent null errors in the UI
        return {
          'requestId': '',
          'originName': '',
          'destinationName': '',
          'distanceText': '',
          'durationText': '',
          'price': 0.0,
          'vehicleType': '',
          'hasLocationData': false
        }; // Return empty details instead of null''';
  
  // Replace the empty result handling with our enhanced version
  final updatedContent = content.substring(0, emptyResultLineIndex) + 
    newEmptyResultHandling + 
    content.substring(returnNullLineIndex + 'return null; // No transport requests found'.length);
  
  await file.writeAsString(updatedContent);
}

Future<void> updateLoadClientDetailsMethod(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'File not found: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Find the _loadClientDetails method
  final methodStart = content.indexOf('Future<void> _loadClientDetails() async {');
  if (methodStart == -1) {
    throw 'Could not find _loadClientDetails method';
  }
  
  // Find the if statement that checks transport details
  final transportIfIndex = content.indexOf('if (transportDetails != null &&', methodStart);
  if (transportIfIndex == -1) {
    throw 'Could not find transport details check in _loadClientDetails';
  }
  
  // Define the updated if statement
  final newTransportIf = '''
      // تحميل معلومات طلب النقل الخاص بالعميل (إن وجد)
      final transportDetails = await _notificationService
          .getClientTransportRequestDetails(widget.clientId);

      // Check if we have transport request details with location data
      if (transportDetails != null &&
          transportDetails['hasLocationData'] == true) {
        // استخراج معلومات النقل
        setState(() {
          _hasTransportRequestData = true;''';
  
  // Find the start of the transport details section
  final transportDetailsStart = content.indexOf('// تحميل معلومات طلب النقل الخاص بالعميل (إن وجد)', methodStart);
  if (transportDetailsStart == -1) {
    throw 'Could not find transport details section in _loadClientDetails';
  }
  
  // Replace the transport details section
  final updatedContent = content.substring(0, transportDetailsStart) + 
    newTransportIf + 
    content.substring(transportIfIndex + 'if (transportDetails != null &&'.length);
  
  await file.writeAsString(updatedContent);
}
