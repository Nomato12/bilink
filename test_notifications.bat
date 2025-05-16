@echo off
echo Testing BiLink Notification System...
flutter run -d chrome --web-renderer html --target=test/notification_verification.dart
echo Test complete.
