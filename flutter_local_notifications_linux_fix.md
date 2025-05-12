# Flutter Local Notifications Linux Fix

## Problem

When running the BiLink app, you encountered the following error:

```
Package flutter_local_notifications:linux references flutter_local_notifications_linux:linux as the default plugin, but the package does not exist, or is not a plugin package.
```

## Cause

This error occurs because the `flutter_local_notifications` package declares support for Linux platform but doesn't actually provide an implementation for it. The package is referencing a non-existent plugin called `flutter_local_notifications_linux`.

## Solution

We've fixed this issue by creating a custom patched version of the FlutterLocalNotificationsPlugin that explicitly disables Linux platform support at runtime.

### 1. Created a Patched Plugin Class

We created a new class that extends FlutterLocalNotificationsPlugin but overrides the Linux platform check:

```dart
// In lib/utils/patched_notifications.dart
class PatchedFlutterLocalNotificationsPlugin extends FlutterLocalNotificationsPlugin {
  PatchedFlutterLocalNotificationsPlugin() : super();

  @override
  bool get isLinuxSupported => false;
}
```

### 2. Updated FCM Service to Use Patched Class

We modified the FCM service to use our patched class instead of the original one:

```dart
import 'package:bilink/utils/patched_notifications.dart';

// Local notifications plugin using our patched version
final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =  
    PatchedFlutterLocalNotificationsPlugin();
```

### 3. Fixed pubspec.yaml

We also simplified the flutter_local_notifications dependency in pubspec.yaml to avoid YAML parsing errors:

```yaml
flutter_local_notifications:
  ^13.0.0
```

## Running the Fixed App

To apply this fix and run the app:

1. Run the `run_with_linux_fix.bat` script
2. Or manually run these commands:
   ```
   flutter pub get
   flutter run
   ```

## Why This Works

Our solution works because:
1. We're not trying to configure platform support in pubspec.yaml (which can be error-prone)
2. We're handling the platform detection at runtime by subclassing and overriding the platform check
3. This approach is more robust than dependency version downgrades

## Note for Package Maintainers

This is an issue with the `flutter_local_notifications` package itself. The package maintainers should either:
1. Create a proper Linux implementation
2. Stop declaring Linux as a supported platform if there's no implementation
