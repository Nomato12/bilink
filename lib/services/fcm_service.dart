// filepath: d:\bilink\lib\services\fcm_service.dart 
import 'package:firebase_messaging/firebase_messaging.dart'; 
// Import commented out since notifications are disabled
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
 
/// Service for handling Firebase Cloud Messaging (FCM) notifications 
class FcmService { 
  // Firebase instances 
  final FirebaseMessaging _messaging = FirebaseMessaging.instance; 
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; 
  final FirebaseAuth _auth = FirebaseAuth.instance; 
 
  // Notification channel for Android - commented out since notifications are disabled
  // final AndroidNotificationChannel _channel = const AndroidNotificationChannel( 
  //   'high_importance_channel', 
  //   '??????? ????', 
  //   description: '?????? ??? ?????? ????????? ??????', 
  //   importance: Importance.high, 
  //   enableVibration: true, 
  //   enableLights: true, 
  //   showBadge: true, 
  // ); 
 
  // Local notifications plugin - commented out since notifications are disabled
  // final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =  
  //     FlutterLocalNotificationsPlugin();
 
  /// Initialize the FCM service 
  Future<void> initialize() async { 
    // Request notification permissions 
    await requestPermission(); 
 
    // Setup local notifications 
    await _initializeLocalNotifications(); 
 
    // Set up background message handler 
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage); 
 
