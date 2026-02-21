import UIKit
import Flutter
import CarPlay

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let channelName = "com.example.carplay/car_display"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // ── Platform channel: receive display data from Flutter ─────────────
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "updateDisplay",
                  let args = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented)
                return
            }

            // Parse the payload Flutter sends
            let data = DrivingData(
                currentSpeedDisplay: args["currentSpeedDisplay"] as? String ?? "0",
                averageSpeedDisplay: args["averageSpeedDisplay"] as? String ?? "0",
                speedUnit:           args["speedUnit"]           as? String ?? "km/h",
                distanceDisplay:     args["distanceDisplay"]     as? String ?? "0 km",
                durationDisplay:     args["durationDisplay"]     as? String ?? "00:00",
                tripStatus:          args["tripStatus"]          as? String ?? "idle",
                currentSpeedKmh:     args["currentSpeedKmh"]     as? Double ?? 0.0,
                averageSpeedKmh:     args["averageSpeedKmh"]     as? Double ?? 0.0
            )

            // Push to CarPlay controller
            CarPlayController.shared.update(with: data)
            result(nil)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
