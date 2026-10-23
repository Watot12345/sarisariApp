# Flutter & Android Widget / ML Kit / Local Notifications ProGuard Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SariMe Home Screen Widget Provider
-keep class com.tindahan.app.SariWidgetProvider { *; }
-keep class es.antonborri.home_widget.** { *; }

# Keep Google ML Kit Barcode Scanning classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter Local Notifications classes & receivers
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Suppress Play Core SplitInstall warnings (SariMe is 100% offline and does not use dynamic feature modules)
-dontwarn com.google.android.play.core.**
