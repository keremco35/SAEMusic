//
//  MusicProvider.swift
//  SAEMusicLyrics
//
//  Unified protocol for music playback providers
//

import Foundation
import Combine

/// Music source types
enum MusicSource: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .appleMusic: return "applelogo"
        case .spotify: return "music.note.tv"
        }
    }
}

/// Unified protocol for music playback providers
@MainActor
protocol MusicProvider: ObservableObject {
    /// Current track being played
    var currentTrack: Track? { get }
    
    /// Current playback time in seconds
    var playbackTime: TimeInterval { get }
    
    /// Whether currently playing
    var isPlaying: Bool { get }
    
    /// Whether connected/authorized to the service
    var isConnected: Bool { get }
    
    /// Whether this provider supports lyrics display
    var supportsLyrics: Bool { get }
    
    /// Display name for the provider
    var providerName: String { get }
    
    /// Music source type
    var source: MusicSource { get }
    
    /// Connect/authorize with the music service
    func connect() async throws
    
    /// Disconnect from the service
    func disconnect()
    
    /// Start playback
    func play() async
    
    /// Pause playback
    func pause()
    
    /// Seek to specific time (in seconds)
    func seek(to time: TimeInterval)
    
    /// Skip to next track
    func skipToNext() async
    
    /// Skip to previous track
    func skipToPrevious() async
    
    /// Toggle play/pause
    func togglePlayback() async
}

/// Default implementation for toggle
extension MusicProvider {
    func togglePlayback() async {
        if isPlaying {
            pause()
        } else {
            await play()
        }
    }
}
