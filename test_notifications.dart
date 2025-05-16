import 'package:flutter/material.dart';
import 'package:bilink/services/service_request_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// This script tests the functionality of the service requests notification system
/// Run this in a test environment to validate that notifications display correctly
void main() async {
  // Initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get the current user ID
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    print('Error: No user is logged in. Please log in first.');
    return;
  }
  
  // Create a test service request
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ServiceRequestNotificationService notificationService = ServiceRequestNotificationService();
  
  try {
    // Find a sample service to associate with the request
    final serviceSnapshot = await firestore.collection('services').limit(1).get();
    if (serviceSnapshot.docs.isEmpty) {
      print('Error: No services found in the database.');
      return;
    }
    
    final serviceData = serviceSnapshot.docs.first.data();
    final serviceId = serviceSnapshot.docs.first.id;
    final providerId = serviceData['userId'] ?? '';
    
    if (providerId.isEmpty) {
      print('Error: Service does not have a valid provider ID.');
      return;
    }
    
    // Create a test request
    final requestRef = firestore.collection('service_requests').doc();
    await requestRef.set({
      'clientId': userId,
      'providerId': providerId,
      'serviceId': serviceId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'details': 'This is a test request for testing notifications',
      'clientName': 'Test Client',
      'serviceName': serviceData['title'] ?? 'Test Service',
      'serviceType': serviceData['type'] ?? 'تخزين',
      'isClientNotified': false
    });
    
    print('Created test service request with ID: ${requestRef.id}');
    
    // Simulate accepting the request by the provider
    await Future.delayed(Duration(seconds: 2));
    await requestRef.update({
      'status': 'accepted',
      'responseDate': FieldValue.serverTimestamp(),
    });
    
    print('Test request accepted. Notification should appear in the client interface.');
    print('Current notification count: ${await notificationService.getAcceptedRequestsCount().first}');
    
    // Clean up after 30 seconds
    await Future.delayed(Duration(seconds: 30));
    await requestRef.delete();
    print('Test request deleted. Test complete.');
    
  } catch (e) {
    print('Error testing notifications: $e');
  }
}
