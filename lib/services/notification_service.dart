import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  final CollectionReference _requestsCollection = 
      FirebaseFirestore.instance.collection('service_requests');
  
  final CollectionReference _notificationsCollection = 
      FirebaseFirestore.instance.collection('notifications');

  // Send a service request from client to provider
  Future<String> sendServiceRequest({
    required String serviceId,
    required String providerId,
    required String serviceName,
    required String details,
    required DateTime requestDate,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create the request document
      final requestDoc = await _requestsCollection.add({
        'serviceId': serviceId,
        'serviceName': serviceName,
        'providerId': providerId,
        'clientId': currentUser.uid,
        'clientName': currentUser.displayName ?? 'عميل',
        'details': details,
        'requestDate': requestDate,
        'status': 'pending', // pending, accepted, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a notification for the provider
      await _notificationsCollection.add({
        'userId': providerId,
        'title': 'طلب خدمة جديد',
        'body': 'لديك طلب جديد للخدمة: $serviceName',
        'type': 'service_request',
        'data': {
          'requestId': requestDoc.id,
          'serviceId': serviceId,
          'clientId': currentUser.uid,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return requestDoc.id;
    } catch (e) {
      print('Error sending service request: $e');
      throw Exception('Failed to send service request');
    }
  }

  // Update the status of a service request (accept or reject)
  Future<void> updateRequestStatus({
    required String requestId,
    required String status, // 'accepted' or 'rejected'
  }) async {
    try {
      // Get the request document
      final requestDoc = await _requestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final clientId = requestData['clientId'];
      final serviceName = requestData['serviceName'];

      // Update request status
      await _requestsCollection.doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create a notification for the client
      await _notificationsCollection.add({
        'userId': clientId,
        'title': status == 'accepted' ? 'تم قبول طلبك' : 'تم رفض طلبك',
        'body': status == 'accepted' 
          ? 'تم قبول طلبك للخدمة: $serviceName' 
          : 'تم رفض طلبك للخدمة: $serviceName',
        'type': 'request_update',
        'data': {
          'requestId': requestId,
          'status': status,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating request status: $e');
      throw Exception('Failed to update request status');
    }
  }

  // Get unread notifications count for a user
  Stream<int> getUnreadNotificationsCount(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get all notifications for a user
  Stream<List<DocumentSnapshot>> getUserNotifications(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'read': true,
    });
  }

  // Get pending service requests for a provider
  Stream<List<DocumentSnapshot>> getProviderPendingRequests(String providerId) {
    return _requestsCollection
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
}
