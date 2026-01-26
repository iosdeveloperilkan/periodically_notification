import Flutter
import UIKit
import UserNotifications
import Foundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  // #region agent log
  private func debugLog(_ message: String, data: [String: Any] = [:], hypothesisId: String = "") {
    let logPath = "/Applications/periodically_notification/.cursor/debug.log"
    let logEntry: [String: Any] = [
      "sessionId": "debug-session",
      "runId": "run1",
      "hypothesisId": hypothesisId,
      "location": "AppDelegate.swift",
      "message": message,
      "data": data,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
    ]
    if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      if let fileHandle = FileHandle(forWritingAtPath: logPath) {
        fileHandle.seekToEndOfFile()
        fileHandle.write((jsonString + "\n").data(using: .utf8)!)
        fileHandle.closeFile()
      } else {
        try? (jsonString + "\n").write(toFile: logPath, atomically: false, encoding: .utf8)
      }
    }
  }
  // #endregion
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // #region agent log
    debugLog("didFinishLaunchingWithOptions START", data: ["launchOptions": "\(launchOptions ?? [:])"], hypothesisId: "H2")
    // #endregion
    
    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // #region agent log
    debugLog("Before GeneratedPluginRegistrant.register", hypothesisId: "H2")
    // #endregion
    GeneratedPluginRegistrant.register(with: self)
    
    // #region agent log
    debugLog("Before super.application didFinishLaunchingWithOptions", hypothesisId: "H2")
    // #endregion
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // #region agent log
    debugLog("didFinishLaunchingWithOptions END", data: ["result": "\(result)"], hypothesisId: "H2")
    // #endregion
    
    return result
  }
  
  // Handle FCM token registration
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass device token to Flutter
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
  
  // MARK: - Scene Lifecycle (iOS 13+)
  // Override scene lifecycle methods to satisfy iOS 13+ requirements
  // For Flutter apps, we provide a minimal scene configuration
  @available(iOS 13.0, *)
  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // #region agent log
    debugLog("configurationForConnecting START", data: ["role": "\(connectingSceneSession.role)", "sessionRole": "\(connectingSceneSession.role.rawValue)"], hypothesisId: "H1,H3")
    // #endregion
    
    // Return a basic scene configuration without delegate
    // Flutter manages the window lifecycle internally
    let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    
    // #region agent log
    debugLog("configurationForConnecting END", data: ["configName": "\(config.name ?? "nil")", "configRole": "\(config.role.rawValue)", "delegateClass": "\(config.delegateClass?.description ?? "nil")"], hypothesisId: "H1,H3")
    // #endregion
    
    return config
  }
  
  @available(iOS 13.0, *)
  override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // #region agent log
    debugLog("didDiscardSceneSessions", data: ["count": "\(sceneSessions.count)"], hypothesisId: "H1")
    // #endregion
    // No special handling needed for Flutter apps
  }
}
