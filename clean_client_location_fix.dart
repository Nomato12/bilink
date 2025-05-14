// A clean approach to fixing the client location display issues

import 'dart:io';

void main() async {
  try {
    print('🔧 Starting clean fix for client location display issues');
    
    // Step 1: Fix the NotificationService
    await fixNotificationService();
    
    print('\n✅ NotificationService fix completed successfully!');
    print('The next step is to fix the ClientDetailsScreen structure.');
    print('Due to complex formatting issues, this will need to be done carefully.');
    print('\nRecommendation: Use the fix_client_details_screen.dart file to replace');
    print('the contents of lib/screens/client_details_screen.dart');
  } catch (e) {
    print('\n❌ Error applying fixes: $e');
  }
}

Future<void> fixNotificationService() async {
  print('\n📋 Fixing NotificationService...');
  
  final filePath = 'lib/services/notification_service.dart';
  final file = File(filePath);
  
  if (!await file.exists()) {
    throw 'NotificationService file not found at $filePath';
  }
  
  final content = await file.readAsString();
  
  // Make sure empty transport requests return an empty object instead of null
  final emptyRequestPattern = 'print(\'No accepted transport requests found for client: \$clientId\');\n        return null; // No transport requests found';
  
  final emptyRequestReplacement = '''print('No accepted transport requests found for client: \$clientId');
        
        // Even though there are no transport requests, return a basic details object
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
        };''';
  
  // Check if the fix is already applied
  if (content.contains('Even though there are no transport requests')) {
    print('  ✓ NotificationService already has the fix for empty transport requests');
    return;
  }
  
  // Apply the fix
  if (content.contains(emptyRequestPattern)) {
    final updatedContent = content.replaceFirst(emptyRequestPattern, emptyRequestReplacement);
    await file.writeAsString(updatedContent);
    print('  ✓ Applied fix for empty transport requests');
  } else {
    print('  ⚠️ Could not find the exact pattern for empty transport requests');
    print('    You may need to manually update the NotificationService');
    print('    Replace the "return null" when no transport requests are found with:');
    print('\n```dart');
    print(emptyRequestReplacement);
    print('```\n');
  }
}
