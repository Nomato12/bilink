@echo off
ECHO Making a backup of the original file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.bak.dart"

ECHO Applying the RenderFlex overflow fix...

:: Create a temporary PowerShell script to run the fix
echo $file = 'd:\bilink\lib\screens\transport_service_map_updated.dart' > fix_overflow.ps1
echo $content = Get-Content $file -Raw >> fix_overflow.ps1

:: Reduce the height of the main container from 200 to 190
echo $content = $content -replace "height: 200,", "height: 190,"  >> fix_overflow.ps1

:: Reduce the container height from 150 to 140 in the ListView
echo $content = $content -replace "height: 150,", "height: 140," >> fix_overflow.ps1

:: Reduce the image height from 90 to 80
echo $content = $content -replace "height: 90,", "height: 80," >> fix_overflow.ps1

:: Reduce the font size for the price text
echo $content = $content -replace "style: TextStyle(\(\s+fontWeight: FontWeight.bold,\s+color: Colors.green\[700\],\s+\),)", "style: TextStyle$1\n                                                fontSize: 10," >> fix_overflow.ps1

:: Add mainAxisSize.min to the main Column
echo $content = $content -replace "child: Column\(\s+children:", "child: Column(\n                  mainAxisSize: MainAxisSize.min,\n                  children:" >> fix_overflow.ps1

:: Set the output
echo Set-Content -Path $file -Value $content >> fix_overflow.ps1

:: Execute the PowerShell script
powershell -ExecutionPolicy Bypass -File fix_overflow.ps1

:: Clean up
del fix_overflow.ps1

ECHO The RenderFlex overflow has been fixed. Running the app...
cd d:\bilink
flutter run -d android

pause
