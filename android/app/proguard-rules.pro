# Keep Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Keep Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Keep Flutter Workmanager plugin
-keep class dev.fluttercommunity.workmanager.** { *; }

# Keep AndroidX WorkManager (fixes database constructor NoSuchMethodException)
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
