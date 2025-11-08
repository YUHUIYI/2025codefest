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
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    
    // 延遲設定 Method Channel，確保 window 已經準備好
    DispatchQueue.main.async {
      self.setupGoogleMapsChannel()
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupGoogleMapsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      // 如果 window 還沒準備好，稍後再試
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.setupGoogleMapsChannel()
      }
      return
    }
    
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
  }
}
