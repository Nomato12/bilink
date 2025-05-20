# Suppress lint warnings for Firebase Messaging
-dontwarn io.flutter.plugins.firebase.messaging.**
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# Suppress unsafe operations warnings
-dontwarn java.lang.invoke.*
-dontwarn sun.misc.Unsafe
-dontwarn javax.annotation.**

# Additional suppressions for unchecked operations
-dontwarn java.util.concurrent.Flow*
-dontwarn javax.naming.**
-dontwarn kotlin.Deprecated
-dontwarn kotlin.Unit

# Firebase core suppressions
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Specifically for FlutterFirebaseMessagingPlugin unchecked operations
-keepclassmembers class io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin {
    *;
}
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep methods with @Keep annotation
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * {*;}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <init>(...);
}
