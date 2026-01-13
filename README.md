# Nautune 🎵🌊

Poseidon's cross-platform Jellyfin music player. Nautune is built with Flutter and delivers a beautiful deep-sea themed experience with smooth native audio playback and seamless Jellyfin integration.

## 🚀 Latest Updates (v3.4.0)
- **🎨 UI Polish**:
  - ✅ **Cleaner Fullscreen Player**: Quality indicator (Direct/Transcoding badge) now displays below track info instead of beside it, preventing janky horizontal overflow
- **📁 Tidier File Organization (Desktop)**:
  - ✅ **Dedicated App Folder**: All app data now stored in `nautune/` subfolder instead of cluttering user directories
  - ✅ **Downloads**: Linux/macOS/Windows downloads now go to `./nautune/downloads/` instead of `./downloads/`
  - ✅ **Hive Databases**: Session, playback, cache, and download databases now stored in `~/Documents/nautune/` instead of directly in `~/Documents/`
  - ✅ **Automatic Migration**: Existing users' files are automatically moved to the new location on first launch - no data loss

## 🚀 Previous Updates (v3.3.0)
- **🎵 Transcoding & Quality Control**:
  - ✅ **Smart Transcoding**: Stream your music at 128k, 192k, or 320k to save bandwidth on mobile networks
  - ✅ **Visual Quality Badge**: New indicator in the player shows exactly how you're streaming (e.g., "Direct", "128k Transcode")
  - ✅ **Reliable Reporting**: Fixed playback reporting to correctly show "Transcode" status on your Jellyfin dashboard
  - ✅ **Force Transcode**: Improved compatibility logic to ensure Jellyfin respects your bitrate limits, even for stubborn formats
  - ✅ **Session Linking**: Transcoding sessions are now properly linked to playback reports for accurate server-side tracking

## 🚀 Previous Updates (v3.2.1)
- **🚗 CarPlay Navigation Fix**:
  - ✅ **Fixed infinite loading**: Resolved issue where CarPlay menus would spin indefinitely when browsing Albums, Artists, Playlists, Favorites, or Recently Played
  - ✅ **Navigation lock**: Added protection to prevent root template refreshes from interrupting active navigation
  - ✅ **Debounced state updates**: App state changes now debounce (500ms) before refreshing CarPlay UI, preventing rapid UI resets
  - ✅ **Guaranteed completion**: All navigation handlers now use try/finally to ensure the CarPlay spinner always stops, even on errors

## 🚀 Previous Updates (v3.2.0)
- **🎨 Immersive Visual Overhaul**:
  - ✅ **Album Art Gradients**: The Full Player and Mini-Player now feature beautiful, opaque dynamic backgrounds derived directly from the current album art.
  - ✅ **Isolate-Powered Extraction**: Color palette generation runs in a background isolate, ensuring 60FPS UI performance during track transitions.
  - ✅ **Smart Palette Caching**: Recently played albums have their color profiles cached (LRU) for near-instant background updates.
- **🖼️ Sleek Desktop Mini-Player**:
  - ✅ **Frameless Design**: The desktop mini-player now uses a hidden title bar for a modern, "floating widget" aesthetic.
  - ✅ **Window Dragging**: Even without a title bar, you can drag the mini-player anywhere on your screen by clicking and dragging the background.
  - ✅ **Seamless Transitions**: Window decorations are automatically restored when expanding back to the full-size player.
- **🎵 Refined Lyrics Experience**:
  - ✅ **Optimized Backgrounds**: Adjusted blur (Sigma 100) and darkening overlays to ensure lyrics remain perfectly readable over vibrant album gradients.

## 🚀 Previous Updates (v3.0.0)
- **🎵 Synced Lyrics Experience**:
  - ✅ **Beautiful Lyrics UI**: New dedicated tab in the full-screen player with high-quality typography
  - ✅ **Auto-Scrolling**: Active lyrics automatically center and scroll smoothly as the song plays
  - ✅ **Tap-to-Seek**: Click any lyric line to instantly jump the audio to that exact moment
  - ✅ **Intelligent Interactions**: Auto-scroll pauses when you're manually browsing lyrics and resumes after 2 seconds
  - ✅ **Visual Focus**: Past lines are subtly dimmed while the current line is highlighted with primary colors and soft shadows
