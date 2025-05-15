// Verification script for client location fix in transport requests
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilink/utils/location_helper.dart';

void main() async {
  // Initialize Flutter and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("Client Location Fix: Starting verification process");
  
  // Run the verification
  await verifyClientLocationFix();
  
  // Exit the application
  print("Client Location Fix: Verification process completed");
}

Future<void> verifyClientLocationFix() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int hasClientLocation = 0;
  int missingClientLocation = 0;
  int total = 0;
  
  try {
    // Get all active transport service requests
    final requestsSnapshot = await firestore
        .collection('service_requests')
        .where('serviceType', isEqualTo: 'نقل')
        .limit(20) // Limit to 20 most recent requests
        .get();
        
    print("Client Location Fix: Found ${requestsSnapshot.docs.length} transport requests to verify");
    
    // Process each request
    for (final requestDoc in requestsSnapshot.docs) {
      try {
        final requestId = requestDoc.id;
        final requestData = requestDoc.data();
        total++;
        
        print("\nClient Location Fix: Verifying request $requestId");
        
        // Check if the request has client location information
        bool hasLocation = false;
        
        // Try using the location helper to extract location
        GeoPoint? extractedLocation = LocationHelper.getLocationFromData(requestData);
        
        if (extractedLocation != null) {
          print("✓ Request $requestId has extractable client location: ${extractedLocation.latitude}, ${extractedLocation.longitude}");
          hasClientLocation++;
          hasLocation = true;
        } else if (requestData.containsKey('clientLocation') && requestData['clientLocation'] != null) {
          print("✓ Request $requestId has direct client location field");
          hasClientLocation++;
          hasLocation = true;
        } else {
          print("✗ Request $requestId MISSING client location");
          missingClientLocation++;
        }
          // Check if details contains coordinates
        final details = requestData['details'] as String? ?? '';
        if (details.contains('(') && details.contains(')')) {
          print("✓ Details field contains coordinates: $details");
        } else {
          print("✗ Details field does not contain coordinates");
        }
        
        // Check if locationData exists
        if (requestData.containsKey('locationData') && requestData['locationData'] is Map) {
          final locationData = requestData['locationData'] as Map<String, dynamic>;
          print("✓ locationData field exists containing: ${locationData.keys.join(', ')}");
        } else {
          print("✗ locationData field missing");
        }
        
        // Check if client ID is available
        if (requestData.containsKey('clientId') && requestData['clientId'] != null) {
          final clientId = requestData['clientId'];
          
          // Try to get client location from separate collections
          final clientLocationData = await LocationHelper.getClientLocationData(clientId);
          if (clientLocationData != null) {
            print("✓ Found location for client $clientId in client_locations collection");
            
            // If the request doesn't have location info but client_locations does, update the request
            if (!hasLocation) {
              print("! Will update request $requestId with client location data");
              
              // Here we would update the request - in verification mode we just print
              if (clientLocationData.containsKey('originLocation')) {
                print("✓ Origin location available for update");
              }
            }
          }
        }
        
      } catch (e) {
        print("Client Location Fix: Error verifying request ${requestDoc.id}: $e");
      }
    }
      // Print summary
    print("\n===== CLIENT LOCATION DATA SUMMARY =====");
    print("Total requests: $total");
    print("Requests with client location: $hasClientLocation (${(hasClientLocation/total*100).toStringAsFixed(1)}%)");
    print("Requests missing client location: $missingClientLocation (${(missingClientLocation/total*100).toStringAsFixed(1)}%)");
    
    // Count requests with enhanced data
    int hasEnhancedDetails = 0;
    int hasLocationData = 0;
    
    for (final doc in requestsSnapshot.docs) {
      final data = doc.data();
      final details = data['details'] as String? ?? '';
      
      if (details.contains('(') && details.contains(')')) {
        hasEnhancedDetails++;
      }
      
      if (data.containsKey('locationData') && data['locationData'] is Map) {
        hasLocationData++;
      }
    }
    
    print("Requests with enhanced details: $hasEnhancedDetails (${(hasEnhancedDetails/total*100).toStringAsFixed(1)}%)");
    print("Requests with locationData field: $hasLocationData (${(hasLocationData/total*100).toStringAsFixed(1)}%)");
  } catch (e) {
    print("Client Location Fix: General error during verification: $e");
  }
}
