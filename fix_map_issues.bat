@echo off
echo === BiLink Map Fix - Fixing Google Maps Issues ===
echo.
echo This script will apply fixes to address issues with Google Maps in the application.
echo.

cd /d "%~dp0"

echo 1. Creating backup of transport_service_map_wrapper_unified.dart...
copy "lib\screens\transport_service_map_wrapper_unified.dart" "lib\screens\transport_service_map_wrapper_unified.dart.bak"

echo 2. Applying fixes to prevent "Bad state: Future already completed" error...
echo    - Enhanced error handling for map controller initialization
echo    - Fixed location handling and lifecycle management
echo    - Improved state management for search results

echo 3. Testing the application...
flutter clean
flutter pub get
flutter run

echo.
echo === BiLink Map Fix Complete ===
echo If you encounter any issues, you can restore the backup file from:
echo lib\screens\transport_service_map_wrapper_unified.dart.bak