- **🔒 Security Hardening**:
  - ✅ **Removed sensitive debug logging**: API error responses no longer log full body content that may contain user data
  - ✅ **Android network security config**: Explicit network security policy with documented cleartext allowance for local Jellyfin servers
  - ✅ **Improved URL validation**: Server URLs now validated for proper format (scheme, host) before use
  - ✅ **Session migration robustness**: Encrypted storage migration now handles corrupt data gracefully instead of silently failing
- **⚡ Performance Optimizations**:
  - ✅ **Color extraction moved to isolate**: Album art gradient extraction now runs in background isolate, eliminating UI jank when switching tracks
  - ✅ **Fixed memory leak**: System tray stream listeners now properly cancelled on dispose
  - ✅ **Cached filtered favorites**: Offline favorites list no longer recomputed on every frame

## 🚀 Previous Updates (v2.7.5)
- **🎵 Advanced Playlist Management**:
  - ✅ **Drag-and-Drop Reordering**: Long-press and drag tracks to reorder them in any playlist
  - ✅ **Offline Playlist Sync**: Download entire playlists with a single tap for airplane-mode listening
  - ✅ **Visual Enhancements**: Playlist tracks now show individual album artwork instead of generic icons
- **🎧 Playback Experience**:
  - ✅ **Fade-on-Pause / Resume**: Smooth 400ms volume ramping when pausing/resuming for a premium audio feel
  - ✅ **Swipe-to-Skip**: Horizontal swipe gestures on the bottom mini-player bar for quick track changes
  - ✅ **Tray Robustness**: Improved Linux system tray stability with better error handling for missing platform plugins
- **🎨 Immersive Visuals**:
  - ✅ **Professional Color Extraction**: Migrated to `material_color_utilities` (Material You engine) for high-quality palette generation
  - ✅ **Vibrant Gradients**: More pronounced and smoother background gradients in the full-screen player based on album art

## 🚀 Previous Updates (v2.7.0)
- **🔧 Critical Bug Fixes**: Improved reliability across all platforms
  - ✅ **Album continuous playback fixed**: Playing state now properly emitted after gapless transitions
    - Previously, albums would pause after each song instead of playing continuously
    - Fixed by explicitly emitting playing state when swapping preloaded players
  - ✅ **iOS state persistence fixed**: App now reliably saves playback state when backgrounded
    - Save operations are now properly awaited before app suspension
    - Hive storage flushes to disk immediately instead of buffering in memory
    - Volume setting now included in pause/background state snapshots
  - ✅ **Stop properly clears playback state**: Fixed nullable field handling in clearPlayback()
    - Previously, stop button wasn't fully clearing queue/track state due to Dart's `??` operator
    - Now directly constructs clean state object while preserving UI settings
  - ✅ **Alphabet scrollbar sorting fixed**: Now works correctly with all sort orders
    - Rewrote with O(1) letter-to-index lookup map for better performance
    - Properly handles ascending/descending sort with nearest-letter fallback
    - Fixed scroll position calculation and bubble positioning
- **📥 Album Track Pre-Caching**: Smoother playback when listening to albums
  - ✅ **Auto pre-cache on play**: When you play an album, remaining tracks cache in background
  - ✅ **Smart source priority**: Downloads → Cached files → Stream (fastest available)
  - ✅ **Gapless preload uses cache**: Next track preloading checks cache first
  - ✅ **Automatic cleanup**: Cache auto-expires after 7 days, max 500 files
  - ✅ **Manual clear**: Settings → Performance → "Clear Audio Cache" button

## 🚀 Previous Updates (v2.5.0)
- **⚡ API & Performance Optimizations**: Faster, more reliable server communication
  - ✅ **Batch API Requests**: Albums, artists, genres load in parallel with `Future.wait()`
  - ✅ **Request Retry with Backoff**: Auto-retries failed requests 3x with exponential backoff
  - ✅ **HTTP Connection Pooling**: Reuses connections for faster subsequent requests
  - ✅ **ETag Caching**: Skips re-downloading unchanged data (304 responses)
  - ✅ **Server Health Check**: Ping server before heavy operations
  - ✅ **Graceful Timeout Handling**: Shows "server slow" instead of cryptic errors
