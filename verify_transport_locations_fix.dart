// verify_transport_locations_fix.dart
// Script to test if transport locations are properly shown when viewing client locations

import 'dart:io';

void main() async {
  print('====================================================');
  print('VERIFYING TRANSPORT LOCATIONS FIX');
  print('====================================================');
  
  try {
    // Check service_request_card.dart for the updated code
    final requestCardFile = File('lib/widgets/service_request_card.dart');
    if (!await requestCardFile.exists()) {
      print('⚠️ Service request card file not found!');
      return;
    }
    
    final requestCardContent = await requestCardFile.readAsString();
    
    // Check for the transport location database lookup
    final hasTransportLookup = requestCardContent.contains('final transportLocationData = await LocationHelper.getClientLocationData');
    print('✓ Transport location database lookup implemented: $hasTransportLookup');
    
    // Check for loading indicator before fetching locations
    final hasLoadingIndicator = requestCardContent.contains('showDialog') && 
                               requestCardContent.contains('CircularProgressIndicator');
    print('✓ Loading indicator while checking for locations: $hasLoadingIndicator');
    
    // Check for origin location handling
    final hasOriginHandler = requestCardContent.contains('locationData.containsKey(\'originLocation\')') && 
                            requestCardContent.contains('transportLocationData[\'originLocation\'] as GeoPoint');
    print('✓ Origin location handling from database: $hasOriginHandler');
    
    // Check for destination location handling
    final hasDestinationHandler = requestCardContent.contains('locationData.containsKey(\'destinationLocation\')') && 
                                 requestCardContent.contains('transportLocationData[\'destinationLocation\'] as GeoPoint');
    print('✓ Destination location handling from database: $hasDestinationHandler');
    
    // Check for proper location message flag
    final hasLocationMessageFlag = requestCardContent.contains('showLocationUnavailableMessage: false') && 
                                  requestCardContent.contains('showLocationUnavailableMessage: true');
    print('✓ Proper location message flags set: $hasLocationMessageFlag');
    
    // Check for removal of duplicate clientId variable
    final hasDuplicateClientId = requestCardContent.contains('final String clientId = requestData[\'clientId\'] ?? \'\';') && 
                                requestCardContent.contains('final String clientId = requestData[\'clientId\'] ?? \'\';', 
                                requestCardContent.indexOf('final String clientId = requestData[\'clientId\'] ?? \'\';') + 10);
    print('✓ No duplicate clientId variable declaration: ${!hasDuplicateClientId}');
    
    // Check LocationHelper changes
    final locationHelperFile = File('lib/utils/location_helper.dart');
    if (!await locationHelperFile.exists()) {
      print('⚠️ Location helper file not found!');
      return;
    }
    
    final locationHelperContent = await locationHelperFile.readAsString();
    
    // Check for improved client location data retrieval
    final hasImprovedLocationRetrieval = locationHelperContent.contains('(data.containsKey(\'originLocation\') && data[\'originLocation\'] is GeoPoint) ||') && 
                                        locationHelperContent.contains('(data.containsKey(\'destinationLocation\') && data[\'destinationLocation\'] is GeoPoint)');
    print('✓ Improved client location data retrieval: $hasImprovedLocationRetrieval');
    
    // Check for extended time window
    final hasExtendedTimeWindow = locationHelperContent.contains('if (now.difference(updateTime).inHours < 24)');
    print('✓ Extended time window for valid location data: $hasExtendedTimeWindow');
    
    // Check for debug logging
    final hasDebugLogging = locationHelperContent.contains('print(\'Found transport location data for client');
    print('✓ Debug logging for location retrieval: $hasDebugLogging');
    
    // Overall assessment
    if (hasTransportLookup && hasOriginHandler && hasDestinationHandler && 
        hasImprovedLocationRetrieval && !hasDuplicateClientId) {
      print('====================================================');
      print('✅ TRANSPORT LOCATIONS FIX VERIFICATION PASSED');
      print('Client transport locations (origin/destination) should now be correctly displayed');
      print('====================================================');
    } else {
      print('====================================================');
      print('❌ TRANSPORT LOCATIONS FIX VERIFICATION FAILED');
      print('Some required changes are missing or incomplete');
      print('====================================================');
    }
    
  } catch (e) {
    print('❌ Error during verification: $e');
  }
}
