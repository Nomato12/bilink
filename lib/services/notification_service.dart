import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    String? additionalMessage, // رسالة إضافية من مزود الخدمة
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
      final serviceId = requestData['serviceId'];
      final providerId = requestData['providerId'];
      final providerData = await _firestore.collection('users').doc(providerId).get();
      final providerName = providerData.exists 
          ? (providerData.data() as Map<String, dynamic>)['displayName'] ?? 'مزود الخدمة'
          : 'مزود الخدمة';

      // Update request status with response date
      Map<String, dynamic> updateData = {
        'status': status,
        'responseDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // إضافة الرسالة الإضافية إذا كانت موجودة
      if (additionalMessage != null && additionalMessage.isNotEmpty) {
        updateData['providerMessage'] = additionalMessage;
      }
      
      await _requestsCollection.doc(requestId).update(updateData);

      // تخصيص عنوان ومحتوى الإشعار بناءً على الحالة
      String notificationTitle;
      String notificationBody;
      
      if (status == 'accepted') {
        notificationTitle = '🎉 تمت الموافقة على طلبك';
        notificationBody = additionalMessage != null && additionalMessage.isNotEmpty
            ? 'تم قبول طلبك للخدمة: $serviceName\nرسالة من مزود الخدمة: $additionalMessage'
            : 'تم قبول طلبك للخدمة: $serviceName\nيمكنك التواصل مع مزود الخدمة الآن';
      } else {
        notificationTitle = 'تم رفض طلبك';
        notificationBody = additionalMessage != null && additionalMessage.isNotEmpty
            ? 'تم رفض طلبك للخدمة: $serviceName\nسبب الرفض: $additionalMessage'
            : 'تم رفض طلبك للخدمة: $serviceName';
      }

      // Create a notification for the client
      await _notificationsCollection.add({
        'userId': clientId,
        'title': notificationTitle,
        'body': notificationBody,
        'type': 'request_update',
        'data': {
          'requestId': requestId,
          'serviceId': serviceId,
          'providerId': providerId,
          'providerName': providerName,
          'status': status,
          'message': additionalMessage,
          'importance': status == 'accepted' ? 'high' : 'normal',
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
  
  // Get accepted requests for a provider
  Stream<List<DocumentSnapshot>> getProviderAcceptedRequests(String providerId) {
    return _requestsCollection
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
  
  // Get client details for an accepted request
  Future<Map<String, dynamic>> getClientDetails(String clientId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(clientId).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      return {
        'id': userDoc.id,
        'name': userData['displayName'] ?? 'عميل',
        'email': userData['email'] ?? '',
        'phone': userData['phoneNumber'] ?? '',
        'profilePicture': userData['profilePicture'] ?? '',
        'address': userData['address'] ?? '',
      };
    } catch (e) {
      print('Error getting client details: $e');
      throw Exception('Failed to get client details');
    }
  }
}
