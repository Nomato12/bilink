@echo off
echo Running verification for service type display fix...
echo This will check and repair any transport services showing as storage services.

echo.
echo === RUNNING THE FIX ===
flutter run -d windows lib\widgets\service_request_card.dart

echo.
echo === VERIFYING THE FIX ===
flutter run -d windows verify_service_type_display_fix.dart

echo.
echo Verification complete!
pause
