@echo off
REM This batch file contains commands to test the FCM notification system in BiLink

echo Testing FCM Notification System...
echo.
echo Before running this test:
echo 1. Make sure the app is installed on at least one device
echo 2. Make sure the device has granted notification permissions
echo 3. Make sure the user has logged in at least once (to save FCM token)
echo.
echo Choose a test option:
echo 1. Send a test notification to a user ID
echo 2. Verify FCM token storage in Firestore
echo 3. Check failed notifications
echo.

set /p option="Enter option (1-3): "

if "%option%"=="1" (
    echo.
    set /p userId="Enter user ID to send notification to: "
    echo.
    echo Running Flutter command to send test notification...
    echo.
    echo flutter run -d chrome --web-port=8080 --dart-define=TEST_NOTIFICATION=true --dart-define=USER_ID=%userId%
    echo.
    echo Run this command in your terminal to test sending a notification.
    echo Then check the device to see if the notification was received.
)

if "%option%"=="2" (
    echo.
    echo Checking FCM token storage...
    echo.
    echo To verify that FCM tokens are properly stored:
    echo 1. Open Firebase Console: https://console.firebase.google.com/
    echo 2. Navigate to Firestore
    echo 3. Go to the 'users' collection
    echo 4. Check if user documents have 'deviceTokens' field with valid tokens
    echo.
)

if "%option%"=="3" (
    echo.
    echo Checking failed notifications...
    echo.
    echo To check for failed notifications:
    echo 1. Open Firebase Console: https://console.firebase.google.com/
    echo 2. Navigate to Firestore
    echo 3. Go to the 'fcm_messages' collection
    echo 4. Look for documents with status 'failed'
    echo 5. Check the 'statusMessage' field for error details
    echo.
    echo To check Cloud Functions logs:
    echo 1. Open Firebase Console: https://console.firebase.google.com/
    echo 2. Navigate to Functions
    echo 3. Click on the 'sendNotification' function
    echo 4. Review the logs for any errors
    echo.
)

pause
