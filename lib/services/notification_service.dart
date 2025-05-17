import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/fcm_service.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FcmService _fcmService = FcmService();

  // Collection references
  final CollectionReference _requestsCollection = 
      FirebaseFirestore.instance.collection('service_requests');
  
  final CollectionReference _notificationsCollection = 
      FirebaseFirestore.instance.collection('notifications');  // Send a service request from client to provider
  Future<String> sendServiceRequest({
    required String serviceId,
    required String providerId,
    required String serviceName,
    required String details,
    required DateTime requestDate,
    // Add transport-specific optional parameters
    GeoPoint? originLocation,
    String? originName,
    GeoPoint? destinationLocation,
    String? destinationName,
    String? distanceText,
    String? durationText,
    String? vehicleType,
    double? price,
    // Client location information
    GeoPoint? clientLocation,
    String? clientAddress,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Retrieve service type from the service document
      String serviceType = 'تخزين'; // Default to storage service
      try {
        final serviceDoc = await _firestore.collection('services').doc(serviceId).get();
        if (serviceDoc.exists) {
          final serviceData = serviceDoc.data() as Map<String, dynamic>;
          serviceType = serviceData['type'] ?? serviceData['serviceType'] ?? 'تخزين';
        }
      } catch (e) {
        print('Error retrieving service type: $e');
        // Continue with default service type
      }

      // Create the request data map
      Map<String, dynamic> requestData = {
        'serviceId': serviceId,
        'serviceName': serviceName,
        'providerId': providerId,
        'clientId': currentUser.uid,
        'clientName': currentUser.displayName ?? 'عميل',
        'details': details,
        'requestDate': requestDate,
        'status': 'pending', // pending, accepted, rejected
        'serviceType': serviceType, // Add service type to the request
        'createdAt': FieldValue.serverTimestamp(),
      };
        // Add transport-specific data if this is a transport service
      if (serviceType == 'نقل') {
        if (originLocation != null) requestData['originLocation'] = originLocation;
        if (originName != null && originName.isNotEmpty) requestData['originName'] = originName;
        if (destinationLocation != null) requestData['destinationLocation'] = destinationLocation;
        if (destinationName != null && destinationName.isNotEmpty) requestData['destinationName'] = destinationName;
        if (distanceText != null && distanceText.isNotEmpty) requestData['distanceText'] = distanceText;
        if (durationText != null && durationText.isNotEmpty) requestData['durationText'] = durationText;
        if (vehicleType != null && vehicleType.isNotEmpty) requestData['vehicleType'] = vehicleType;
        if (price != null) requestData['price'] = price;
        
        // Add client location information
        if (clientLocation != null) requestData['clientLocation'] = clientLocation;
        if (clientAddress != null && clientAddress.isNotEmpty) requestData['clientAddress'] = clientAddress;
      }

      // Create the request document
      final requestDoc = await _requestsCollection.add(requestData);

      // Create a notification for the provider
      await _notificationsCollection.add({
        'userId': providerId,
        'title': 'طلب خدمة جديد',
        'body': 'لديك طلب ${serviceType == 'نقل' ? 'نقل' : 'تخزين'} جديد للخدمة: $serviceName',
        'type': 'service_request',
        'data': {
          'requestId': requestDoc.id,
          'serviceId': serviceId,
          'clientId': currentUser.uid,
          'serviceType': serviceType, // Add service type to notification data
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return requestDoc.id;
    } catch (e) {
      print('Error sending service request: $e');
      throw Exception('Failed to send service request');
    }  }

  // Send a notification to a specific user
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // تم إلغاء إرسال الإشعارات - مع الاحتفاظ بسجل الإشعارات في قاعدة البيانات
    debugPrint('تم إلغاء إرسال الإشعار: $title إلى المستخدم: $recipientId');
    
    try {
      // لا نزال نحتفظ بسجل الإشعارات في قاعدة البيانات ولكن بدون ظهور الإشعارات الفعلية
      await _notificationsCollection.add({
        'userId': recipientId,
        'title': title,
        'body': body,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // تم تعطيل إرسال إشعار FCM
      // await _fcmService.sendNotificationToUser(
      //   userId: recipientId,
      //   title: title,
      //   body: body,
      //   data: data,
      // );
      
      debugPrint('تم حفظ سجل الإشعار دون إظهاره للمستخدم: $recipientId');
    } catch (e) {
      debugPrint('خطأ في حفظ سجل الإشعار: $e');
      // Continue execution even if notification fails
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
      }      final requestData = requestDoc.data() as Map<String, dynamic>;
      final clientId = requestData['clientId'];
      final serviceName = requestData['serviceName'];
      final serviceId = requestData['serviceId'];
      final providerId = requestData['providerId'];
      // Get the service type from the request data
      final serviceType = requestData['serviceType'] ?? 'تخزين'; // Default to storage if not specified
      final providerData = await _firestore.collection('users').doc(providerId).get();
      final providerName = providerData.exists 
          ? (providerData.data() as Map<String, dynamic>)['displayName'] ?? 'مزود الخدمة'
          : 'مزود الخدمة';      // Update request status with response date
      Map<String, dynamic> updateData = {
        'status': status,
        'responseDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isClientNotified': false, // إضافة هذا الحقل للتتبع في واجهة العميل
      };
      
      // إضافة الرسالة الإضافية إذا كانت موجودة
      if (additionalMessage != null && additionalMessage.isNotEmpty) {
        updateData['providerMessage'] = additionalMessage;
      }
      
      await _requestsCollection.doc(requestId).update(updateData);

      // تخصيص عنوان ومحتوى الإشعار بناءً على الحالة
      String notificationTitle;
      String notificationBody;
        // Create a service type text for notifications
      final serviceTypeText = serviceType == 'نقل' ? 'نقل' : 'تخزين';
      
      if (status == 'accepted') {
        notificationTitle = '🎉 تمت الموافقة على طلبك';
        notificationBody = additionalMessage != null && additionalMessage.isNotEmpty
            ? 'تم قبول طلب $serviceTypeText للخدمة: $serviceName\nرسالة من مزود الخدمة: $additionalMessage'
            : 'تم قبول طلب $serviceTypeText للخدمة: $serviceName\nيمكنك التواصل مع مزود الخدمة الآن';
      } else {
        notificationTitle = 'تم رفض طلبك';
        notificationBody = additionalMessage != null && additionalMessage.isNotEmpty
            ? 'تم رفض طلب $serviceTypeText للخدمة: $serviceName\nسبب الرفض: $additionalMessage'
            : 'تم رفض طلب $serviceTypeText للخدمة: $serviceName';
      }      // Create a notification for the client
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
          'serviceType': serviceType,  // Add service type to notification data
          'importance': status == 'accepted' ? 'high' : 'normal',
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // تم تعطيل إرسال إشعار FCM للعميل
      debugPrint('تم إلغاء إرسال إشعار FCM للعميل: $clientId');
      /*
      try {
        await _fcmService.sendNotificationToUser(
          userId: clientId,
          title: notificationTitle,
          body: notificationBody,          
          data: {            
            'type': 'request_update',
            'requestId': requestId,
            'status': status,
            'serviceId': serviceId,
            'providerId': providerId,
            'serviceType': serviceType,  // Add service type to FCM data
            'targetScreen': 'client_interface', // Add target screen for routing
            'isForClient': true, // Explicitly mark notification for client only
            'userId': clientId // Include the target user ID for filtering
          },
        );
        debugPrint('تم إرسال إشعار FCM للعميل: $clientId');
      } catch (fcmError) {
        debugPrint('خطأ في إرسال إشعار FCM: $fcmError');
        // استمرار التنفيذ حتى لو فشل إرسال الإشعار عبر FCM
      }
      */
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
    // Get client details for an accepted request
  Future<Map<String, dynamic>> getClientDetails(String clientId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(clientId).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get additional client data if available      // تحسين استخراج بيانات العميل من مختلف الحقول المحتملة
      String clientName = '';
      String profilePicUrl = '';
      
      // استخراج الاسم من مختلف الحقول المحتملة
      if (userData['displayName'] != null && userData['displayName'].toString().isNotEmpty) {
        clientName = userData['displayName'].toString();
      } else if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
        clientName = userData['name'].toString();
      } else if (userData['fullName'] != null && userData['fullName'].toString().isNotEmpty) {
        clientName = userData['fullName'].toString();
      } else if (userData['firstName'] != null || userData['lastName'] != null) {
        String firstName = userData['firstName']?.toString() ?? '';
        String lastName = userData['lastName']?.toString() ?? '';
        clientName = '$firstName $lastName'.trim();
      } else {
        clientName = 'عميل';
      }
      
      // استخراج رابط الصورة الشخصية من مختلف الحقول المحتملة
      // في BiLink، يتم استخدام profileImageUrl للصورة الشخصية
      if (userData['profileImageUrl'] != null && userData['profileImageUrl'].toString().isNotEmpty) {
        profilePicUrl = userData['profileImageUrl'].toString();
      } else if (userData['profilePicture'] != null && userData['profilePicture'].toString().isNotEmpty) {
        profilePicUrl = userData['profilePicture'].toString();
      } else if (userData['photoURL'] != null && userData['photoURL'].toString().isNotEmpty) {
        profilePicUrl = userData['photoURL'].toString();
      } else if (userData['photo'] != null && userData['photo'].toString().isNotEmpty) {
        profilePicUrl = userData['photo'].toString();
      } else if (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty) {
        profilePicUrl = userData['profileImage'].toString();
      }
      
      print('استخراج بيانات العميل: الاسم = $clientName، الصورة = ${profilePicUrl.isNotEmpty}، رابط الصورة = $profilePicUrl');
      
      Map<String, dynamic> clientInfo = {
        'id': userDoc.id,
        'name': clientName,
        'email': userData['email'] ?? '',
        'phone': userData['phoneNumber'] ?? userData['phone'] ?? '',
        'profilePicture': profilePicUrl,
        'address': userData['address'] ?? '',
        'fcmToken': userData['fcmToken'] ?? '',
        'userRole': userData['role'] ?? 'client',
      };
      
      // Add location data if available - handle all possible location formats
      // Case 1: Direct GeoPoint field
      if (userData['location'] is GeoPoint) {
        final location = userData['location'] as GeoPoint;
        clientInfo['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude
        };
        print('Found client location (direct GeoPoint): ${location.latitude}, ${location.longitude}');
      }
      // Case 2: Nested location map with latitude/longitude
      else if (userData['location'] is Map) {
        final locationMap = userData['location'] as Map<String, dynamic>;
        
        // Check for GeoPoint in location map
        if (locationMap['geopoint'] is GeoPoint) {
          final geoPoint = locationMap['geopoint'] as GeoPoint;
          clientInfo['location'] = {
            'latitude': geoPoint.latitude,
            'longitude': geoPoint.longitude,
            'address': locationMap['address'] ?? ''
          };
          print('Found client location (nested GeoPoint): ${geoPoint.latitude}, ${geoPoint.longitude}');
        }
        // Check for lat/long in location map
        else if (locationMap['latitude'] is num && locationMap['longitude'] is num) {
          clientInfo['location'] = {
            'latitude': locationMap['latitude'].toDouble(),
            'longitude': locationMap['longitude'].toDouble(),
            'address': locationMap['address'] ?? ''
          };
          print('Found client location (nested lat/long): ${locationMap['latitude']}, ${locationMap['longitude']}');
        }
      }
      // Case 3: Direct lat/long fields at root
      else if (userData['latitude'] is num && userData['longitude'] is num) {
        clientInfo['location'] = {
          'latitude': userData['latitude'].toDouble(),
          'longitude': userData['longitude'].toDouble()
        };
        print('Found client location (direct lat/long): ${userData['latitude']}, ${userData['longitude']}');
      }
      // Case 4: Last known location
      else if (userData['lastLocation'] is GeoPoint) {
        final location = userData['lastLocation'] as GeoPoint;
        clientInfo['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude
        };
        print('Found client location (lastLocation): ${location.latitude}, ${location.longitude}');
      }
      // Case 5: Home location as fallback
      else if (userData['homeLocation'] is GeoPoint) {
        final location = userData['homeLocation'] as GeoPoint;
        clientInfo['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'isHomeLocation': true
        };
        print('Found client location (homeLocation): ${location.latitude}, ${location.longitude}');
      } else {
        print('No location data found for client: $clientId');
      }
        // Add any additional contact methods if available
      if (userData.containsKey('alternativePhone')) {
        clientInfo['alternativePhone'] = userData['alternativePhone'];
      }
      if (userData.containsKey('whatsapp')) {
        clientInfo['whatsapp'] = userData['whatsapp'];
      }
      
      return clientInfo;
    } catch (e) {
      print('Error getting client details: $e');
      throw Exception('Failed to get client details');
    }
  }
  
    // Get transport request details for a specific client
  Future<Map<String, dynamic>> getClientTransportRequestDetails(String clientId) async {
    try {
      // Search for accepted transport requests for this client
      print('Searching for transport requests for client: $clientId');
      final requestQuery = await _requestsCollection
        .where('clientId', isEqualTo: clientId)
        .where('serviceType', isEqualTo: 'نقل')
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        if (requestQuery.docs.isEmpty) {
        print('No accepted transport requests found for client: $clientId');
        
        // Even though there are no transport requests, we can still return a basic details object
        // with hasLocationData set to false to prevent null errors in the UI
        return {
          'requestId': '',
          'originName': '',
          'destinationName': '',
          'distanceText': '',
          'durationText': '',
          'price': 0.0,
          'vehicleType': '',
          'hasLocationData': false
        }; // Return empty details instead of null
      }
      
      // Get the most recent transport request
      final requestDoc = requestQuery.docs.first;
      final requestData = requestDoc.data() as Map<String, dynamic>;
      
      print('Found transport request: ${requestDoc.id}');
      
      // Convert GeoPoint objects to readable format if they exist
      Map<String, dynamic> transportDetails = {
        'requestId': requestDoc.id,
        'originName': requestData['originName'] ?? '',
        'destinationName': requestData['destinationName'] ?? '',
        'distanceText': requestData['distanceText'] ?? '',
        'durationText': requestData['durationText'] ?? '',
        'hasLocationData': false,
      };
      
      // Process price properly - ensure it's a double
      var priceValue = requestData['price'];
      if (priceValue != null) {
        if (priceValue is int) {
          transportDetails['price'] = priceValue.toDouble();
        } else if (priceValue is double) {
          transportDetails['price'] = priceValue;
        } else if (priceValue is String) {
          transportDetails['price'] = double.tryParse(priceValue) ?? 0.0;
        } else {
          transportDetails['price'] = 0.0;
        }
      } else {
        transportDetails['price'] = 0.0;
      }
      
      print('Price in transport details: ${transportDetails['price']}');
      
      transportDetails['vehicleType'] = requestData['vehicleType'] ?? '';
      
      // Add location data if available
      if (requestData.containsKey('originLocation') && requestData['originLocation'] != null) {
        try {
          final originGeoPoint = requestData['originLocation'] as GeoPoint;
          transportDetails['originLocation'] = {
            'latitude': originGeoPoint.latitude,
            'longitude': originGeoPoint.longitude,
          };
          transportDetails['hasLocationData'] = true;
          print('Origin location: ${originGeoPoint.latitude}, ${originGeoPoint.longitude}');
        } catch (e) {
          print('Error processing origin location: $e');
        }
      }
      
      if (requestData.containsKey('destinationLocation') && requestData['destinationLocation'] != null) {
        try {
          final destinationGeoPoint = requestData['destinationLocation'] as GeoPoint;
          transportDetails['destinationLocation'] = {
            'latitude': destinationGeoPoint.latitude,
            'longitude': destinationGeoPoint.longitude,
          };
          transportDetails['hasLocationData'] = true;
          print('Destination location: ${destinationGeoPoint.latitude}, ${destinationGeoPoint.longitude}');
        } catch (e) {
          print('Error processing destination location: $e');
        }
      }
      
      return transportDetails;
    } catch (e) {
      print('Error getting client transport request details: $e');
      // Return a valid empty object instead of null to avoid breaking the UI
      return {
        'requestId': '',
        'originName': '',
        'destinationName': '',
        'distanceText': '',
        'durationText': '',
        'price': 0.0,
        'vehicleType': '',
        'hasLocationData': false
      };
    }
  }
}
