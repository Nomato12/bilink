@echo off
echo Testing BiLink Transport Location UI Enhancements
echo ==============================================
echo.
echo This script will run the BiLink app with the enhanced transport location UI.
echo.
echo What you should test:
echo 1. Navigate to the Transport Services section
echo 2. Select origin and destination locations
echo 3. Verify that vehicles appear on the map and in the bottom sheet
echo 4. Check that the UI follows the Yassir app design style
echo 5. Test the booking flow by selecting a vehicle
echo.
echo If you encounter any issues, please report them with detailed steps to reproduce.
echo.
echo Press any key to start the app...
pause > nul

cd /d "%~dp0"
flutter clean
flutter pub get
flutter run -d windows --no-sound-null-safety
