import UIKit
import Flutter

let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate {
  var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    // Register Audio FFT plugin for real-time visualization
    AudioFFTPlugin.register(with: flutterEngine.registrar(forPlugin: "AudioFFTPlugin")!)

    // Register Share plugin for native file sharing (AirDrop, etc.)
    SharePlugin.register(with: flutterEngine.registrar(forPlugin: "SharePlugin")!)

    // Register App Icon plugin for alternate icon support
    AppIconPlugin.register(with: flutterEngine.registrar(forPlugin: "AppIconPlugin")!)

    // Return true directly for CarPlay compatibility
    // super.application() can interfere with CarPlay initialization
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Request background time to ensure Flutter can save playback state
    backgroundTaskIdentifier = application.beginBackgroundTask(withName: "SavePlaybackState") { [weak self] in
      self?.endBackgroundTask()
    }

    // Allow 3 seconds for Flutter to save state
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
      self?.endBackgroundTask()
    }
  }

  private func endBackgroundTask() {
    guard backgroundTaskIdentifier != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
    backgroundTaskIdentifier = .invalid
  }
}
