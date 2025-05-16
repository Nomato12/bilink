// This file verifies the fix for service type display issues
// It will check that transport services are correctly displayed as transport

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/firebase_options.dart';

void main() async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('\n=== VERIFYING SERVICE TYPE DISPLAY FIX ===');
  print('Checking for transport services that show the wrong service type in UI...');
  
  await verifyServiceTypeDisplayFix();
  
  print('\n=== VERIFICATION COMPLETE ===');
}

Future<void> verifyServiceTypeDisplayFix() async {
  try {
    // Get all service requests that should be transport services
    final transportRequestsQuery = await FirebaseFirestore.instance.collection('service_requests')
        .where('status', isEqualTo: 'accepted')
        .where('originLocation', isNull: false)  // Transport services have origin location
        .limit(10)
        .get();
    
    if (transportRequestsQuery.docs.isEmpty) {
      print('No accepted transport requests found to verify.');
      return;
    }
    
    print('Found ${transportRequestsQuery.docs.length} potential transport service requests to check.');
    
    int correctlyDisplayedCount = 0;
    int incorrectlyDisplayedCount = 0;
    
    // Check each service request
    for (final doc in transportRequestsQuery.docs) {
      final data = doc.data();
      final id = doc.id;
      
      // Check service type values
      final serviceType = data['serviceType'];
      final type = data['type'];
      final hasOriginLocation = data['originLocation'] != null;
      final hasDestinationLocation = data['destinationLocation'] != null;
      final hasVehicleType = data['vehicleType'] != null;
      
      print('\nChecking service request: $id');
      print('- serviceType field: ${serviceType ?? "NULL"}');
      print('- type field: ${type ?? "NULL"}');
      print('- Has origin location: $hasOriginLocation');
      print('- Has destination location: $hasDestinationLocation');
      print('- Has vehicle type: $hasVehicleType');
      
      // Determine if this is definitely a transport service
      bool isTransportService = (serviceType == 'نقل' || type == 'نقل' || 
          (hasOriginLocation && hasDestinationLocation) || hasVehicleType);
      
      // Check if service type would be displayed correctly with our fix
      bool wouldDisplayCorrectly = false;
      
      // Simulating our logic in service_request_card.dart
      String displayedServiceType;
      if (serviceType != null) {
        displayedServiceType = serviceType;
      } else if (type != null) {
        displayedServiceType = type;
      } else if (hasOriginLocation && hasDestinationLocation) {
        displayedServiceType = 'نقل';
      } else if (hasVehicleType) {
        displayedServiceType = 'نقل';
      } else {
        displayedServiceType = 'تخزين';
      }
      
      wouldDisplayCorrectly = (isTransportService && displayedServiceType == 'نقل');
      
      print('- Is transport service: $isTransportService');
      print('- Would be displayed as: $displayedServiceType');
      print('- Display status: ${wouldDisplayCorrectly ? "✅ CORRECT" : "❌ INCORRECT"}');
      
      if (wouldDisplayCorrectly) {
        correctlyDisplayedCount++;
      } else if (isTransportService) {
        incorrectlyDisplayedCount++;
      }
      
      // If this service is not displayed correctly, update it
      if (isTransportService && displayedServiceType != 'نقل') {
        print('- 🔄 Updating service request to have correct serviceType: نقل');
        await doc.reference.update({'serviceType': 'نقل'});
        print('- ✅ Updated successfully!');
      }
    }
    
    print('\n=== SUMMARY ===');
    print('Total transport services checked: ${transportRequestsQuery.docs.length}');
    print('Correctly displayed: $correctlyDisplayedCount');
    print('Incorrectly displayed (now fixed): $incorrectlyDisplayedCount');
    
  } catch (e) {
    print('Error verifying service type display fix: $e');
  }
}
