//
//  TrackInfo.swift
//  SAEMusicLyrics
//
//  Model representing currently playing track metadata
//

import Foundation
import MusicKit

/// Data model for track metadata from Apple Music
struct TrackInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let duration: TimeInterval // in seconds
    let isrc: String?
    
    /// Initialize from MusicKit Song
    init(from song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artist = song.artistName
        self.album = song.albumTitle ?? ""
        self.artworkURL = song.artwork?.url(width: 600, height: 600)
        self.duration = song.duration ?? 0
        self.isrc = song.isrc
    }
    
    /// Initialize from MusicPlayer queue entry
    init?(from entry: MusicPlayer.Queue.Entry) {
        // Try to extract song from the entry's item
        switch entry.item {
        case .song(let song):
            self.init(from: song)
        default:
            // For other types (musicVideo, etc.), try to get basic info
            return nil
        }
    }
    
    /// Manual initializer for previews/testing
    init(id: String, title: String, artist: String, album: String, 
         artworkURL: URL? = nil, duration: TimeInterval, isrc: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.isrc = isrc
    }
    
    /// Duration in milliseconds for web component
    var durationMilliseconds: Int {
        return Int(duration * 1000)
    }
}

