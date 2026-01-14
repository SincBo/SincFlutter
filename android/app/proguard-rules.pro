# Keep Flutter generated plugin registrant and platform channels to avoid channel errors.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry { *; }
-keep class io.flutter.embedding.engine.plugins.FlutterPlugin** { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }

# Keep ImagePicker plugin classes
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.android.support.** { *; }
-keep class androidx.** { *; }

# Do not strip classes referenced from AndroidManifest
-keepnames class * {
    @androidx.annotation.Keep *;
}

