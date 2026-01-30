# Keep ML Kit Text Recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Ignore missing ML Kit language-specific classes (not included in base dependency)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep Google ML Kit commons
-keep class com.google.mlkit.** { *; }

# Prevent R8 from stripping interface information
-keep,allowobfuscation,allowshrinking interface com.google.mlkit.** { *; }
-keep,allowobfuscation,allowshrinking class * extends com.google.mlkit.** { *; }

# Keep Flutter plugin classes
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }
