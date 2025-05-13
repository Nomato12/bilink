
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/fcm_service.dart';

/// Helper class for debugging notification issues
class NotificationDebugHelper {
  final FcmService _fcmService = FcmService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get and display the current FCM token
  Future<String?> getCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('Current FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Check if notification permissions are granted
  Future<bool> checkNotificationPermissions() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      final authStatus = settings.authorizationStatus;
      
      debugPrint('Notification authorization status: $authStatus');
      
      return authStatus == AuthorizationStatus.authorized || 
             authStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  /// Send a test notification to the current user
  Future<bool> sendTestNotificationToSelf() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return false;
      }

      await _fcmService.sendNotificationToUser(
        userId: user.uid,
        title: 'Test Notification',
        body: 'This is a test notification sent at ${DateTime.now()}',
        data: {'type': 'test_notification', 'timestamp': DateTime.now().millisecondsSinceEpoch.toString()},
      );

      debugPrint('Test notification sent to current user (${user.uid})');
      return true;
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      return false;
    }
  }

  /// Check if FCM token is saved in Firestore for current user
  Future<bool> isTokenSavedInFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return false;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        debugPrint('User document does not exist in Firestore');
        return false;
      }

      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('User data is null');
        return false;
      }

      final deviceTokens = userData['deviceTokens'];
      if (deviceTokens == null || deviceTokens is! List || deviceTokens.isEmpty) {
        debugPrint('No device tokens found for user');
        return false;
      }

      final currentToken = await _messaging.getToken();
      final tokenExists = deviceTokens.contains(currentToken);
      
      debugPrint('Token exists in Firestore: $tokenExists');
      debugPrint('Tokens in Firestore: $deviceTokens');
      
      return tokenExists;
    } catch (e) {
      debugPrint('Error checking token in Firestore: $e');
      return false;
    }
  }

  /// Force refresh and save FCM token
  Future<bool> forceRefreshToken() async {
    try {
      await _fcmService.saveDeviceToken();
      debugPrint('FCM token refreshed and saved');
      return true;
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
      return false;
    }
  }

  /// Show a notification debug dialog with options to test notifications
  Future<void> showDebugDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Debug'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _gatherDebugInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            
            final data = snapshot.data ?? {};
            
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FCM Token: ${data['token'] ?? 'Not available'}'),
                  const SizedBox(height: 8),
                  Text('Permissions Granted: ${data['permissionsGranted'] ? 'Yes' : 'No'}'),
                  const SizedBox(height: 8),
                  Text('Token Saved in Firestore: ${data['tokenInFirestore'] ? 'Yes' : 'No'}'),
                  const SizedBox(height: 8),
                  const Text('Use the buttons below to test notification functionality.'),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await sendTestNotificationToSelf();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Test notification sent!' 
                      : 'Failed to send test notification'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Send Test Notification'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await forceRefreshToken();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Token refreshed and saved!' 
                      : 'Failed to refresh token'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Refresh Token'),
          ),
        ],
      ),
    );
  }

  /// Gather debug info about notifications
  Future<Map<String, dynamic>> _gatherDebugInfo() async {
    final token = await getCurrentToken();
    final permissionsGranted = await checkNotificationPermissions();
    final tokenInFirestore = await isTokenSavedInFirestore();
    
    return {
      'token': token,
      'permissionsGranted': permissionsGranted,
      'tokenInFirestore': tokenInFirestore,
    };
  }
}
