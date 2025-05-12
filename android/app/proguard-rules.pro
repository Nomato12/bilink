-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firebase Messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn io.flutter.plugins.firebase.**

# For Java unchecked operations in Firebase Messaging
-dontwarn java.io.**
-dontwarn org.slf4j.**

# Generic Android warnings
-dontwarn android.content.Context
-dontwarn android.animation.ObjectAnimator

# Include Firebase Messaging specific rules
-include firebase-messaging-rules.pro

# Flutter Local Notifications specific rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-dontwarn com.dexterous.flutterlocalnotifications.models.styles.BigPictureStyleInformation
-dontwarn com.dexterous.flutterlocalnotifications.models.styles.BigTextStyleInformation

# AndroidX Core - specifically handling the bigLargeIcon issue
-keep class androidx.core.app.NotificationCompat$BigTextStyle { *; }
-keep class androidx.core.app.NotificationCompat$BigPictureStyle { *; }
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
-dontwarn androidx.core.app.**

# Ignore all warnings for development builds
-ignorewarnings
