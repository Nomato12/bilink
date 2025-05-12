@echo off
echo Cleaning Flutter project...
flutter clean

echo Getting dependencies with fixed platform configuration...
flutter pub get

echo Running the app with fixed flutter_local_notifications configuration...
flutter run --no-sound-null-safety

echo If the app launches without the Linux platform error, the fix was successful!
