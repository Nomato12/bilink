@echo off
echo Applying Transport Service Map Improvements...
echo.

echo 1. Adding real road routes instead of straight lines
echo 2. Implementing accurate distance calculation
echo 3. Adding route duration information
echo 4. Fixing null safety issues
echo 5. Improving search UI behavior
echo.

echo Updating the app...
flutter pub get
flutter clean
flutter pub get
flutter run

echo.
echo Transport Service Map improvements applied successfully!
echo Please restart the application to see the changes.
