// This script verifies the service request notification system and fixes any issues found

import 'dart:io';

void main() async {
  print('Verifying service request notification system...');
  
  // 1. Check that all required files exist
  final requiredFiles = [
    'lib/widgets/service_request_card.dart',
    'lib/widgets/notification_badge.dart',
    'lib/services/service_request_notification_service.dart',
  ];
  
  for (final file in requiredFiles) {
    final exists = await File(file).exists();
    print('$file exists: $exists');
    
    if (!exists) {
      print('ERROR: Required file $file does not exist');
      exit(1);
    }
  }
  
  // 2. Verify imports in the required files
  print('\nChecking imports in client_interface.dart...');
  final clientInterfaceContent = await File('lib/screens/client_interface.dart').readAsString();
  final requiredImports = [
    "import 'package:bilink/widgets/notification_badge.dart';",
    "import 'package:bilink/services/service_request_notification_service.dart';",
  ];
  
  for (final import in requiredImports) {
    if (!clientInterfaceContent.contains(import)) {
      print('Missing import in client_interface.dart: $import');
      
      // Add the import if needed
      final newContent = clientInterfaceContent.replaceFirst(
        "import 'package:bilink/services/auth_service.dart';", 
        "import 'package:bilink/services/auth_service.dart';\n$import"
      );
      
      await File('lib/screens/client_interface.dart').writeAsString(newContent);
      print('Added missing import to client_interface.dart');
    }
  }
  
  // 3. Verify the notification badge is correctly displayed
  if (!clientInterfaceContent.contains('NotificationBadge(count: acceptedCount)')) {
    print('WARNING: Notification badge might not be correctly displayed in client_interface.dart');
  }
  
  print('\nService request notification system verification complete.');
  print('Rebuilding application should now fix the notification display issues.');
}
