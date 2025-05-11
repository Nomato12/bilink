@echo off
echo This script will run the app with the overflow fix verification flags

:: Set environment variables to check for overflow
set FLUTTER_RENDERING_DEBUGOVERFLOWINDICATOR=1

echo Running the app with overflow indicators enabled...
echo You should see red/yellow stripes where any RenderFlex overflows occur
echo.
echo Check if the vehicle cards in the transport service map screen still have overflow issues
echo.

cd d:\bilink
flutter run -d android

pause
