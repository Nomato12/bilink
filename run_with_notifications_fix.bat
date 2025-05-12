@echo off
echo Cleaning Flutter project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building and running app...
flutter run --no-sound-null-safety

echo If you still see Linux notifications warnings, they can be safely ignored as we've patched the notifications plugin to properly handle this case.
