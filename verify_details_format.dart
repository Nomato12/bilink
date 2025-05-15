// A simple script to verify that transport request details no longer include coordinates
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
  print("VERIFYING TRANSPORT REQUEST DETAILS FORMAT");
  print("====================================================");
  
  await verifyDetailsFormat();
  
  print("Verification complete!");
}

Future<void> verifyDetailsFormat() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int total = 0;
  int withCoordinates = 0;
  int withoutCoordinates = 0;
  
  try {
    // Get all transport service requests
    final requestsSnapshot = await firestore
        .collection('service_requests')
        .where('serviceType', isEqualTo: 'نقل')
        .get();
        
    print("Found ${requestsSnapshot.docs.length} transport requests to check");
    
    for (final requestDoc in requestsSnapshot.docs) {
      final requestData = requestDoc.data();
      total++;
      
      // Check the format of the details text
      final String details = requestData['details'] ?? '';
      
      // Check if details contains coordinates (numbers in parentheses)
      if (details.contains(RegExp(r'\(\d+\.\d+,\d+\.\d+\)'))) {
        print("✗ Request ${requestDoc.id} has coordinates in details text: $details");
        withCoordinates++;
      } else {
        print("✓ Request ${requestDoc.id} has clean details without coordinates: $details");
        withoutCoordinates++;
      }
    }
    
    // Print summary
    print("\n===== VERIFICATION SUMMARY =====");
    print("Total transport requests: $total");
    print("Requests with coordinates in details: $withCoordinates");
    print("Requests without coordinates in details: $withoutCoordinates");
    print("Percentage clean: ${(withoutCoordinates/total*100).toStringAsFixed(1)}%");
    
    if (withCoordinates > 0) {
      print("\n⚠️ Some transport requests still have coordinates in the details text.");
      print("You may need to run a script to update all existing records.");
    } else {
      print("\n✅ All transport requests have been properly formatted without coordinates!");
    }
    
  } catch (e) {
    print("Error during verification: $e");
  }
}
