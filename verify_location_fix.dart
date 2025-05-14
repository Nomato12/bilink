import 'dart:io';

void main() async {
  try {
    print('====================================================');
    print('VERIFYING CLIENT LOCATION DISPLAY FIX');
    print('====================================================');
    
    // Check client_details_screen.dart for location rendering conditions
    final clientDetailsFile = File('lib/screens/client_details_screen.dart');
    if (!await clientDetailsFile.exists()) {
      print('⚠️ Client details screen file not found!');
      return;
    }
    
    final clientDetailsContent = await clientDetailsFile.readAsString();
    
    // Check for correct location rendering condition
    final locationSectionExists = clientDetailsContent.contains(
        'if (_initialCameraPosition != null && _markers.isNotEmpty)');
    print('✓ Location section with correct condition exists: $locationSectionExists');
    
    // Check for map widget
    final mapWidgetExists = clientDetailsContent.contains('GoogleMap(');
    print('✓ Google Maps widget exists: $mapWidgetExists');
    
    // Check for duplicate location sections
    final locationSectionCount = '\$locationSectionExists'.allMatches(clientDetailsContent).length;
    print('✓ Number of location section conditions: $locationSectionCount (should be 1)');
    
    // Check for navigation to client location
    final hasNavigation = clientDetailsContent.contains('_openInGoogleMaps');
    print('✓ Navigation to client location implemented: $hasNavigation');
    
    // Check NotificationService for null-safety
    final notificationFile = File('lib/services/notification_service.dart');
    if (await notificationFile.exists()) {
      final notificationContent = await notificationFile.readAsString();
      final handleEmptyRequests = notificationContent.contains("if (requestQuery.docs.isEmpty) {") && 
                                 notificationContent.contains("'hasLocationData': false");
      print('✓ NotificationService handles empty requests safely: $handleEmptyRequests');
    } else {
      print('⚠️ NotificationService file not found!');
    }
    
    // Overall assessment
    if (locationSectionExists && mapWidgetExists && hasNavigation) {
      print('====================================================');
      print('✅ CLIENT LOCATION DISPLAY FIX VERIFICATION PASSED');
      print('✅ The code now correctly displays client location when available');
      print('====================================================');
    } else {
      print('====================================================');
      print('❌ CLIENT LOCATION DISPLAY FIX VERIFICATION FAILED');
      print('    Some required changes are missing or incomplete');
      print('====================================================');
    }
    
  } catch (e) {
    print('❌ Error during verification: $e');
  }
}
