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

# Ignore all warnings for development builds
-ignorewarnings
