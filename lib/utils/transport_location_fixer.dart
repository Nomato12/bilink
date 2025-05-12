// Apply Transport Location Fix
//
// This script fixes the transport location display issue by ensuring
// the data structure in service_locations is correct and compatible
// with client display
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransportLocationFixer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Main fix function - updates all transport service locations to proper format
  Future<Map<String, dynamic>> fixTransportLocations() async {
    int success = 0;
    int failed = 0;
    List<String> fixedServices = [];
    List<String> errorServices = [];
    
    try {
      // Get all transport services
      final services = await _firestore
          .collection('services')
          .where('type', isEqualTo: 'نقل')
          .where('isActive', isEqualTo: true)
          .get();
      
      print("TransportLocationFixer: Found ${services.docs.length} active transport services");
      
      // Process each service
      for (var doc in services.docs) {
        try {
          final serviceId = doc.id;
          final serviceData = doc.data();
          
          print("TransportLocationFixer: Fixing location for service $serviceId");
          
          // Extract valid location information if available
          Map<String, dynamic>? locationData;
          
          if (serviceData.containsKey('location') && serviceData['location'] != null) {
            final location = serviceData['location'];
            
            if (location is Map && 
                location.containsKey('latitude') && 
                location.containsKey('longitude')) {
              
              final lat = location['latitude'];
              final lng = location['longitude'];
              
              if (lat is num && lng is num) {
                locationData = {
                  'latitude': lat.toDouble(),
                  'longitude': lng.toDouble(),
                  'address': location['address'] ?? 'العنوان غير متوفر',
                };
              }
            }
          }
          
          // Use default location if none found
          if (locationData == null) {
            // Create a stable random location based on service ID
            final int hashCode = serviceId.hashCode;
            final double latOffset = (hashCode % 100) / 10000.0;
            final double lngOffset = (hashCode % 50) / 10000.0;
            
            locationData = {
              'latitude': 36.7538 + latOffset,
              'longitude': 3.0588 + lngOffset,
              'address': 'موقع افتراضي - الجزائر',
            };
            
            print("TransportLocationFixer: Using default location for $serviceId");
          }
          
          // Update service document
          await _firestore.collection('services').doc(serviceId).update({
            'location': locationData,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });
          
          // Ensure service_locations has correct position structure
          await _firestore.collection('service_locations').doc(serviceId).set({
            'serviceId': serviceId,
            'providerId': serviceData['providerId'],
            'position': {
              'latitude': locationData['latitude'],
              'longitude': locationData['longitude'],
              'geopoint': GeoPoint(
                locationData['latitude'], 
                locationData['longitude'],
              ),
            },
            'address': locationData['address'],
            'lastUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          success++;
          fixedServices.add(serviceId);
          print("TransportLocationFixer: Fixed location for $serviceId");
        } catch (e) {
          failed++;
          errorServices.add(doc.id);
          print("TransportLocationFixer: Error fixing service ${doc.id}: $e");
        }
      }
    } catch (e) {
      print("TransportLocationFixer: General error: $e");
    }
    
    return {
      'success': success,
      'failed': failed,
      'fixedServices': fixedServices,
      'errorServices': errorServices,
    };
  }
  
  // Show results dialog
  static void showResultsDialog(BuildContext context, Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('نتائج إصلاح مواقع خدمات النقل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم إصلاح: ${results['success']} خدمة'),
              Text('فشل إصلاح: ${results['failed']} خدمة'),
              if (results['fixedServices'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('الخدمات التي تم إصلاحها:'),
                Container(
                  height: 100,
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(results['fixedServices'].join(', ')),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }
  
  // Run the fixer and show results dialog
  static Future<void> runAndShowResults(BuildContext context) async {
    final TransportLocationFixer fixer = TransportLocationFixer();
    final results = await fixer.fixTransportLocations();
    
    if (context.mounted) {
      showResultsDialog(context, results);
    }
  }
}
