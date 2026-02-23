# ──────────────────────────────────────────────────────────────
#  ProGuard rules for MindSpore Lite AAR
#  Prevent R8 from stripping native bridge classes
# ──────────────────────────────────────────────────────────────

# Keep all MindSpore public API
-keep class com.mindspore.** { *; }
-keepclassmembers class com.mindspore.** { *; }

# Keep Huawei HiAI engine classes (used internally by MindSpore Lite)
-keep class com.huawei.hiaiengine.** { *; }
-keepclassmembers class com.huawei.hiaiengine.** { *; }

# Suppress warnings for classes that may not be present on all devices
-dontwarn com.mindspore.**
-dontwarn com.huawei.hiaiengine.**

# Keep the Flutter plugin registration
-keep class com.example.mindspore_lite_flutter.MindsporeLiteFlutterPlugin { *; }
