@echo off
echo Creating temporary directory...
mkdir temp_fix
cd temp_fix

echo Downloading the flutter_local_notifications Android build.gradle...
curl -o build.gradle https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/flutter_local_notifications/android/build.gradle

echo Patching the build.gradle file...
echo namespace 'com.dexterous.flutterlocalnotifications' >> build.gradle

echo Copying the patched file to the plugin directory...
copy build.gradle "%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_local_notifications-13.0.0\android\build.gradle"

echo Cleaning up...
cd ..
rmdir /s /q temp_fix

echo Namespace patch applied successfully!
