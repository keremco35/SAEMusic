# SAE Music Lyrics

A native iOS app that displays real-time word-synced Apple Music lyrics with Spotify playback control support.

## Features

- 🎵 **Multi-Provider Support** - Works with Apple Music and Spotify
- 📝 **Time-Synced Lyrics** - Word-by-word lyrics synchronized at 60fps (Apple Music)
- 🎯 **Tap to Seek** - Tap any lyric line to jump to that position
- 🎨 **Modern UI** - Dark mode with album art blur background
- ▶️ **Playback Controls** - Play, pause, seek, and skip tracks
- 🔄 **Source Switcher** - Seamlessly switch between providers

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Apple Developer Program membership
- Physical iOS device (Simulator doesn't support MusicKit/Spotify)

## Supported Providers

| Feature | Apple Music | Spotify |
|---------|-------------|---------|
| Time-synced lyrics | ✅ Full support | ❌ Not available |
| Playback control | ✅ Direct | ✅ Via Web API |
| Track detection | ✅ 60fps | ✅ 1s polling |
| Background playback | ✅ Built-in | ✅ Spotify app |

> **Note**: Spotify doesn't provide a public lyrics API, so lyrics are only available for Apple Music tracks.

## Architecture

```
MVVM + Providers
├── Protocols
│   └── MusicProvider - Unified playback protocol
├── Views (SwiftUI)
│   ├── NowPlayingView - Main screen layout
│   ├── SourceSelectorView - Provider switcher
│   ├── LyricsWebView - WKWebView for am-lyrics
│   └── PlaybackControlsView - Controls
├── ViewModels
│   └── NowPlayingViewModel - Multi-provider coordinator
├── Services
│   ├── AppleMusicProvider - MusicKit integration
│   ├── Spotify/
│   │   ├── SpotifyProvider - Spotify Web API
│   │   ├── SpotifyAuthManager - OAuth 2.0
│   │   └── KeychainHelper - Secure token storage
│   └── WebViewBridge - JavaScript bridge
└── Models
    ├── Track - Provider-agnostic track model
    └── TrackInfo - Legacy (Apple Music)
```

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SAEMusicLyrics
   ```

2. **Configure Spotify (Optional)**
   - Create app at [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
   - Add redirect URI: `saemusic-spotify://callback`
   - Update `SpotifyConfig.swift` with your Client ID

3. **Open in Xcode**
   ```bash
   open SAEMusicLyrics.xcodeproj
   ```

4. **Configure Signing**
   - Select project in Navigator
   - Go to Signing & Capabilities
   - Select your Development Team
   - Add MusicKit capability

5. **Build & Run**
   - Connect your iPhone/iPad
   - Select it as target
   - Press `Cmd + R`

## Usage

### Apple Music
1. Grant Apple Music access when prompted
2. Play a song in Apple Music
3. Lyrics appear automatically with word-by-word sync

### Spotify
1. Tap Spotify in the source selector
2. Tap "Connect with Spotify"
3. Authorize in Spotify app
4. Control playback from SAE Music Lyrics

## Key Files

| File | Purpose |
|------|---------|
| `MusicProvider.swift` | Unified protocol for music providers |
| `AppleMusicProvider.swift` | Apple Music implementation |
| `SpotifyProvider.swift` | Spotify Web API implementation |
| `SpotifyAuthManager.swift` | OAuth 2.0 authentication |
| `NowPlayingViewModel.swift` | Multi-provider coordinator |
| `SourceSelectorView.swift` | Provider switcher UI |

## Platform Limitations

- **Spotify Lyrics**: Spotify does not provide a public synced lyrics API
- **Audio Streaming**: Spotify audio plays through the Spotify app (per Spotify developer policy)
- **Simulator**: Neither MusicKit nor Spotify App Remote work in Simulator

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No Track Playing" | Ensure music is playing in the selected app |
| No Spotify connection | Check if Spotify app is installed |
| Token expired | Session refreshes automatically |
| Lyrics not available | Spotify tracks don't have lyrics; switch to Apple Music |

## License

MIT License - See LICENSE file for details

## Credits

- [apple-music-web-components](https://github.com/binimum/apple-music-web-components) - Word-synced lyrics
- [LyricsPlus (KPoe)](https://github.com/ibratabian17/YouLyPlus) - Lyrics API provider
- [Spotify Web API](https://developer.spotify.com/documentation/web-api) - Spotify integration
