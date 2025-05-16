// Implementation script to update transport requests with enhanced location data
// This script extends our previous work to provide better location details in transport requests

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Flutter and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("Transport Location Enhancement: Starting implementation process");
  
  // Run the implementation
  await enhanceTransportLocationData();
  
  // Exit the application
  print("Transport Location Enhancement: Implementation process completed");
}

Future<void> enhanceTransportLocationData() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int totalProcessed = 0;
  int updated = 0;
  int alreadyUpdated = 0;
  int errors = 0;
  
  try {
    // Get all transport service requests
    final requestsSnapshot = await firestore
        .collection('service_requests')
        .where('serviceType', isEqualTo: 'نقل')
        .get();
        
    print("Transport Location Enhancement: Found ${requestsSnapshot.docs.length} transport requests to process");
    
    // Process each request
    for (final requestDoc in requestsSnapshot.docs) {
      try {
        final requestId = requestDoc.id;
        final requestData = requestDoc.data();
        totalProcessed++;
        
        print("\nProcessing request $requestId ($totalProcessed/${requestsSnapshot.docs.length})");
        
        // Check if already has enhanced location data
        if (requestData.containsKey('locationData') && 
            requestData['locationData'] is Map &&
            (requestData['locationData'] as Map).containsKey('clientCoords')) {
          print("✓ Request already has enhanced location data");
          alreadyUpdated++;
          continue;
        }
        
        // Get location data
        final originLocation = requestData['originLocation'] as GeoPoint?;
        final originName = requestData['originName'] as String? ?? '';
        final destinationLocation = requestData['destinationLocation'] as GeoPoint?;
        final destinationName = requestData['destinationName'] as String? ?? '';
        final clientLocation = requestData['clientLocation'] as GeoPoint?;
        final clientAddress = requestData['clientAddress'] as String? ?? '';
        final vehicleType = requestData['vehicleType'] as String? ?? '';
        
        if (originLocation == null || destinationLocation == null) {
          print("✗ Missing origin or destination location - skipping");
          errors++;
          continue;
        }
        
        // Create enhanced location data
        String originCoords = '${originLocation.latitude.toStringAsFixed(6)},${originLocation.longitude.toStringAsFixed(6)}';
        String destCoords = '${destinationLocation.latitude.toStringAsFixed(6)},${destinationLocation.longitude.toStringAsFixed(6)}';
        String clientCoords = clientLocation != null 
            ? '${clientLocation.latitude.toStringAsFixed(6)},${clientLocation.longitude.toStringAsFixed(6)}' 
            : originCoords;
            
        // Create enhanced details string
        String enhancedDetails = 'طلب خدمة نقل من $originName إلى $destinationName باستخدام $vehicleType';
        
        // Create location data map
        Map<String, dynamic> locationData = {
          'originCoords': originCoords,
          'destinationCoords': destCoords,
          'clientCoords': clientCoords,
        };
        
        // Update the request document
        try {
          await firestore.collection('service_requests').doc(requestId).update({
            'details': enhancedDetails,
            'locationData': locationData,
          });
          
          print("✓ Successfully updated request with enhanced location data");
          updated++;
        } catch (e) {
          print("✗ Error updating request: $e");
          errors++;
        }
        
      } catch (e) {
        print("✗ Error processing request ${requestDoc.id}: $e");
        errors++;
      }
    }
    
    // Print summary
    print("\n===== TRANSPORT LOCATION ENHANCEMENT SUMMARY =====");
    print("Total requests processed: $totalProcessed");
    print("Requests already updated: $alreadyUpdated");
    print("Requests newly updated: $updated");
    print("Errors encountered: $errors");
    
    double successRate = totalProcessed > 0 ? ((updated + alreadyUpdated) / totalProcessed) * 100 : 0;
    print("Success rate: ${successRate.toStringAsFixed(1)}%");
    
  } catch (e) {
    print("Transport Location Enhancement: Error during implementation: $e");
  }
}
