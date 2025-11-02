# Nautune CarPlay Plugin

iOS CarPlay integration for the Nautune music player.

## Features

- ✅ Now Playing screen with track info and album art
- ✅ Playback controls (play/pause, next, previous)
- ✅ Library browsing in CarPlay interface
- ✅ Integration with iOS Media Player framework
- ✅ Simple, focused car-friendly UI

## Requirements

- iOS 14.0+
- CarPlay entitlement from Apple
- Xcode 13+

## Setup

### 1. Enable CarPlay Capability

In your iOS project (`ios/Runner.xcodeproj`):
1. Select the Runner target
2. Go to "Signing & Capabilities"
3. Click "+ Capability" and add "CarPlay"

### 2. Update Info.plist

Add the required CarPlay scene configuration to `ios/Runner/Info.plist`:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>CarPlay Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>NautuneCarplayPlugin</string>
            </dict>
        </array>
    </dict>
</dict>
```

### 3. Add to pubspec.yaml

```yaml
dependencies:
  nautune_carplay:
    path: plugins/nautune_carplay
```

## Usage

### Initialize CarPlay

```dart
import 'package:nautune_carplay/nautune_carplay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize CarPlay
  await NautuneCarplay.initialize();
  
  // Set up command handler
  NautuneCarplay.setCommandHandler((command, args) {
    switch (command) {
      case 'playPause':
        // Handle play/pause
        break;
      case 'next':
        // Handle next track
        break;
      case 'previous':
        // Handle previous track
        break;
    }
  });
  
  runApp(MyApp());
}
```

### Update Now Playing Info

```dart
await NautuneCarplay.updateNowPlaying(
  trackId: track.id,
  title: track.name,
  artist: track.displayArtist,
  album: track.album,
  duration: track.duration ?? Duration.zero,
  position: currentPosition,
  artworkUrl: track.artworkUrl(),
);
```

### Update Playback State

```dart
await NautuneCarplay.setPlaybackState(isPlaying: true);
```

## Testing

CarPlay can be tested using the iOS Simulator:
1. Run your app in the iOS Simulator
2. Open "I/O" → "External Displays" → "CarPlay"
3. The CarPlay interface will appear in a separate window

## License

MIT License - see LICENSE file for details
