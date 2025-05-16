// This script fixes the ServiceRequestCard import issues in request_tabs.dart and notifications_screen.dart

import 'dart:io';

void main() async {
  print('Fixing ServiceRequestCard import issues...');
  
  // Fix request_tabs.dart
  final requestTabsPath = 'lib/widgets/request_tabs.dart';
  final requestTabsFile = File(requestTabsPath);
  var requestTabsContent = await requestTabsFile.readAsString();
  
  // Ensure the import is at the top of the file
  if (!requestTabsContent.contains("import 'package:bilink/widgets/service_request_card.dart';")) {
    requestTabsContent = requestTabsContent.replaceFirst(
      "import 'package:firebase_auth/firebase_auth.dart';",
      "import 'package:firebase_auth/firebase_auth.dart';\nimport 'package:bilink/widgets/service_request_card.dart';"
    );
    await requestTabsFile.writeAsString(requestTabsContent);
    print('Fixed import in request_tabs.dart');
  }
  
  // Fix notifications_screen.dart
  final notificationsScreenPath = 'lib/screens/notifications_screen.dart';
  final notificationsScreenFile = File(notificationsScreenPath);
  var notificationsScreenContent = await notificationsScreenFile.readAsString();
  
  // Ensure the import is at the top of the file
  if (!notificationsScreenContent.contains("import 'package:bilink/widgets/service_request_card.dart';")) {
    notificationsScreenContent = notificationsScreenContent.replaceFirst(
      "import 'package:bilink/services/auth_service.dart';",
      "import 'package:bilink/services/auth_service.dart';\nimport 'package:bilink/widgets/service_request_card.dart';"
    );
    await notificationsScreenFile.writeAsString(notificationsScreenContent);
    print('Fixed import in notifications_screen.dart');
  }
  
  // Verify service_request_card.dart exists and is valid
  final serviceRequestCardPath = 'lib/widgets/service_request_card.dart';
  final serviceRequestCardFile = File(serviceRequestCardPath);
  
  if (!await serviceRequestCardFile.exists()) {
    print('ERROR: service_request_card.dart does not exist. This is a critical error.');
    return;
  }
  
  final serviceRequestCardContent = await serviceRequestCardFile.readAsString();
  if (!serviceRequestCardContent.contains('class ServiceRequestCard extends StatelessWidget')) {
    print('ERROR: service_request_card.dart does not contain the ServiceRequestCard class definition.');
    return;
  }
  
  print('\nImport issues fixed. Rebuilding the application should resolve the ServiceRequestCard errors.');
}
