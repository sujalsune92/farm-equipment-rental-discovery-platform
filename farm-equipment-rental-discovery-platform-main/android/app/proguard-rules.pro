# Keep TensorFlow Lite classes required by tflite_flutter (GPU delegates etc.)
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.**

# Keep Google Generative AI client models
-keep class com.google.ai.client.generativeai.** { *; }
-dontwarn com.google.ai.client.generativeai.**

# Keep native methods referenced via JNI
-keepclassmembers class * {
	native <methods>;
}
