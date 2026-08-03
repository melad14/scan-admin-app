# Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin

# Firebase & FCM
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin serialization & coroutines
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlinx.coroutines.**

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep crash-free for release
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
