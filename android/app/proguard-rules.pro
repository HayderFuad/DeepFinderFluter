# Prevent R8 / ProGuard from obfuscating Flutter MethodChannels & Native Plugin Methods
-dontobfuscate

# Preserve reflection attributes required by Flutter plugins, Pigeon & Coroutines
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep Flutter Engine & Plugin Interfaces
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep specific plugin packages & Pigeon generated classes
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class **.SharedPreferencesApiRegistrar { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.crazecoder.openfile.** { *; }

# Keep Kotlin Coroutines
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }

# Keep SQLite and Secure Storage ProGuard Rules
-dontwarn com.tekartik.sqflite.**
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**
