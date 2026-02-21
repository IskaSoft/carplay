package com.example.carplay
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity wires the Flutter MethodChannel to the Android Auto service.
 * All GPS work is done in Flutter/Dart; this class only forwards display data.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.example.carplay/car_display"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateDisplay" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data != null) {
                            // Forward to Android Auto service via a local broadcast
                            CarPlayAppService.updateDrivingData(
                                currentSpeedDisplay = data["currentSpeedDisplay"] as? String ?: "0",
                                averageSpeedDisplay = data["averageSpeedDisplay"] as? String ?: "0",
                                speedUnit           = data["speedUnit"]           as? String ?: "km/h",
                                distanceDisplay     = data["distanceDisplay"]     as? String ?: "0 km",
                                durationDisplay     = data["durationDisplay"]     as? String ?: "00:00",
                                tripStatus          = data["tripStatus"]          as? String ?: "idle",
                                currentSpeedKmh     = (data["currentSpeedKmh"]   as? Double) ?: 0.0,
                                averageSpeedKmh     = (data["averageSpeedKmh"]   as? Double) ?: 0.0,
                            )
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Expected Map argument", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
