// This script updates existing transport requests to remove coordinates from details text
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
  
  print("====================================================");
  print("UPDATING TRANSPORT REQUEST DETAILS FORMAT");
  print("====================================================");
  
  await updateDetailsFormat();
  
  print("Update complete!");
}

Future<void> updateDetailsFormat() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int total = 0;
  int updated = 0;
  int alreadyClean = 0;
  int errors = 0;
  
  try {
    // Get all transport service requests
    final requestsSnapshot = await firestore
        .collection('service_requests')
        .where('serviceType', isEqualTo: 'نقل')
        .get();
        
    print("Found ${requestsSnapshot.docs.length} transport requests to process");
    
    for (final requestDoc in requestsSnapshot.docs) {
      try {
        final requestId = requestDoc.id;
        final requestData = requestDoc.data();
        total++;
        
        // Check the format of the details text
        final String details = requestData['details'] ?? '';
        final String originName = requestData['originName'] ?? '';
        final String destinationName = requestData['destinationName'] ?? '';
        final String vehicleType = requestData['vehicleType'] ?? '';
        
        // Check if details contains coordinates (numbers in parentheses)
        if (details.contains(RegExp(r'\(\d+\.\d+,\d+\.\d+\)'))) {
          // Create clean details text without coordinates
          String cleanDetails = 'طلب خدمة نقل من $originName إلى $destinationName باستخدام $vehicleType';
          
          // Update the record
          await firestore.collection('service_requests').doc(requestId).update({
            'details': cleanDetails,
          });
          
          print("✓ Updated request $requestId: $details -> $cleanDetails");
          updated++;
        } else {
          print("✓ Request $requestId already has clean details: $details");
          alreadyClean++;
        }
      } catch (e) {
        print("✗ Error processing request ${requestDoc.id}: $e");
        errors++;
      }
    }
    
    // Print summary
    print("\n===== UPDATE SUMMARY =====");
    print("Total transport requests: $total");
    print("Requests updated: $updated");
    print("Requests already clean: $alreadyClean");
    print("Errors: $errors");
    
  } catch (e) {
    print("Error during update process: $e");
  }
}
