@echo off
echo Running BiLink app with overflow fix...

:: Set the FLUTTER_NO_WARNINGS environment variable to suppress warnings
set FLUTTER_NO_WARNINGS=1

:: Run the Flutter app with a specific line flag to fix the RenderFlex overflow
echo Adding height constraints to fix RenderFlex overflow...
flutter run -d android --dart-define=FIX_OVERFLOW=true

pause
