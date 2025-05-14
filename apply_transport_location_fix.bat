// filepath: d:\bilink\apply_transport_location_fix.bat
@echo off
echo Starting Transport Location Fix...
echo.

cd /d %~dp0
dart apply_transport_location_fix.dart

echo.
echo Transport Location Fix Completed
echo.
pause
