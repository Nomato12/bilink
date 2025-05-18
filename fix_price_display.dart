import 'dart:io';

void main() {
  // Read the service_request_card.dart file
  final serviceRequestCardPath = 'lib/widgets/service_request_card.dart';
  var content = File(serviceRequestCardPath).readAsStringSync();

  // Update the price container to ensure it always displays correctly for transport services
  content = content.replaceFirst(
    '''                          // Price details for transport service
                          if (serviceType == 'نقل' && vehicleType.isNotEmpty) ...[
                            // Price per km and minimum price
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'سعر الكم: \${ServiceVehiclesHelper.basePricesPerKm[vehicleType] ?? ServiceVehiclesHelper.basePricesPerKm['default']} دج',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'الحد الأدنى: \${ServiceVehiclesHelper.minimumPrices[vehicleType] ?? ServiceVehiclesHelper.minimumPrices['default']} دج',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],''',
    
    '''                          // Price details for transport service
                          if (serviceType == 'نقل') ...[
                            // Price per km and minimum price
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'سعر الكم: \${ServiceVehiclesHelper.basePricesPerKm[vehicleType] ?? ServiceVehiclesHelper.basePricesPerKm['default']} دج',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'الحد الأدنى: \${ServiceVehiclesHelper.minimumPrices[vehicleType] ?? ServiceVehiclesHelper.minimumPrices['default']} دج',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],''');
  
  // Update price formatting to ensure it always appears correctly
  content = content.replaceFirst(
    '''                              Text(
                                ServiceVehiclesHelper.formatPrice(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 18,
                                ),
                              ),''',
    
    '''                              Text(
                                price > 0 ? ServiceVehiclesHelper.formatPrice(price) : 
                                  serviceType == 'نقل' ? ServiceVehiclesHelper.formatPrice(ServiceVehiclesHelper.calculateDefaultPrice(vehicleType)) : '0 دج',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 18,
                                ),
                              ),''');

  // Write the updated content back to the file
  File(serviceRequestCardPath).writeAsStringSync(content);
  print('Updated $serviceRequestCardPath with improved price display logic');

  // Add a default price calculation method to ServiceVehiclesHelper
  final serviceVehiclesHelperPath = 'lib/services/service_vehicles_helper.dart';
  content = File(serviceVehiclesHelperPath).readAsStringSync();
  
  if (!content.contains('calculateDefaultPrice')) {
    content = content.replaceFirst(
      '''  /// Format price as a string with currency
  static String formatPrice(double price) {
    return '\${price.toInt()} دج';
  }''',
    
      '''  /// Format price as a string with currency
  static String formatPrice(double price) {
    return '\${price.toInt()} دج';
  }
  
  /// Calculate a default price for a vehicle type when no distance is available
  static double calculateDefaultPrice(String vehicleType) {
    // Return the minimum price for this vehicle type
    return minimumPrices[vehicleType] ?? minimumPrices['default']!;
  }''');

    // Write the updated content back to the file
    File(serviceVehiclesHelperPath).writeAsStringSync(content);
    print('Added calculateDefaultPrice method to ServiceVehiclesHelper');
  }
  
  print('Price display fixes completed!');
}
