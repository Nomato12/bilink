@echo off
setlocal

set PLUGIN_GRADLE_PATH=C:\Users\SAAD ABDERRAHMANE\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_local_notifications-13.0.0\android\build.gradle

echo Patching %PLUGIN_GRADLE_PATH%

REM Check if the namespace is already added
findstr /C:"namespace \"com.dexterous.flutterlocalnotifications\"" "%PLUGIN_GRADLE_PATH%" >nul
if %errorlevel% equ 0 (
    echo Namespace already exists.
) else (
    echo Adding namespace...
    REM Create a temporary file
    copy "%PLUGIN_GRADLE_PATH%" "%PLUGIN_GRADLE_PATH%.tmp" >nul
    (for /f "delims=" %%i in ('findstr /n "^" "%PLUGIN_GRADLE_PATH%.tmp"') do (
        set "line=%%i"
        setlocal enabledelayedexpansion
        echo !line:*:=!
        if "!line:*:=!"=="android {" (
            echo     namespace "com.dexterous.flutterlocalnotifications"
        )
        endlocal
    )) > "%PLUGIN_GRADLE_PATH%"
    del "%PLUGIN_GRADLE_PATH%.tmp"
    echo Namespace added successfully.
)

echo Cleaning Flutter project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Running the app...
flutter run --no-sound-null-safety

echo Build process initiated. Check the output for success or further errors.

endlocal
