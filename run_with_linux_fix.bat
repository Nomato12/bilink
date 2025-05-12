@echo off
echo Applying fix for flutter_local_notifications Linux issue...

echo Getting dependencies...
flutter pub get

echo Building and running the app with Linux platform issue fixed...
flutter run

echo If the app launches successfully, the Linux platform error is fixed!
