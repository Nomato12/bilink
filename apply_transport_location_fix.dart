// This script fixes the transport location data structure to ensure locations show on client pages
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';

void main() async {
  // Initialize Flutter and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("Transport Location Fix: Starting fix process");
  
  // Run the fix
  await fixTransportLocations();
  
  // Exit the application
  print("Transport Location Fix: Fix process completed");
}

Future<void> fixTransportLocations() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int fixed = 0;
  int errors = 0;
  
  try {
    // Get all transport services
    final servicesSnapshot = await firestore
        .collection('services')
        .where('type', isEqualTo: 'نقل')
        .get();
        
    print("Transport Location Fix: Found ${servicesSnapshot.docs.length} transport services");
    
    // Process each service
    for (final serviceDoc in servicesSnapshot.docs) {
      try {
        final serviceId = serviceDoc.id;
        final serviceData = serviceDoc.data();
        
        print("Transport Location Fix: Processing service $serviceId");
        
        // Extract location data from the service
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
              
              print("Transport Location Fix: Valid location found in service data: $lat, $lng");
            }
          }
        }
        
        // Create default location if none found
        if (locationData == null) {
          final int hashCode = serviceId.hashCode;
          final double latOffset = (hashCode % 100) / 10000.0;
          final double lngOffset = (hashCode % 50) / 10000.0;
          
          locationData = {
            'latitude': 36.7538 + latOffset,
            'longitude': 3.0588 + lngOffset,
            'address': 'موقع افتراضي - الجزائر',
          };
          
          print("Transport Location Fix: Using default location for service $serviceId");
          
          // Update the service's location field
          await firestore.collection('services').doc(serviceId).update({
            'location': locationData,
          });
        }
        
        // Now create or update the service_locations entry with correct structure
        await firestore.collection('service_locations').doc(serviceId).set({
          'serviceId': serviceId,
          'providerId': serviceData['providerId'] ?? 'unknown',
          'position': {
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
            'geopoint': GeoPoint(locationData['latitude'], locationData['longitude']),
          },
          'address': locationData['address'],
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        fixed++;
        print("Transport Location Fix: Successfully fixed service $serviceId");
      } catch (e) {
        errors++;
        print("Transport Location Fix: Error fixing service ${serviceDoc.id}: $e");
      }
    }
    
    print("Transport Location Fix: Fix completed. Fixed: $fixed, Errors: $errors");
  } catch (e) {
    print("Transport Location Fix: General error: $e");
  }
}