# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Play Services / Firebase (if present)
-keep class com.google.** { *; }
-dontwarn com.google.**

# Keep Kotlin metadata
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn org.jetbrains.annotations.**

# OkHttp/Okio (if used by http/dio)
-dontwarn okhttp3.**
-dontwarn okio.**
