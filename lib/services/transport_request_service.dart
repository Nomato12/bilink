// Transport request service to handle the transport requests
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/models/transport_request.dart';
import 'package:bilink/services/notification_service.dart';

class TransportRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new transport request
  Future<String> createTransportRequest({
    required String providerId,
    required String providerName,
    required String vehicleType,
    required LatLng originLocation,
    required String originName,
    required LatLng destinationLocation,
    required String destinationName,
    required double distance,
    required double duration,
    required String distanceText,
    required String durationText,
    required double price,
  }) async {
    try {
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }      // Get client name from Firestore
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final clientName = userDoc.exists ? (userDoc.data()?['name'] ?? userDoc.data()?['displayName'] ?? 'Client') : 'Client';      // Create transport request document
      final Map<String, dynamic> requestData = {
        'clientId': currentUser.uid,
        'clientName': clientName,
        'providerId': providerId,
        'providerName': providerName,
        'vehicleType': vehicleType,
        'originLocation': GeoPoint(originLocation.latitude, originLocation.longitude),
        'originName': originName,
        'destinationLocation': GeoPoint(destinationLocation.latitude, destinationLocation.longitude),
        'destinationName': destinationName,
        'distance': distance,
        'duration': duration,
        'distanceText': distanceText,
        'durationText': durationText,
        'price': price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'serviceType': 'نقل',
        'details': 'طلب خدمة نقل من $originName إلى $destinationName باستخدام $vehicleType'
      };

      // Use NotificationService to send the service request
      final String requestId = await _notificationService.sendServiceRequest(
        serviceId: providerId, // Using providerId as serviceId
        providerId: providerId,
        serviceName: 'خدمة نقل',
        details: 'طلب خدمة نقل من $originName إلى $destinationName باستخدام $vehicleType',
        requestDate: DateTime.now(),
        // Pass transport-specific data
        originLocation: GeoPoint(originLocation.latitude, originLocation.longitude),
        originName: originName,
        destinationLocation: GeoPoint(destinationLocation.latitude, destinationLocation.longitude),
        destinationName: destinationName,
        distanceText: distanceText,
        durationText: durationText,
        vehicleType: vehicleType,
        price: price,
      );

      // Send notification to provider
      await _notificationService.sendNotification(
        recipientId: providerId,
        title: 'طلب خدمة نقل جديد',
        body: 'لديك طلب نقل جديد من $clientName',
        data: {
          'requestId': requestId,
          'type': 'transport_request',
        },
      );

      return requestId;
    } catch (e) {
      print('Error creating transport request: $e');
      rethrow;
    }
  }
  // Get all transport requests for a provider
  Stream<List<TransportRequest>> getProviderTransportRequests(String providerId) {
    return _firestore
        .collection('service_requests')
        .where('providerId', isEqualTo: providerId)
        .where('serviceType', isEqualTo: 'نقل')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransportRequest.fromDocument(doc))
            .toList());
  }
  // Get all transport requests for a client
  Stream<List<TransportRequest>> getClientTransportRequests(String clientId) {
    return _firestore
        .collection('service_requests')
        .where('clientId', isEqualTo: clientId)
        .where('serviceType', isEqualTo: 'نقل')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransportRequest.fromDocument(doc))
            .toList());
  }  // Update request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      final Map<String, dynamic> updateData = {'status': status};
      
      if (status == 'accepted') {
        updateData['acceptedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore.collection('service_requests').doc(requestId).update(updateData);
      
      // Fetch request to get details for notification
      final requestDoc = await _firestore.collection('service_requests').doc(requestId).get();
      final requestData = requestDoc.data();
      
      if (requestData != null) {
        final recipientId = status == 'accepted' || status == 'rejected' 
            ? requestData['clientId'] 
            : requestData['providerId'];
        
        String title = '';
        String body = '';
        
        if (status == 'accepted') {
          title = 'تم قبول طلب النقل';
          body = 'تم قبول طلب النقل الخاص بك من ${requestData['providerName']}';
        } else if (status == 'rejected') {
          title = 'تم رفض طلب النقل';
          body = 'تم رفض طلب النقل الخاص بك من ${requestData['providerName']}';
        } else if (status == 'completed') {
          title = 'تم إكمال طلب النقل';
          body = 'تم إكمال طلب النقل من ${requestData['clientName']}';
        }
        
        // Send notification
        await _notificationService.sendNotification(
          recipientId: recipientId,
          title: title,
          body: body,
          data: {
            'requestId': requestId,
            'type': 'transport_request_update',
          },
        );
      }
    } catch (e) {
      print('Error updating request status: $e');
      rethrow;
    }
  }
}
