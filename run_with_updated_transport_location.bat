@echo off
echo Running BiLink app with updated transport location functionality...

echo Applying all fixes for transport location selection...

cd /d "%~dp0"
flutter run -d windows --no-sound-null-safety
