@echo off
echo Creating a structural fix for the transport_service_map_updated.dart file...

echo Making a backup of the original file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.backup.dart"

echo Fixing unused imports...
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'import ''package:url_launcher/url_launcher.dart'';', '// import ''package:url_launcher/url_launcher.dart'';' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'import ''package:bilink/screens/service_details_screen.dart'';', '// import ''package:bilink/screens/service_details_screen.dart'';' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'import ''package:bilink/services/location_synchronizer.dart'';', '// import ''package:bilink/services/location_synchronizer.dart'';' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"

echo Fixing comment-only unused fields for now (can be properly removed later)...
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'Map<String, dynamic> _directionsData = {};', '// Used when calculating routes - Map<String, dynamic> _directionsData = {};' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'final bool _showDirectionsPanel = false;', '// For future use - final bool _showDirectionsPanel = false;' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"

echo Ensuring proper structure with ClipRRect and CachedNetworkImage...
powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') | ForEach-Object { $_ -replace 'Icon\(Icons.error\),\s+\),\s+\),', 'Icon(Icons.error),\n                                      ),\n                                    ),' } | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"

echo Running Flutter analyzer to check for remaining issues...
cd d:\bilink
flutter analyze lib\screens\transport_service_map_updated.dart

echo.
echo Fix applied! Check the analysis results above.
echo If there are still issues, you may need to make additional fixes.
echo.
echo You can now run the app to verify the overflow fix:
echo   1. Run 'verify_overflow_fix.bat' to see if any red/yellow overflow indicators appear
echo   2. Run 'run_app_with_overflow_fix.bat' to test the app with the fix applied
echo.

pause