- **⚙️ Cache Configuration**: Fine-tune performance
  - ✅ **Configurable TTL**: Settings → Performance → Cache Duration (5 minutes to 1 week)
  - ✅ **Album Track Caching**: Pre-cache track lists for downloaded albums
  - ✅ **Persisted setting**: Cache preference survives app restarts
- **📳 Haptic Feedback (Mobile)**: Tactile response on iOS/Android
  - ✅ **Play/Pause**: Light tap feedback
  - ✅ **Next/Previous**: Medium tap feedback
  - ✅ **Platform-aware**: Only triggers on mobile devices
- **🔧 Code Quality**: Debouncer/Throttler utilities for search and scroll events

## 🚀 Previous Updates (v2.4.0)
- **📻 Infinite Radio Mode**: Never-ending music discovery
  - ✅ **Auto-generates queue**: Fetches similar tracks when queue runs low (≤2 tracks remaining)
  - ✅ **Powered by Jellyfin InstantMix**: Uses server-side similarity analysis
  - ✅ **Seamless continuation**: New tracks append silently without interrupting playback
  - ✅ **No duplicates**: Automatically filters out tracks already in queue
  - ✅ **Toggle in Settings**: Enable/disable under Audio Options
  - ✅ **Persisted preference**: Setting survives app restarts
- **🔢 Sorting Options**: Organize your library your way
  - ✅ **Albums sort**: By name, date added, year, or play count
  - ✅ **Artists sort**: By name, date added, or play count
  - ✅ **Ascending/descending**: Toggle sort direction with one tap
  - ✅ **Server-side sorting**: Fast results via Jellyfin API
  - ✅ **Clean UI**: Dropdown + direction button in Library tab header
- **🔲 System Tray (Desktop)**: Background playback controls
  - ✅ **Linux/Windows/macOS**: Native system tray integration
  - ✅ **Playback controls**: Play/Pause, Previous, Next from tray menu
  - ✅ **Track info**: Current song displayed in tooltip and menu
  - ✅ **Quick access**: Right-click for context menu
  - ⚠️ **Linux requirement**: `libayatana-appindicator3-dev` package

## 🚀 Previous Updates (v2.3.0)
- **💾 Enhanced Playback State Persistence**: Never lose your place again
  - ✅ **Pause saves everything**: Queue, position, track, repeat mode, shuffle state all preserved
  - ✅ **Resume exactly where you left off**: App remembers your exact playback position after pause
  - ✅ **Force-close protection**: Full state saved on app lifecycle events (background, inactive, detached)
  - ✅ **iOS & Linux support**: Works reliably on both platforms even after force quit
  - ✅ **Stop still clears**: Stop button intentionally clears queue for fresh start (unchanged)
- **🚗 CarPlay Fixes**: App now properly appears in CarPlay
  - ✅ **Entitlements linked**: Fixed `CODE_SIGN_ENTITLEMENTS` configuration in Xcode project
  - ✅ **AppDelegate fixed**: Returns `true` directly for CarPlay compatibility
  - ✅ **Early initialization**: CarPlay service initializes immediately on app start
  - ✅ **Works offline**: Browse and play downloaded music in car without internet

## 🚀 Previous Updates (v2.1.0+)
- **🚗 Enhanced CarPlay Integration**: Smarter, more reliable car experience
  - ✅ **Connection state tracking**: Properly detects CarPlay connect/disconnect events
  - ✅ **Auto-refresh on connect**: Library content refreshes when CarPlay connects
  - ✅ **Auto-refresh on data change**: Content updates when library data changes
  - ✅ **Empty state handling**: Clear messages when no albums/playlists/favorites available
  - ✅ **Proper queue context**: Playing tracks from CarPlay now queues the full album/playlist
  - ✅ **Offline-aware messaging**: Empty states show different messages when offline
- **📱 iOS App Lifecycle Management**: Robust state persistence
  - ✅ **Background state saving**: Playback state saved immediately when app goes to background
  - ✅ **Resume connectivity check**: Connectivity checked when app returns to foreground
  - ✅ **Lifecycle observer**: Proper `WidgetsBindingObserver` integration for pause/resume
  - ✅ **Seamless restore**: Resume exactly where you left off after backgrounding
- **🔄 Smoother Offline/Online Transitions**: Graceful network handling
  - ✅ **Debounced online detection**: 2-second delay prevents flicker from unstable connections
  - ✅ **Instant offline detection**: Going offline is immediate - users know right away
  - ✅ **Smart mode switching**: Only switches back to online mode after successful data refresh
  - ✅ **Background refresh**: Data refreshes in background after reconnection
  - ✅ **Graceful fallback**: Stays offline if refresh fails after reconnect

