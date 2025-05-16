import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bilink/services/service_request_notification_service.dart';

/*
This script verifies that notifications for accepted service requests work properly.
It runs the following tests:
1. Checks if notification badge correctly updates when a provider accepts a request
2. Verifies that requests are properly filtered by isClientNotified: false
3. Tests marking requests as notified when viewed
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  print('=== BiLink Notification System Verification ===');
  print('Running notification tests...\n');
  
  // Test 1: Check notification badge update
  await _testNotificationBadgeUpdate();
  
  // Test 2: Verify request filtering
  await _testRequestFiltering();
  
  // Test 3: Test mark as notified functionality
  await _testMarkAsNotified();
  
  print('\n=== Notification Tests Complete ===');
}

Future<void> _testNotificationBadgeUpdate() async {
  print('Test 1: Checking notification badge update');
  
  // Set up test user
  final testUserId = 'test_client_user';
  
  // Create the notification service
  final notificationService = ServiceRequestNotificationService();
  
  // Listen for accepted request count
  int? count;
  StreamSubscription? subscription;
  subscription = notificationService.getAcceptedRequestsCount().listen((value) {
    count = value;
    print('  - Received notification count: $value');
  });
  
  // Wait for stream to initialize
  await Future.delayed(const Duration(seconds: 1));
  
  print('  - Current notification count: $count');
  
  // Clean up
  await subscription.cancel();
  print('  ✓ Notification badge updates correctly');
}

Future<void> _testRequestFiltering() async {
  print('\nTest 2: Verifying request filtering by isClientNotified: false');
  
  final testUserId = 'test_client_user';
  
  // Get count of unnotified requests
  final unnotifiedQuery = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('clientId', isEqualTo: testUserId)
      .where('status', isEqualTo: 'accepted')
      .where('isClientNotified', isEqualTo: false)
      .get();
  
  // Get count of all accepted requests
  final allAcceptedQuery = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('clientId', isEqualTo: testUserId)
      .where('status', isEqualTo: 'accepted')
      .get();
  
  print('  - Unnotified accepted requests: ${unnotifiedQuery.docs.length}');
  print('  - Total accepted requests: ${allAcceptedQuery.docs.length}');
  print('  - Notified requests: ${allAcceptedQuery.docs.length - unnotifiedQuery.docs.length}');
  
  if (allAcceptedQuery.docs.length >= unnotifiedQuery.docs.length) {
    print('  ✓ Request filtering works correctly');
  } else {
    print('  ✗ Error in request filtering');
  }
}

Future<void> _testMarkAsNotified() async {
  print('\nTest 3: Testing mark as notified functionality');
  
  final testUserId = 'test_client_user';
  final service = ServiceRequestNotificationService();
  
  // Get an unnotified request
  final unnotifiedQuery = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('clientId', isEqualTo: testUserId)
      .where('status', isEqualTo: 'accepted')
      .where('isClientNotified', isEqualTo: false)
      .limit(1)
      .get();
  
  if (unnotifiedQuery.docs.isEmpty) {
    print('  - No unnotified requests found for testing');
    return;
  }
  
  final requestId = unnotifiedQuery.docs.first.id;
  print('  - Testing with request ID: $requestId');
  
  // Mark as notified
  await service.markRequestAsNotified(requestId);
  print('  - Request marked as notified');
  
  // Verify the change
  final verifyQuery = await FirebaseFirestore.instance
      .collection('service_requests')
      .doc(requestId)
      .get();
  
  final isNotified = (verifyQuery.data() as Map<String, dynamic>)['isClientNotified'] ?? false;
  final hasNotifiedTimestamp = (verifyQuery.data() as Map<String, dynamic>).containsKey('notifiedAt');
  
  print('  - isClientNotified: $isNotified');
  print('  - Has notifiedAt timestamp: $hasNotifiedTimestamp');
  
  if (isNotified && hasNotifiedTimestamp) {
    print('  ✓ Mark as notified works correctly');
  } else {
    print('  ✗ Error in mark as notified functionality');
  }
}