    // Set up foreground message handler 
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage); 
 
    // Set up handling for when notifications are tapped 
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen); 
 
    // Save the device token for the current user 
    await saveDeviceToken(); 
  } 
 
  /// Request notification permissions 
  Future<void> requestPermission() async { 
    NotificationSettings settings = await _messaging.requestPermission( 
      alert: true, 
      announcement: false, 
      badge: true, 
      carPlay: false, 
      criticalAlert: true, 
      provisional: false, 
      sound: true, 
    ); 
 
    debugPrint('??????? ?????: ${settings.authorizationStatus}'); 
  } 
   /// Initialize local notifications 
  Future<void> _initializeLocalNotifications() async { 
    // تخطي تهيئة الإشعارات المحلية عندما تكون الإشعارات معطلة
    debugPrint('تم تخطي تهيئة الإشعارات المحلية');
    return;

    // الكود القديم لتهيئة الإشعارات المحلية - تم تعطيله
    /*
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher'); 
 
    const DarwinInitializationSettings initializationSettingsIOS = 
        DarwinInitializationSettings( 
      requestSoundPermission: true, 
      requestBadgePermission: true, 
      requestAlertPermission: true, 
    ); 
 
    const InitializationSettings initializationSettings = InitializationSettings( 
      android: initializationSettingsAndroid, 
      iOS: initializationSettingsIOS, 
    ); 
 
    await _flutterLocalNotificationsPlugin.initialize( 
      initializationSettings, 
      onDidReceiveNotificationResponse: (NotificationResponse response) { 
        final payload = response.payload; 
        if (payload != null) { 
          debugPrint('تم النقر على الإشعار: $payload'); 
        } 
      }, 
    ); 
 
    // Create notification channel for Android 
    await _flutterLocalNotificationsPlugin 
        .resolvePlatformSpecificImplementation< 
            AndroidFlutterLocalNotificationsPlugin>() 
        ?.createNotificationChannel(_channel);
    */
  } 
 
  /// Save the device token for the current user 
  Future<void> saveDeviceToken() async { 
    try { 
      User? user = _auth.currentUser; 
      if (user == null) return; 
 
      String? token = await _messaging.getToken(); 
      if (token == null) return; 
 
      debugPrint('?? ?????? ??? ??? ??????: $token'); 
 
      // Save the device token in Firestore 
      await _firestore.collection('users').doc(user.uid).update({ 
        'deviceTokens': FieldValue.arrayUnion([token]), 
        'lastTokenUpdate': FieldValue.serverTimestamp(), 
      }); 
    } catch (e) { 
      debugPrint('??? ?? ??? ??? ??????: $e'); 
    } 
  } 
   /// Send a notification to a user 
  Future<void> sendNotificationToUser({ 
    required String userId, 
    required String title, 
    required String body, 
    Map<String, dynamic>? data, 
  }) async { 
    // تخطي إرسال الإشعارات للمستخدمين
    debugPrint('تم إلغاء إرسال الإشعار إلى المستخدم: $userId');
    debugPrint('عنوان الإشعار: $title');
    return;
    
    /*
    // الكود القديم لإرسال الإشعارات - تم تعطيله
    try { 
      // Get user device tokens 
      final userDoc = await _firestore.collection('users').doc(userId).get(); 
      if (!userDoc.exists) { 
        debugPrint('المستخدم غير موجود: $userId'); 
        return; 
      } 
 
      final userData = userDoc.data(); 
      if (userData == null) { 
        debugPrint('بيانات المستخدم فارغة: $userId'); 
        return; 
      } 
 
      // Extract tokens 
      final List<dynamic> tokens = userData['deviceTokens'] ?? []; 
 
      // Show a local notification (for when app is in foreground) 
      _showLocalNotification(title: title, body: body, payload: data?.toString()); 
 
      if (tokens.isEmpty) { 
        debugPrint('لا توجد رموز جهاز للمستخدم: $userId - تخطي إرسال الإشعار'); 
        return; 
      } 
 
      // Queue notification in Firestore for processing by Cloud Functions 
      await _firestore.collection('fcm_messages').add({ 
        'tokens': tokens, 
        'notification': { 
          'title': title, 
          'body': body, 
        }, 
        'data': data ?? {}, 
        'userId': userId, 
        'status': 'pending', 
        'createdAt': FieldValue.serverTimestamp(), 
      }); 
 
      debugPrint('تم إضافة الإشعار إلى الفايرستور: $userId (${tokens.length} جهاز)'); 
    } catch (e) { 
      debugPrint('خطأ في إرسال الإشعار: $e'); 
    }    */
  }  
  
  // Commented out since notifications are disabled
  /*
  /// Show a local notification 
  Future<void> _showLocalNotification({ 
    required String title, 
    required String body, 
    String? payload,
  }) async { 
    // تخطي عرض الإشعارات المحلية لكن دون حذف الدالة نفسها لأنها مستخدمة في أماكن أخرى
    debugPrint('تم حذف الإشعار المحلي: $title');
    return;
  }
  */
   /// Handle background messages 
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async { 
    await Firebase.initializeApp(); 
 
    debugPrint('تم استلام إشعار في الخلفية: ${message.notification?.title}');
    // تخطي معالجة الإشعارات في الخلفية
    return;
  }/// Handle foreground messages 
  void _handleForegroundMessage(RemoteMessage message) { 
    debugPrint('تم استلام إشعار في المقدمة: ${message.notification?.title}'); 
    
    // حذف جميع الإشعارات - تخطي عرض الإشعارات بالكامل
    return;
    
    /*
    // الكود القديم لعرض الإشعارات - تم تعطيله
    final data = message.data;
    final isForClient = data['isForClient'] == 'true';
    final targetScreen = data['targetScreen'];
    final currentUserId = _auth.currentUser?.uid;
    final targetUserId = data['userId'];
    
    final bool shouldShow = (!isForClient) || 
                           (isForClient && targetUserId == currentUserId);
    
    final bool isApprovalNotification = data['type'] == 'request_update' && 
                                       data['status'] == 'accepted';
    
    if (isApprovalNotification && targetUserId != currentUserId) {
      return;
    }
    
    if (message.notification != null && shouldShow) { 
      _showLocalNotification( 
        title: message.notification!.title ?? 'إشعار جديد', 
        body: message.notification!.body ?? '', 
        payload: message.data.toString(), 
      ); 
    }
    */
  }
   /// Handle notification open (when user taps on a notification) 
  void _handleNotificationOpen(RemoteMessage message) { 
    debugPrint('تم النقر على الإشعار: ${message.notification?.title}'); 
    
    // حذف جميع الإشعارات - تخطي معالجة النقر على الإشعار
    return;
    
    /*
    // الكود القديم لمعالجة النقر على الإشعارات - تم تعطيله
    final data = message.data; 
    if (data.isEmpty) return; 

    final targetUserId = data['userId'];
    final currentUserId = _auth.currentUser?.uid;
    
    if (targetUserId != null && targetUserId != currentUserId) {
      return;
    }
    
    final notificationType = data['type']; 
    final isForClient = data['isForClient'] == 'true';
    final targetScreen = data['targetScreen']; 
    
    if (notificationType == 'request_update' && isForClient && targetScreen == 'client_interface') { 
      // Only route to client notifications screen if this is a client notification
      // Navigator.pushNamed(context, '/notifications'); 
    }
    */
  }
}