## 🚀 Previous Updates (v2.0.0+)
- **💎 The "Silver Bullet" Progress Bar**: Buttery smooth tracking
  - ✅ **Jitter-Free**: Replaced jumping sliders with `audio_video_progress_bar`
  - ✅ **RxStream Synchronization**: Unified `PositionData` stream combines current position, buffered status, and metadata duration using `rxdart`
  - ✅ **Instant Feedback**: Metadata duration is injected into the stream immediately upon selection, eliminating "--:--" lag
- **⚡ True Gapless Player Swapping**: Zero-latency transitions
  - ✅ **Dual-Player Engine**: Implemented physical player swapping (`_player` ↔ `_nextPlayer`) for instant track changes
  - ✅ **Dynamic Listener Re-attachment**: UI and media controls automatically follow the active player instance during swaps
  - ✅ **MPRIS/Lockscreen Sync**: Media controls stay synchronized with the active audio instance even across track boundaries
- **🛡️ Playback Stability**:
  - ✅ **Non-Blocking Stop**: "Stop" command now kills audio immediately and skips awaiting network reporting to prevent deadlocks
  - ✅ **BehaviorSubject State**: Core playback streams migrated to `BehaviorSubject` for instant UI hydration on screen entry
  - ✅ **Deadlock Prevention**: Fixed "Ghost Playback" where audio would continue if the network call to the server hung


## 🧪 Review / Demo Mode

Apple's Guideline 2.1 requires working reviewer access. Nautune includes an on-device demo that mirrors every feature—library browsing, downloads, playlists, CarPlay, and offline playback—without touching a real Jellyfin server.

1. **Credentials**: leave the server field blank, use username `tester` and password `testing`.
2. The login form detects that combo and seeds a showcase library with open-source media. Switching back to a real server instantly removes demo data (even cached downloads).
3. Demo mode is documented in `assets/demo/README.md`, which also lists licensing notes for the bundled tracks and artwork.

### Demo assets recap

