# Testing FCM Notifications After Fix

This guide provides steps to verify that FCM notifications are working correctly after fixing the build issue.

## 1. Testing Local Notifications (When App is in Foreground)

1. Run the app using the `fix_notification_issue.bat` script
2. Navigate to a screen where a notification might be triggered (e.g., service request screen)
3. Create a new service request to trigger a notification
4. Verify that a local notification appears even when the app is in the foreground

## 2. Testing Background Notifications

1. Run the app and log in with two different accounts on two different devices
2. Send the app to the background on the device that will receive the notification
3. Use the other device to trigger an action that would send a notification
4. Verify that the notification is received on the background device
5. Tap on the notification to confirm it opens the correct screen in the app

## 3. Using the Debug Helper

If notifications aren't working, use the notification debug helper:

```dart
import 'package:bilink/utils/notification_debug_helper.dart';

// In your testing code
final debugHelper = NotificationDebugHelper();
await debugHelper.checkFcmToken(); // Verify token exists
await debugHelper.checkNotificationPermission(); // Verify permissions
await debugHelper.sendTestNotification(); // Send a test notification
```

## 4. Common Issues and Solutions

- If notifications don't appear, check the Firebase Cloud Functions logs
- Verify that the device token is being saved correctly in Firestore
- Check that the notification channel is created correctly
- Verify that the app has notification permissions

## 5. Deploying Cloud Functions

If you need to update the cloud functions:

1. Navigate to the functions directory: `cd functions`
2. Install dependencies: `npm install`
3. Deploy the functions: `firebase deploy --only functions`
4. Check the Firebase console for successful deployment
