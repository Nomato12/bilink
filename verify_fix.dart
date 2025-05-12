import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  // Initialize Flutter and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("Transport Location Fix Verification: Starting verification");
  
  // Run verification
  await verifyTransportLocations();
  
  print("Transport Location Fix Verification: Completed");
}

Future<void> verifyTransportLocations() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int correctCount = 0;
  int incorrectCount = 0;
  
  try {
    // Get all transport services
    final servicesSnapshot = await firestore
        .collection('services')
        .where('type', isEqualTo: 'نقل')
        .get();
        
    print("Verification: Found ${servicesSnapshot.docs.length} transport services");
    
    // Examine each service
    for (final serviceDoc in servicesSnapshot.docs) {
      final serviceId = serviceDoc.id;
      final serviceData = serviceDoc.data();
      
      print("\nVerifying service $serviceId:");
      
      // Check if there's a corresponding service_location document
      final locationDoc = await firestore
          .collection('service_locations')
          .doc(serviceId)
          .get();
      
      if (locationDoc.exists) {
        final locationData = locationDoc.data();
        
        if (locationData != null && locationData.containsKey('position')) {
          final position = locationData['position'];
          
          // Check if position has the required structure
          if (position is Map && 
              position.containsKey('latitude') && 
              position.containsKey('longitude') && 
              position.containsKey('geopoint')) {
            
            correctCount++;
            print("  ✅ Service location has correct structure");
            print("  - Position data: ${position['latitude']}, ${position['longitude']}");
            
            // Verify if we can get a LatLng from this data
            LatLng? latLng = safeGetLatLng(locationData);
            if (latLng != null) {
              print("  ✅ Successfully extracted LatLng: ${latLng.latitude}, ${latLng.longitude}");
            } else {
              print("  ❌ Failed to extract LatLng despite correct structure");
              incorrectCount++;
            }
          } else {
            incorrectCount++;
            print("  ❌ Position object missing required fields");
            print("  - Position data: $position");
          }
        } else {
          incorrectCount++;
          print("  ❌ Missing 'position' field in location data");
          print("  - Location data: $locationData");
        }
      } else {
        incorrectCount++;
        print("  ❌ No service_locations entry found");
      }
    }
    
    print("\nVerification summary:");
    print("✅ Correct structure: $correctCount");
    print("❌ Incorrect structure: $incorrectCount");
    
  } catch (e) {
    print("Error during verification: $e");
  }
}

// Implement the same safeGetLatLng function to test extraction
LatLng? safeGetLatLng(Map<String, dynamic>? location) {
  if (location == null) {
    print('DEBUG: safeGetLatLng called with null location');
    return null;
  }

  // Try getting location from 'position' map
  if (location.containsKey('position')) {
    final positionData = location['position'];
    if (positionData is Map<String, dynamic>) {
      // Check for GeoPoint within position
      if (positionData.containsKey('geopoint')) {
        final geopointData = positionData['geopoint'];
        if (geopointData is GeoPoint) {
          return LatLng(geopointData.latitude, geopointData.longitude);
        }
      }

      // Check for latitude/longitude within position
      if (positionData.containsKey('latitude') && positionData.containsKey('longitude')) {
        final lat = positionData['latitude'];
        final lng = positionData['longitude'];
        
        if (lat is num && lng is num) {
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    }
  }

  // Try root level fields
  if (location.containsKey('latitude') && location.containsKey('longitude')) {
    final lat = location['latitude'];
    final lng = location['longitude'];
    
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
  }
  
  return null;
}
