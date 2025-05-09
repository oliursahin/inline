import Foundation
import InlineConfig
import InlineKit
import Sentry
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  let notificationHandler = NotificationHandler()
  let nav = Navigation()

  func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Set up notification delegate here to not miss anything
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.delegate = self

    return true
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SentrySDK.start { options in
      options.dsn = InlineConfig.SentryDSN
      options.debug = false
      options.tracesSampleRate = 0.1
      options.attachViewHierarchy = true
      options.enableMetricKit = true
      options.enableTimeToFullDisplayTracing = true
      options.swiftAsyncStacktraces = true
      options.enableAppLaunchProfiling = true
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAuthenticationChange(_:)),
      name: .authenticationChanged,
      object: nil
    )

    return true
  }

  private func applicationDidResignActive(_ notification: Notification) {
//    Task {
//      // Mark offline
//      try? await DataManager.shared.updateStatus(online: false)
//    }
  }

  private func applicationDidBecomeActive(_ notification: Notification) {
//    Task {
//      // Mark online
//      try? await DataManager.shared.updateStatus(online: true)
//    }
  }

  @objc private func handleAuthenticationChange(_ notification: Notification) {
    if let authenticated = notification.object as? Bool, authenticated {
      requestPushNotifications()
    }
  }

  func requestPushNotifications() {
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      guard granted else { return }
      self.getNotificationSettings()
    }
  }

  func getNotificationSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in

      guard settings.authorizationStatus == .authorized else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let deviceToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

    Task {
      let _ = try await ApiClient.shared.savePushNotification(
        pushToken: deviceToken
      )
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {}

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    if let userId = userInfo["userId"] as? Int {
      let peerId = Peer.user(id: Int64(userId))
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // go to home first
        self.nav.popToRoot()
        self.nav.push(.chat(peer: peerId))
      }

      completionHandler()
    }
  }
}

public class NotificationHandler: ObservableObject {
  @Published var authenticated: Bool = false

  public func setAuthenticated(value: Bool) {
    DispatchQueue.main.async {
      self.authenticated = value
      NotificationCenter.default.post(name: .authenticationChanged, object: value)
    }
  }
}

extension Notification.Name {
  static let authenticationChanged = Notification.Name("authenticationChanged")
}
