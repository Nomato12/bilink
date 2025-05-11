@echo off
echo Fixing transport_service_map_updated.dart overflow issue...

powershell -Command "(Get-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart') -replace 'child: Column\(\s+crossAxisAlignment: CrossAxisAlignment.start,\s+children:', 'child: SingleChildScrollView(\n                                child: Column(\n                                  crossAxisAlignment: CrossAxisAlignment.start,\n                                  mainAxisSize: MainAxisSize.min,\n                                  children:'" | Set-Content 'd:\bilink\lib\screens\transport_service_map_updated.dart'"

echo Fix applied. Run the app to verify the fix.
pause
