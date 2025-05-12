import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

/// A wrapper for the flutter_local_notifications package
/// that disables Linux platform support to avoid the
/// missing implementation error.
class NotificationsWrapper {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Get the plugin instance
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Initialize the notifications plugin
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    // Skip initialization on Linux platform
    if (Platform.isLinux) {
      return false;
    }

    return _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Show a notification
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    // Skip on Linux platform
    if (Platform.isLinux) {
      return;
    }

    return _plugin.show(id, title, body, notificationDetails, payload: payload);
  }

  /// Create notification channel
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) async {
    // Skip on Linux platform
    if (Platform.isLinux) {
      return;
    }

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }
  }
}
