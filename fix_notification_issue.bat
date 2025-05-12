@echo off
echo Cleaning Flutter project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Rebuilding Android app...
cd android
gradlew clean
cd ..

echo Building and running the app...
flutter run --no-sound-null-safety

echo If the app builds and runs correctly, the notification issue has been fixed!
