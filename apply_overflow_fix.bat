@echo off
echo Creating a backup of the original file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.backup.dart"

echo Creating fixed version...
powershell -Command "Set-Content -Path 'd:\bilink\lib\screens\transport_service_map_updated.dart' -Value (Get-Content 'd:\bilink\lib\screens\transport_service_map_updated_fixed.dart')"

echo Done! Running the app...
cd d:\bilink
flutter run -d android

pause
