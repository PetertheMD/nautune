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
      // Forward to AppDelegate which Flutter/app_links hooks into
      _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
        UIApplication.shared,
        open: urlContext.url,
        options: [:]
      )
    }
  }

  // Handle deep link when app is already running (QR code scan when app is in background)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    // Forward to AppDelegate which Flutter/app_links hooks into
    _ = (UIApplication.shared.delegate as? FlutterAppDelegate)?.application(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }
}
