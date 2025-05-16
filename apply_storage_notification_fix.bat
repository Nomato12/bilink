@echo off
echo Applying storage service notification fixes...

REM Run the main fix script
cd d:\bilink
echo Running verification test for storage service notifications...
flutter run -t verify_storage_notifications.dart

echo.
echo Fix applied. Please test the application to verify that:
echo 1. Storage service requests appear correctly for providers
echo 2. Providers receive notifications when clients request their storage service
echo 3. The notification badge updates properly in the provider interface
echo.
