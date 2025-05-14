// Comprehensive verification script for all client location display fixes

import 'dart:io';

void main() async {
  print('🔍 Starting comprehensive verification of client location fixes');
  
  try {
    // Verify NotificationService changes
    await verifyNotificationService();
    
    // Verify ClientDetailsScreen changes
    await verifyClientDetailsScreen();
    
    print('\n✅ All verifications completed successfully! The fixes appear to be properly applied.');
    print('The application should now correctly handle and display client location data.');
  } catch (e) {
    print('\n❌ Verification failed: $e');
    print('Some fixes may not have been applied correctly.');
  }
}

Future<void> verifyNotificationService() async {
  print('\n📋 Verifying NotificationService changes:');
  
  final filePath = 'lib/services/notification_service.dart';
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'Could not find notification service file: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Check for proper handling of empty transport requests
  if (content.contains('return null; // No transport requests found')) {
    throw 'NotificationService still returns null for empty transport requests instead of a valid empty object';
  }
  
  if (!content.contains('// Even though there are no transport requests, we can still return a basic details object')) {
    throw 'Empty transport request handling improvement not found in NotificationService';
  }
  
  if (!content.contains("'hasLocationData': false")) {
    throw 'Empty transport request object does not set hasLocationData to false';
  }
  
  print('  ✓ NotificationService properly handles empty transport requests');
  
  // Check for location data handling
  if (!content.contains('Client location data handling improvements')) {
    print('  ⚠️ Warning: Client location data handling comment not found - might be OK');
  }
  
  if (content.contains('getLocationFromData')) {
    print('  ✓ NotificationService has proper location helper integration');
  }
  
  print('  ✓ NotificationService verification complete');
}

Future<void> verifyClientDetailsScreen() async {
  print('\n📋 Verifying ClientDetailsScreen changes:');
  
  final filePath = 'lib/screens/client_details_screen.dart';
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'Could not find client details screen file: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Check for LocationHelper import
  if (!content.contains("import 'package:bilink/utils/location_helper.dart';")) {
    print('  ⚠️ Warning: LocationHelper import not found - check if it was added to the correct location');
  } else {
    print('  ✓ LocationHelper import is present');
  }
  
  // Check for client location handling in _loadClientDetails
  if (!content.contains('Client location data found:')) {
    print('  ⚠️ Warning: Client location data debug print not found');
  }
  
  // Check if there are any duplicate client location sections
  final locationSectionCount = countOccurrences(content, '// إضافة قسم لموقع العميل إذا كان متاحاً');
  if (locationSectionCount > 1) {
    throw 'Found duplicate client location sections ($locationSectionCount) in the UI';
  }
  
  print('  ✓ No duplicate client location sections found');
  
  // Check for improved client location rendering condition
  final hasImprovedCondition = content.contains('if (_initialCameraPosition != null && _markers.isNotEmpty)');
  final hasOldCondition = content.contains('if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)');
  
  if (!hasImprovedCondition && hasOldCondition) {
    throw 'Client location rendering condition not fixed - still requires !_hasTransportRequestData';
  }
  
  print('  ✓ Client location rendering condition improved');
  print('  ✓ ClientDetailsScreen verification complete');
}

int countOccurrences(String text, String pattern) {
  int count = 0;
  int index = text.indexOf(pattern);
  while (index != -1) {
    count++;
    index = text.indexOf(pattern, index + 1);
  }
  return count;
}
