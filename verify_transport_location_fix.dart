// This file is used to verify if the transport location fix has been implemented correctly
// Run it in the BiLink project to test that transport locations now display correctly

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
  
  print("Transport Location Fix Verification: Starting verification process");
  
  // Run the verification
  await verifyTransportLocations();
  
  // Exit the application
  print("Transport Location Fix Verification: Verification completed");
}

Future<void> verifyTransportLocations() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int correctlyFormatted = 0;
  int incorrectlyFormatted = 0;
  
  try {
    // Step 1: Check service_locations collection for proper structure
    print("\n===== CHECKING SERVICE_LOCATIONS COLLECTION =====");
    final locationSnapshot = await firestore
        .collection('service_locations')
        .get();
        
    print("Found ${locationSnapshot.docs.length} service location documents");
    
    // Process each location document
    for (final locationDoc in locationSnapshot.docs) {
      final locationId = locationDoc.id;
      final locationData = locationDoc.data();
      
      bool hasCorrectStructure = locationData.containsKey('position') && 
          locationData['position'] is Map &&
          (locationData['position'] as Map).containsKey('latitude') &&
          (locationData['position'] as Map).containsKey('longitude') &&
          (locationData['position'] as Map).containsKey('geopoint');
      
      if (hasCorrectStructure) {
        correctlyFormatted++;
        print("Location $locationId: Correctly formatted with nested position structure");
      } else {
        incorrectlyFormatted++;
        print("Location $locationId: INCORRECT format: ${locationData.keys.toList()}");
      }
    }
    
    // Summary
    print("\n===== SERVICE_LOCATIONS STRUCTURE SUMMARY =====");
    print("Correctly formatted: $correctlyFormatted");
    print("Incorrectly formatted: $incorrectlyFormatted");
    print("Percentage correct: ${(correctlyFormatted / (correctlyFormatted + incorrectlyFormatted) * 100).toStringAsFixed(2)}%");
    
    // Step 2: Verify sample transport service display
    print("\n===== CHECKING TRANSPORT SERVICES FOR DISPLAY =====");
    
    final transportServices = await firestore
        .collection('services')
        .where('type', isEqualTo: 'نقل')
        .limit(5)
        .get();
    
    if (transportServices.docs.isEmpty) {
      print("No transport services found to verify display");
    } else {
      print("Analyzing ${transportServices.docs.length} transport services for display compatibility");
      
      for (final serviceDoc in transportServices.docs) {
        final serviceId = serviceDoc.id;
        final serviceLocationDoc = await firestore
            .collection('service_locations')
            .doc(serviceId)
            .get();
        
        if (serviceLocationDoc.exists) {
          final locationData = serviceLocationDoc.data();
          if (locationData != null && 
              locationData.containsKey('position') && 
              locationData['position'] is Map) {
            
            print("Service $serviceId: Will display correctly on client page");
            print("  - Position data: ${locationData['position']}");
          } else {
            print("Service $serviceId: Will NOT display correctly on client page");
            print("  - Location data structure: ${locationData?.keys.toList()}");
          }
        } else {
          print("Service $serviceId: No location document found in service_locations");
        }
      }
    }
    
  } catch (e) {
    print("Transport Location Fix Verification: Error during verification: $e");
  }
}
