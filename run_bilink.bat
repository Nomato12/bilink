@echo off
echo Building and running BiLink app with optimized settings...

:: Clean first to ensure all changes are applied
flutter clean

:: Get dependencies
flutter pub get

:: Run the app with optimized settings for Android
flutter run --debug --no-warning-mode --dart-flags="--omit-warnings" %*
