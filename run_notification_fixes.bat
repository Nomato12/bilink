@echo off
echo ===============================================
echo     Service Request Notification Fix Script
echo ===============================================
echo.

cd /d %~dp0
echo Current directory: %CD%

echo.
echo 1. Running notification system fix...
flutter run -d windows lib\fix_service_request_notifications.dart
if %ERRORLEVEL% neq 0 (
    echo Failed to run notification system fix
    exit /b %ERRORLEVEL%
)

echo.
echo 2. Testing notification system...
flutter run -d windows lib\debug_notification_service.dart
if %ERRORLEVEL% neq 0 (
    echo Failed to run notification system test
    exit /b %ERRORLEVEL%
)

echo.
echo Notification fixes completed successfully.
echo.
pause
