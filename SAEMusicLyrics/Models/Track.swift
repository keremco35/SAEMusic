//
//  Track.swift
//  SAEMusicLyrics
//
//  Provider-agnostic track model
//

import Foundation
import MusicKit

/// Provider-agnostic data model for track metadata
struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let duration: TimeInterval // in seconds
    let isrc: String?
    let source: MusicSource
    
    /// Duration in milliseconds for web component
    var durationMilliseconds: Int {
        return Int(duration * 1000)
    }
    
    /// Initialize from MusicKit Song (Apple Music)
    init(from song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artist = song.artistName
        self.album = song.albumTitle ?? ""
        self.artworkURL = song.artwork?.url(width: 600, height: 600)
        self.duration = song.duration ?? 0
        self.isrc = song.isrc
        self.source = .appleMusic
    }
    
    /// Initialize from MusicPlayer queue entry (Apple Music)
    init?(from entry: MusicPlayer.Queue.Entry) {
        switch entry.item {
        case .song(let song):
            self.init(from: song)
        default:
            return nil
        }
    }
    
    /// Initialize for Spotify track
    init(spotifyId: String, title: String, artist: String, album: String,
         artworkURL: URL?, duration: TimeInterval) {
        self.id = spotifyId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.isrc = nil
        self.source = .spotify
    }
    
    /// Manual initializer for previews/testing
    init(id: String, title: String, artist: String, album: String,
         artworkURL: URL? = nil, duration: TimeInterval, isrc: String? = nil,
         source: MusicSource = .appleMusic) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.isrc = isrc
        self.source = source
    }
}

// MARK: - Backward Compatibility with TrackInfo

extension Track {
    /// Create Track from legacy TrackInfo
    init(from trackInfo: TrackInfo) {
        self.id = trackInfo.id
        self.title = trackInfo.title
        self.artist = trackInfo.artist
        self.album = trackInfo.album
        self.artworkURL = trackInfo.artworkURL
        self.duration = trackInfo.duration
        self.isrc = trackInfo.isrc
        self.source = .appleMusic
    }
    
    /// Convert to legacy TrackInfo for WebViewBridge compatibility
    func toTrackInfo() -> TrackInfo {
        return TrackInfo(
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL,
            duration: duration,
            isrc: isrc
        )
    }
}
