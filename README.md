# SAE Music Lyrics

A native iOS app that displays real-time word-synced Apple Music lyrics using the `am-lyrics` web component.

## Features

- 🎵 **Now Playing Detection** - Automatically detects currently playing Apple Music track
- 📝 **Time-Synced Lyrics** - Word-by-word lyrics synchronized at 60fps
- 🎯 **Tap to Seek** - Tap any lyric line to jump to that position
- 🎨 **Modern UI** - Dark mode with album art blur background
- ▶️ **Playback Controls** - Play, pause, seek, and skip tracks

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Apple Developer Program membership
- Active Apple Music subscription (for full functionality)
- Physical iOS device (Simulator doesn't support MusicKit playback detection)

## Architecture

```
MVVM + Services
├── Views (SwiftUI)
│   ├── NowPlayingView - Main screen layout
│   ├── LyricsWebView - WKWebView wrapper for am-lyrics
│   └── PlaybackControlsView - Play/pause, progress, skip
├── ViewModels
│   └── NowPlayingViewModel - Coordinates MusicKit + WebView
├── Services
│   ├── MusicKitService - MusicKit authorization, playback, 60fps updates
│   └── WebViewBridge - JavaScript ↔ Swift communication
└── Models
    └── TrackInfo - Track metadata model
```

## Data Flow

```
┌─────────────┐     ┌───────────────────┐     ┌─────────────────┐
│ Apple Music │────▶│  MusicKitService  │────▶│ NowPlayingVM    │
│   (iOS)     │     │  (60fps updates)  │     │                 │
└─────────────┘     └───────────────────┘     └────────┬────────┘
                                                       │
                                                       ▼
┌─────────────┐     ┌───────────────────┐     ┌─────────────────┐
│ am-lyrics   │◀────│   WebViewBridge   │◀────│ updateCurrentTime│
│ (Web Comp.) │     │   (Swift <-> JS)  │     │ updateTrackInfo │
└──────┬──────┘     └───────────────────┘     └─────────────────┘
       │                     ▲
       │ line-click          │ seek request
       └─────────────────────┘
```

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SAEMusicLyrics
   ```

2. **Open in Xcode**
   ```bash
   open SAEMusicLyrics.xcodeproj
   ```

3. **Configure Signing**
   - Select the project in Navigator
   - Go to Signing & Capabilities
   - Select your Development Team
   - Add MusicKit capability if not present

4. **Build & Run**
   - Connect your iPhone/iPad
   - Select it as the build target
   - Press `Cmd + R`

## Usage

1. Grant Apple Music access when prompted
2. Open Apple Music and play any song
3. Return to SAE Music Lyrics
4. Watch synced lyrics appear and scroll automatically
5. Tap any lyric line to seek to that position

## How Lyrics Sync Works

1. **Track Detection**: MusicKit observes `MPMusicPlayerControllerNowPlayingItemDidChange` notifications
2. **Time Updates**: CADisplayLink updates playback time at 60fps
3. **Web Bridge**: Swift sends `currentTime` (in milliseconds) to JavaScript
4. **am-lyrics Component**: Web component highlights current word and auto-scrolls
5. **Seek on Tap**: Line-click events are sent from JS to Swift via `WKScriptMessageHandler`

## Key Files

| File | Purpose |
|------|---------|
| `MusicKitService.swift` | MusicKit authorization, playback observation, controls |
| `WebViewBridge.swift` | WKWebView + JavaScript bridge for am-lyrics |
| `NowPlayingViewModel.swift` | Coordinates services, manages state |
| `NowPlayingView.swift` | Main UI with album art, lyrics, controls |
| `LyricsWebView.swift` | UIViewRepresentable wrapper for WKWebView |

## Lyric Providers

The app uses the **LyricsPlus (KPoe)** API via the am-lyrics web component:
- Fetches word-synced lyrics based on song title and artist
- Falls back to Apple Music endpoint if LyricsPlus is unavailable
- Supports ISRC codes for precise song matching

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No Track Playing" | Ensure Apple Music is playing, not another app |
| No lyrics appear | Song may not have synced lyrics available |
| Authorization denied | Go to Settings > Privacy > Media & Apple Music |
| Lyrics out of sync | Try pausing and resuming playback |

## License

MIT License - See LICENSE file for details

## Credits

- [apple-music-web-components](https://github.com/binimum/apple-music-web-components) - Word-synced lyrics component
- [LyricsPlus (KPoe)](https://github.com/ibratabian17/YouLyPlus) - Lyrics API provider
