import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ServiceRequestNotificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get count of newly accepted service requests for the current user
  Stream<int> getAcceptedRequestsCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }
    
    // Check for service requests that have been accepted in the last 24 hours
    final DateTime oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    
    return _firestore
        .collection('service_requests')
        .where('clientId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('responseDate', isGreaterThan: Timestamp.fromDate(oneDayAgo))
        .where('isClientNotified', isEqualTo: false) // New field to track notification status
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
    // Get list of newly accepted service requests
  Stream<List<DocumentSnapshot>> getAcceptedRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }
    
    final DateTime oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    
    return _firestore
        .collection('service_requests')
        .where('clientId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('responseDate', isGreaterThan: Timestamp.fromDate(oneDayAgo))
        .where('isClientNotified', isEqualTo: false) // Only show unnotified requests
        .orderBy('responseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
    // Mark service request as notified to the client
  Future<void> markRequestAsNotified(String requestId) async {
    await _firestore
        .collection('service_requests')
        .doc(requestId)
        .update({
          'isClientNotified': true,
          'notifiedAt': FieldValue.serverTimestamp()
        });
  }
    // Mark all unread service requests as notified
  Future<void> markAllRequestsAsNotified() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    final snapshot = await _firestore
        .collection('service_requests')
        .where('clientId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('isClientNotified', isEqualTo: false)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isClientNotified': true,
        'notifiedAt': FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
  }
}
