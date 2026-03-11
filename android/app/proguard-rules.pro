# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }

# Keep mailer classes
-keep class mailer.** { *; }

# Keep all model classes
-keep class com.zeynabijaz.five_s_digital_assessment.models.** { *; }
