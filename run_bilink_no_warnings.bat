@echo off
REM This script runs the BiLink Flutter app with suppressed warnings
echo Running BiLink with suppressed warnings...

cd /d "%~dp0"

REM Set environment variables to suppress specific warnings
set GRADLE_OPTS=-Dorg.gradle.daemon=false -Dorg.gradle.logging.level=quiet
set JAVA_OPTS=-Xmx2048m -XX:MaxPermSize=512m -Dcom.android.build.gradle.overrideVersionCheck=true

REM Run the Flutter app with specific flags to reduce warnings
flutter run --verbose --no-hot ^
  --dart-define=SUPPRESS_FIREBASE_WARNINGS=true ^
  --dart-define=FLUTTER_WEB_USE_SKIA=false

echo BiLink app completed execution.
