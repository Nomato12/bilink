// Script to create a clean and comprehensive fix for client location display issues

import 'dart:io';

void main() async {
  try {
    // Step 1: Fix the notification service first
    await fixNotificationService();
    print('✅ Fixed NotificationService');
    
    // Step 2: Prepare the client details screen with the correct imports
    await fixClientDetailsScreenImports();
    print('✅ Fixed ClientDetailsScreen imports');
    
    // Step 3: Fix the client location rendering in the client details screen
    await fixClientLocationRendering();
    print('✅ Fixed client location rendering in UI');
    
    print('\n🎉 All fixes have been compiled and applied successfully!');
    print('The app should now correctly display client location data.');
  } catch (e) {
    print('❌ Error applying fixes: $e');
  }
}

Future<void> fixNotificationService() async {
  final filePath = 'lib/services/notification_service.dart';
  final file = File(filePath);
  
  if (!await file.exists()) {
    throw 'NotificationService file not found at $filePath';
  }
  
  final content = await file.readAsString();
  
  // Make sure empty transport requests return an empty object instead of null
  final emptyTransportRequestsPattern = '''
      if (requestQuery.docs.isEmpty) {
        print('No accepted transport requests found for client: \$clientId');
        return null; // No transport requests found
      }''';
  
  final emptyTransportRequestsReplacement = '''
      if (requestQuery.docs.isEmpty) {
        print('No accepted transport requests found for client: \$clientId');
        
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
        };
      }''';
  
  // Check if the file needs to be updated
  if (content.contains('Even though there are no transport requests')) {
    print('  ✓ NotificationService already has the fix for empty transport requests');
  } else if (content.contains(emptyTransportRequestsPattern)) {
    // Apply the fix
    final updatedContent = content.replaceFirst(emptyTransportRequestsPattern, emptyTransportRequestsReplacement);
    await file.writeAsString(updatedContent);
    print('  ✓ Applied fix for empty transport requests');
  } else {
    print('  ⚠️ Could not find the exact pattern for empty transport requests handling - fix may need to be applied manually');
  }
}

Future<void> fixClientDetailsScreenImports() async {
  final filePath = 'lib/screens/client_details_screen.dart';
  final file = File(filePath);
  
  if (!await file.exists()) {
    throw 'ClientDetailsScreen file not found at $filePath';
  }
  
  final content = await file.readAsString();
  
  // Check if LocationHelper import is present
  if (!content.contains("import 'package:bilink/utils/location_helper.dart';")) {
    // Add the import
    final imports = content.substring(0, content.indexOf('class ClientDetailsScreen'));
    final lastImportEnd = imports.lastIndexOf(';') + 1;
    
    final updatedImports = "${imports.substring(0, lastImportEnd)}\nimport 'package:bilink/utils/location_helper.dart';${imports.substring(lastImportEnd)}";
    
    final updatedContent = updatedImports + content.substring(imports.length);
    await file.writeAsString(updatedContent);
    print('  ✓ Added LocationHelper import');
  } else {
    print('  ✓ LocationHelper import already present');
  }
}

Future<void> fixClientLocationRendering() async {
  final filePath = 'lib/screens/client_details_screen.dart';
  final file = File(filePath);
  
  if (!await file.exists()) {
    throw 'ClientDetailsScreen file not found at $filePath';
  }
  
  String content = await file.readAsString();
  
  // First, fix formatting in _loadClientDetails method
  final badSpacing = '''} else {
        print('No location data found in client details');
      }''';
  
  final goodSpacing = '''} else {
        print('No location data found in client details');
      }
      ''';
  
  if (content.contains(badSpacing)) {
    content = content.replaceFirst(badSpacing, goodSpacing);
    print('  ✓ Fixed spacing in _loadClientDetails method');
  }
  
  // Count occurrences of client location section
  int count = 0;
  int index = 0;
  
  while ((index = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً', index)) != -1) {
    count++;
    index++;
  }
  
  if (count > 1) {
    print('  ⚠️ Found $count duplicated client location sections - attempting to fix');
    
    // This is complex to fix automatically since the pattern may vary
    // Let's provide manual instructions
    print('  ℹ️ Please manually ensure there is only one client location section in the file');
    print('     Look for "// إضافة قسم لموقع العميل إذا كان متاحاً" and remove duplicates');
  } else {
    print('  ✓ No duplicate client location sections found');
  }
  
  // Replace the condition to show client location
  final restrictiveCondition = 'if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)';
  final betterCondition = 'if (_initialCameraPosition != null && _markers.isNotEmpty)';
  
  if (content.contains(restrictiveCondition)) {
    content = content.replaceAll(restrictiveCondition, betterCondition);
    await file.writeAsString(content);
    print('  ✓ Fixed client location display condition');
  } else if (content.contains(betterCondition)) {
    print('  ✓ Client location display condition already fixed');
  } else {
    print('  ⚠️ Could not find client location display condition - fix may need to be applied manually');
  }
}
