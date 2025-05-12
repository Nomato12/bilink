@echo off
echo Running Transport Location Fix...
echo This script will fix the transport location data structure
echo to ensure locations show correctly on client pages.
echo.

rem Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Flutter command not found. Please make sure Flutter is installed and in your PATH.
    exit /b 1
)

echo Starting fix process...
flutter run -d windows --no-sound-null-safety apply_transport_location_fix.dart

echo.
echo Fix process completed.
echo Please restart the application for changes to take effect.
echo.

pause