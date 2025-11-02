import Flutter
import UIKit
import CarPlay

public class NautuneCarplayPlugin: NSObject, FlutterPlugin {
    private static var channel: FlutterMethodChannel?
    private static var interfaceController: CPInterfaceController?
    private static var nowPlayingTemplate: CPNowPlayingTemplate?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "nautune_carplay", binaryMessenger: registrar.messenger())
        let instance = NautuneCarplayPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)
        registrar.addApplicationDelegate(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeCarPlay(result: result)
        case "updateNowPlaying":
            if let args = call.arguments as? [String: Any] {
                updateNowPlaying(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "setPlaybackState":
            if let args = call.arguments as? [String: Any] {
                setPlaybackState(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "updateLibraryContent":
            if let args = call.arguments as? [String: Any] {
                updateLibraryContent(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCarPlay(result: @escaping FlutterResult) {
        // CarPlay initialization
        result(true)
    }
    
    private func updateNowPlaying(args: [String: Any], result: @escaping FlutterResult) {
        guard let title = args["title"] as? String,
              let artist = args["artist"] as? String else {
            result(FlutterError(code: "MISSING_PARAMS", message: "Missing required parameters", details: nil))
            return
        }
        
        let album = args["album"] as? String
        let duration = args["duration"] as? Int ?? 0
        let position = args["position"] as? Int ?? 0
        
        // Update MPNowPlayingInfoCenter
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = TimeInterval(duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = TimeInterval(position)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        result(true)
    }
    
    private func setPlaybackState(args: [String: Any], result: @escaping FlutterResult) {
        guard let isPlaying = args["isPlaying"] as? Bool else {
            result(FlutterError(code: "MISSING_PARAMS", message: "Missing isPlaying parameter", details: nil))
            return
        }
        
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        result(true)
    }
    
    private func updateLibraryContent(args: [String: Any], result: @escaping FlutterResult) {
        // Update CarPlay library/browse content
        result(true)
    }
    
    private func sendCommand(command: String, args: [String: Any]? = nil) {
        Self.channel?.invokeMethod(command, arguments: args)
    }
}

// MARK: - CPApplicationDelegate
extension NautuneCarplayPlugin: CPApplicationDelegate {
    public func application(_ application: UIApplication, 
                          didConnectCarInterfaceController interfaceController: CPInterfaceController,
                          to window: CPWindow) {
        Self.interfaceController = interfaceController
        
        // Create a simple list template for library browsing
        let listTemplate = CPListTemplate(title: "Nautune", sections: [])
        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
        
        // Setup Now Playing template
        Self.nowPlayingTemplate = CPNowPlayingTemplate.shared
        
        sendCommand(command: "carPlayConnected")
    }
    
    public func application(_ application: UIApplication,
                          didDisconnectCarInterfaceController interfaceController: CPInterfaceController,
                          from window: CPWindow) {
        Self.interfaceController = nil
        sendCommand(command: "carPlayDisconnected")
    }
}

// MARK: - CPNowPlayingButtonHandler
extension NautuneCarplayPlugin {
    @objc private func handlePlayPause() {
        sendCommand(command: "playPause")
    }
    
    @objc private func handleNext() {
        sendCommand(command: "next")
    }
    
    @objc private func handlePrevious() {
        sendCommand(command: "previous")
    }
}
