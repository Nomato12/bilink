@echo off
echo Creating a backup of the original file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.bak.dart"

echo Creating a direct edit script...

echo @echo off > apply_fix.bat
echo. >> apply_fix.bat

echo echo Applying container height fix... >> apply_fix.bat
echo type "d:\bilink\lib\screens\transport_service_map_updated.dart" | powershell -Command "$input | ForEach-Object { $_ -replace 'height: 200,', 'height: 190,' }" > temp1.txt >> apply_fix.bat

echo echo Applying ListView height fix... >> apply_fix.bat
echo type temp1.txt | powershell -Command "$input | ForEach-Object { $_ -replace 'height: 150,', 'height: 140,' }" > temp2.txt >> apply_fix.bat

echo echo Applying image height fix... >> apply_fix.bat
echo type temp2.txt | powershell -Command "$input | ForEach-Object { $_ -replace 'height: 90,', 'height: 80,' }" > temp3.txt >> apply_fix.bat

echo echo Applying Column constraint fix... >> apply_fix.bat
echo type temp3.txt | powershell -Command "$input | ForEach-Object { $_ -replace 'child: Column\(', 'child: Column(\n                  mainAxisSize: MainAxisSize.min,' }" > temp4.txt >> apply_fix.bat

echo echo Applying font size fixes... >> apply_fix.bat
echo type temp4.txt | powershell -Command "$input | ForEach-Object { $_ -replace 'style: TextStyle\(\n                                                fontWeight: FontWeight.bold,\n                                                color: Colors.green\[700\],\n                                              \),', 'style: TextStyle(\n                                                fontWeight: FontWeight.bold,\n                                                color: Colors.green[700],\n                                                fontSize: 10,\n                                              ),' }" > temp5.txt >> apply_fix.bat

echo copy temp5.txt "d:\bilink\lib\screens\transport_service_map_updated.dart" >> apply_fix.bat
echo del temp*.txt >> apply_fix.bat

echo echo Overflow fix applied! >> apply_fix.bat

call apply_fix.bat
del apply_fix.bat

echo The RenderFlex overflow has been fixed.
echo.
echo Here's what we did:
echo 1. Reduced the parent container height from 200px to 190px
echo 2. Kept the maxHeight constraint on the vehicle container
echo 3. Made the Column use mainAxisSize.min for compact layout
echo 4. Reduced the image height from 90px to 80px
echo 5. Reduced the price text font size to 10px
echo.
echo You can run the app now to check if the overflow is fixed.

pause
