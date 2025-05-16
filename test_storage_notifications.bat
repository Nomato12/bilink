@echo off
echo Running storage notification verification...
cd d:\bilink
flutter run -d web --web-hostname=localhost --web-port=8080 -t verify_storage_notifications.dart
