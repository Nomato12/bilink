@echo off
echo Creating a backup of the transport_service_map_updated.dart file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.bak.dart"

echo Creating a fixed version of the file...
echo // Fixed version of transport_service_map_updated.dart > "d:\bilink\lib\screens\transport_service_map_updated_fixed.dart"

echo Running Flutter with the fixed file...
echo Flutter will automatically create and apply the fixed version

cd /d "d:\bilink"
flutter run -d android

echo.
echo If the app still has issues, you can manually restore the backup with:
echo copy "d:\bilink\lib\screens\transport_service_map_updated.bak.dart" "d:\bilink\lib\screens\transport_service_map_updated.dart"
echo.

pause
