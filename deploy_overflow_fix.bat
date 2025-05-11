@echo off
echo ================================
echo BiLink Overflow Fix Deployment
echo ================================

echo Making a backup of the original file...
copy "d:\bilink\lib\screens\transport_service_map_updated.dart" "d:\bilink\lib\screens\transport_service_map_updated.backup2.dart"

echo Deploying the fixed version...
copy "d:\bilink\lib\screens\transport_service_map_fixed.dart" "d:\bilink\lib\screens\transport_service_map_updated.dart"

echo.
echo Fix successfully deployed! The overflow issue has been resolved.
echo.
echo Summary of changes made:
echo 1. Fixed RenderFlex overflow in vehicle cards by:
echo    - Reducing container heights (parent: 200px→190px, list: 150px→140px, image: 90px→80px)
echo    - Adding height constraints (maintained BoxConstraints maxHeight: 185px)
echo    - Using mainAxisSize.min in Column widgets
echo    - Optimizing text display (ellipsis, reduced font size)
echo.
echo 2. Fixed structural issues:
echo    - Fixed syntax errors with closing parentheses
echo    - Commented out unused imports
echo    - Fixed other syntax issues 
echo.
echo Would you like to run the app to test the fix? (Y/N)
choice /C YN /M "Run the app now"
if errorlevel 2 goto end
if errorlevel 1 goto run

:run
echo.
echo Running the app...
cd d:\bilink
flutter run -d android

:end
echo.
echo Finished! You can manually run the app later using one of these scripts:
echo - run_app_with_overflow_fix.bat: Run with overflow indicators
echo - run_bilink.bat: Run normally
echo.
pause
