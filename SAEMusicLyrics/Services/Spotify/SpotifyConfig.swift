//
//  SpotifyConfig.swift
//  SAEMusicLyrics
//
//  Spotify SDK configuration constants
//

import Foundation

/// Configuration for Spotify SDK
enum SpotifyConfig {
    /// Your Spotify application Client ID
    /// Get this from https://developer.spotify.com/dashboard
    static let clientID = "4fa8d80a53b84290a6dd25b395b1a01f"
    
    /// OAuth redirect URL - must match the one registered in Spotify Dashboard
    static let redirectURL = URL(string: "saemusic-spotify://callback")!
    
    /// Required scopes for app remote control
    static let scopes: [String] = [
        "app-remote-control",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing"
    ]
    
    /// Keychain keys for token storage
    enum KeychainKeys {
        static let accessToken = "com.saemusic.spotify.accessToken"
        static let refreshToken = "com.saemusic.spotify.refreshToken"
        static let tokenExpiration = "com.saemusic.spotify.tokenExpiration"
    }
}
