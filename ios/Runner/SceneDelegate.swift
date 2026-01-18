//
//  SceneDelegate.swift
//  Runner
//
//  Created for Nautune CarPlay integration.
//

import Flutter
import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    window = UIWindow(windowScene: windowScene)

    let controller = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    controller.loadDefaultSplashScreenView()
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    // Handle deep link from cold start (QR code scan when app is closed)
    if let urlContext = connectionOptions.urlContexts.first {
      print("🔗 SceneDelegate: Cold start URL: \(urlContext.url)")
      // Forward to AppDelegate which Flutter/app_links hooks into
      _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
        UIApplication.shared,
        open: urlContext.url,
        options: [:]
      )
    }

    // Handle universal links from cold start
    if let userActivity = connectionOptions.userActivities.first,
       userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      print("🔗 SceneDelegate: Cold start universal link: \(url)")
      _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
        UIApplication.shared,
        open: url,
        options: [:]
      )
    }
  }

  // Handle deep link when app is already running (QR code scan when app is in background)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    print("🔗 SceneDelegate: openURLContexts received URL: \(url)")
    // Forward to AppDelegate which Flutter/app_links hooks into
    _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }

  // Handle universal links (https:// URLs) when app is already running
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      print("🔗 SceneDelegate: Universal link received: \(url)")
      // Forward to AppDelegate which Flutter/app_links hooks into
      _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
        UIApplication.shared,
        open: url,
        options: [:]
      )
    }
  }
}
