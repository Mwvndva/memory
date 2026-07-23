# Flutter R8 / ProGuard Rules for Memory App

# Ignore missing optional Play Core / split installation classes in Flutter Engine
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Keep Flutter Engine and Entrypoints
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep androidx.room and androidx.work used by home_widget
-keep class androidx.room.** { *; }
-keepclassmembers class androidx.room.** { *; }
-keep class androidx.work.** { *; }
-keepclassmembers class androidx.work.** { *; }

# Keep Firebase & FCM reflection entrypoints
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