- Streaming samples (bundled MP3s for demo mode only):
  - `assets/demo/demo_online_track.mp3` – “Ocean Vibes” from Pixabay (track: https://pixabay.com/music/beats-ocean-vibes-391210/ · Pixabay License).
  - `assets/demo/demo_offline_track.mp3` – “Sirens and Silence” from Pixabay (track: https://pixabay.com/music/modern-classical-sirens-and-silence-10036/ · Pixabay License). This file also powers the offline/download view so reviewers see a real track in airplane mode.
- Artwork: intentionally uses the shared fallbacks `assets/no_album_art.png` and `assets/no_artist_art.png`, making it easy to drop in a branded placeholder that demo + production both inherit.

## 📸 Screenshots

### Linux
<img src="screenshots/Screenshot_20251105_163913.png" width="400" alt="Nautune on Linux">
<img src="screenshots/Screenshot_20251105_164039.png" width="400" alt="Nautune on Linux">

### iOS
<img src="screenshots/IMG_9047.jpg" width="300" alt="Nautune on iOS">
<img src="screenshots/IMG_9048.jpg" width="300" alt="Nautune on iOS">
<img src="screenshots/IMG_9052.jpg" width="300" alt="Nautune on iOS">


## 🔧 Development

### Run in Debug Mode
```bash
flutter run -d linux --debug
```

### Build Release
```bash
flutter build linux --release
```

### Build Deb Package (Linux)
```bash
# Requires: dart pub global activate fastforge
fastforge package --platform linux --targets deb
```

### Build AppImage (Linux)
```bash
flutter build linux --release && \
rm -rf AppDir && \
mkdir -p AppDir/usr/bin && \
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/ && \
cp linux/nautune.desktop AppDir/ && \
cp linux/nautune.png AppDir/ && \
cd AppDir && ln -s usr/bin/nautune AppRun && cd .. && \
mkdir -p dist && \
ARCH=x86_64 ./appimagetool AppDir dist/Nautune-x86_64.AppImage
```

### Static Analysis
```bash
flutter analyze
```

### Format Code
```bash
flutter format lib/
```

### Run Tests
```bash
flutter test
```

## 🌐 Building for Other Platforms

- **Linux**: Builds with `flutter build linux --release`
  - ✅ Native GStreamer audio backend (FLAC/lossless support)
  - ✅ Desktop icon included (`linux/nautune.png` + `nautune.desktop`)
  - ✅ Offline downloads stored in project `downloads/` directory
  - ✅ All Jellyfin features work on Linux
  - ⚠️ **System Tray requires**: `sudo apt install libayatana-appindicator3-dev`
- **iOS**: Builds produced by **Codemagic CI** with full feature support
  - ✅ **Native audio playback** via AVFoundation (FLAC/AAC/lossless support)
  - ✅ **Lock screen controls** with album artwork via audio_service
  - ✅ **Full CarPlay integration** - browse library, playlists, favorites, downloads in car mode
  - ✅ **Offline downloads** stored in app documents (airplane mode compatible)
  - ✅ CarPlay works fully offline with downloaded content
  - ✅ All Jellyfin features work on iOS (playback reporting, favorites sync, playlist management)
- **Windows**: `flutter build windows` (requires Windows machine with VS 2022)
  - ✅ System tray works out of the box
- **macOS**: `flutter build macos` (requires macOS with Xcode)
  - ✅ System tray works out of the box
- **Web**: `flutter run -d chrome` for dev, `flutter build web` for production
- **Android**: Not currently a focus; no Android SDK required for development

### 🚗 CarPlay Support (iOS Only)

Nautune includes **full CarPlay integration** for iOS powered by the `flutter_carplay` plugin:


#### 🔧 Implementation Details
- **Flutter CarPlay Plugin**: `flutter_carplay: ^1.1.4` handles all CarPlay UI and interactions
- **CarPlay Service**: `lib/services/carplay_service.dart` - connects CarPlay to app state with connection tracking
- **Info.plist Configuration**: 
  - UIBackgroundModes with `audio` for background playback
  - CarPlay entitlements in `ios/Runner/Runner.entitlements`:
    - `com.apple.developer.carplay-audio`
    - `com.apple.developer.playable-content`
- **Dart-Only Implementation**: All CarPlay logic is in Dart - no custom Swift code needed
- **Offline Downloads**: iOS stores downloads in app documents directory - accessible even offline
- **Lock Screen Controls**: Album artwork, play/pause, skip buttons via audio_service plugin

## 🗺️ Roadmap


### 🚧 Planned
- [ ] **Advanced Equalizer**: 10-band EQ with per-genre presets.
- [ ] **Shared Listening**: Sync playback with other Nautune users.

## 📝 Development Guidelines

1. **Follow Flutter/Dart lints**: Enforced by `analysis_options.yaml`. Run `flutter analyze` before committing.
2. **Write tests**: Add unit/widget tests for new features. Run `flutter test`.
3. **Keep UI declarative**: Centralize styling in `lib/theme/nautune_theme.dart`.
4. **Jellyfin integration**: Keep all API logic in `lib/jellyfin/`. Expose state via `NautuneAppState`.
5. **Graceful error states**: Show loading spinners, error messages, and retry buttons.
6. **Document complex flows**: Add inline comments for non-obvious logic.
7. **Commit frequently**: Use descriptive commit messages. Sync via SSH.

## 🤝 Contributing & Collaboration

1. **Feature branches**: Work on branches, open PRs against `main` with screenshots/demos
2. **Coordinate platform changes**: Discuss desktop shortcuts, CarPlay hooks early
3. **Code reviews**: All PRs require review before merge
4. **Testing**: Ensure builds pass on Linux before pushing
5. **Codemagic**: Note iOS build considerations in PR descriptions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Jellyfin](https://jellyfin.org/) - Amazing open-source media server
- [audioplayers](https://pub.dev/packages/audioplayers) - Cross-platform native audio engine
- [audio_session](https://pub.dev/packages/audio_session) - Native audio session management
- Flutter team - Incredible cross-platform framework

## 💬 Support & Community

- 🐛 **Bug reports**: Open an issue with steps to reproduce
- ✨ **Feature requests**: Describe your idea in an issue
- ⭐ **Star the repo**: If you like Nautune, show your support!
- 🔔 **Follow for updates**: Watch the repo for new releases

---

**Made with 💜 by ElysiumDisc** | Dive deep into your music 🌊🎵
