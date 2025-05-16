// Verify service type fix
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  print('Starting service type fix verification...');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Verify the fix
  await verifyServiceTypeFix();
  
  print('Service type fix verification completed.');
}

Future<void> verifyServiceTypeFix() async {
  final firestore = FirebaseFirestore.instance;
  
  print('Checking service_request_card.dart modifications...');
  
  final codeFile = File('lib/widgets/service_request_card.dart');
  if (await codeFile.exists()) {
    final codeContent = await codeFile.readAsString();
    
    // Check if our fix is in place
    if (codeContent.contains("requestData['serviceType'] ?? (requestData['type'] ?? 'تخزين')")) {
      print('✓ Service type extraction correctly implemented');
    } else {
      print('✗ Service type extraction not properly implemented');
    }
    
    if (codeContent.contains("'serviceType': requestData['serviceType'] ?? (requestData['type'] ?? 'تخزين'),")) {
      print('✓ Notification data correctly uses serviceType fallback');
    } else {
      print('✗ Notification data not using serviceType fallback');
    }
  } else {
    print('Error: Cannot find service_request_card.dart file');
  }
  
  // Check service requests in Firestore
  print('\nChecking service requests in Firestore...');
  
  try {
    final querySnapshot = await firestore.collection('service_requests').where('status', isEqualTo: 'accepted').limit(5).get();
    
    if (querySnapshot.docs.isEmpty) {
      print('No accepted service requests found for testing');
    } else {
      print('Found ${querySnapshot.docs.length} accepted requests to check');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final serviceType = data['serviceType'] ?? data['type'] ?? 'تخزين';
        final serviceName = data['serviceName'] ?? 'خدمة';
        
        print('Service request $id:');
        print('  - Service Name: $serviceName');
        print('  - Service Type: $serviceType');
        
        // Check if there are notifications for this request
        final notifications = await firestore
            .collection('notifications')
            .where('data.requestId', isEqualTo: id)
            .limit(1)
            .get();
            
        if (notifications.docs.isNotEmpty) {
          final notificationData = notifications.docs.first.data();
          final notifServiceType = notificationData['data']?['serviceType'] ?? 'بدون نوع';
          
          print('  - Notification Service Type: $notifServiceType');
          
          if (serviceType == notifServiceType) {
            print('  - ✓ Service types match!');
          } else {
            print('  - ✗ Service types do not match!');
          }
        } else {
          print('  - No notifications found for this request');
        }
        
        print('');
      }
    }
  } catch (e) {
    print('Error checking Firestore data: $e');
  }
}
