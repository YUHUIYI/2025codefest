import UIKit
import Flutter
import flutter_local_notifications
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 設定 Flutter Method Channel 用於接收 Google Maps API Key
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let googleMapsChannel = FlutterMethodChannel(
      name: "com.example.townpass/google_maps",
      binaryMessenger: controller.binaryMessenger
    )
    
    googleMapsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setApiKey" {
        if let apiKey = call.arguments as? String, !apiKey.isEmpty {
          GMSServices.provideAPIKey(apiKey)
          result(true)
        } else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "API Key is required",
            details: nil
          ))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
