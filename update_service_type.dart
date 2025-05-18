import 'dart:io';

void main() {
  // Read the service_request_card.dart file
  final serviceRequestCardPath = 'lib/widgets/service_request_card.dart';
  var content = File(serviceRequestCardPath).readAsStringSync();

  // Fix the service type detection
  content = content.replaceFirst(
    'final String serviceType = requestData[\'serviceType\'] ?? \'تخزين\';',
    '''// Determine service type more accurately - look at multiple indicators
    String serviceType;
    if (requestData['serviceType'] != null) {
      // If serviceType is explicitly set in the data, use it
      serviceType = requestData['serviceType'];
    } else if (requestData['originLocation'] != null && requestData['destinationLocation'] != null) {
      // If we have origin and destination locations, it's definitely a transport service
      serviceType = 'نقل';
    } else if (details.toLowerCase().contains('نقل')) {
      // Check if details mention transport
      serviceType = 'نقل';
    } else {
      // Default to storage
      serviceType = 'تخزين';
    }''');

  // Fix price calculation for when price is zero or invalid
  content = content.replaceFirst(
    '''// If we have origin and destination location but no price, calculate it
    if (price <= 0 && serviceType == 'نقل' && originLocation != null && destinationLocation != null && vehicleType.isNotEmpty) {''',
    '''// If we have origin and destination location but no price, calculate it
    if ((price <= 0 || price.isNaN) && serviceType == 'نقل' && originLocation != null && destinationLocation != null && vehicleType.isNotEmpty) {''');

  // Write the updated content back to the file
  File(serviceRequestCardPath).writeAsStringSync(content);
  print('Updated $serviceRequestCardPath with better service type detection');

  // Now update transport_request_card.dart to ensure it always identifies as transport
  final transportRequestCardPath = 'lib/widgets/transport_request_card.dart';
  content = File(transportRequestCardPath).readAsStringSync();
  
  // Make sure TransportRequestCard always sets serviceType to 'نقل' explicitly
  content = content.replaceFirst(
    'final String serviceName = requestData[\'serviceName\'] ?? \'خدمة نقل\';',
    '''final String serviceName = requestData['serviceName'] ?? 'خدمة نقل';
    // Always ensure transport service type
    if (!requestData.containsKey('serviceType')) {
      requestData['serviceType'] = 'نقل';
    }''');
  
  // Write the updated content back to the file
  File(transportRequestCardPath).writeAsStringSync(content);
  print('Updated $transportRequestCardPath to always identify as transport');
  
  print('Service type detection fixes completed!');
}
