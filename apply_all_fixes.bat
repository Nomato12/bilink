@echo off
echo Fixing BiLink critical errors...

echo 1. Fixing notification_service.dart...
echo Already fixed - no need to modify

echo 2. Fixing client_details_screen.dart...
powershell -Command "((Get-Content -Path 'd:\bilink\lib\screens\client_details_screen.dart' -Raw) -replace 'if \(transportDetails != null \&\&\r\n          transportDetails\[''hasLocationData''\] == true\)', 'if (transportDetails[''hasLocationData''] == true)') | Set-Content -Path 'd:\bilink\lib\screens\client_details_screen.dart'"

echo 3. Fixing WhatsApp method in client_details_screen.dart...
type d:\bilink\fix_whatsapp_method.dart > d:\bilink\fixed_whatsapp_method.txt
powershell -Command "$content = Get-Content -Path 'd:\bilink\lib\screens\client_details_screen.dart' -Raw; $whatsappMethod = Get-Content -Path 'd:\bilink\fixed_whatsapp_method.txt' -Raw; $pattern = '(?s)  // دالة لفتح محادثة واتساب مع العميل.*?(  })'; $content = $content -replace $pattern, $whatsappMethod; $content | Set-Content -Path 'd:\bilink\lib\screens\client_details_screen.dart'"

echo All fixes applied!
echo Run the app with "flutter run" to verify that the issues are resolved.
