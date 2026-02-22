# Android Auto / Car App Library Keep Rules
-keep class com.example.carplay.CarPlayAppService { *; }
-keep class com.example.carplay.CarPlayAppSession { *; }
-keep class com.example.carplay.CarPlayAppDashboardScreen { *; }
-keep class com.example.carplay.DrivingData { *; }

# Keep androidx.car.app classes used by reflection
-keep class androidx.car.app.** { *; }
-keep interface androidx.car.app.** { *; }
