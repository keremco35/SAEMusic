//
//  SpotifyProvider.swift
//  SAEMusicLyrics
//
//  Spotify provider implementing MusicProvider protocol using Spotify Web API
//

import Foundation
import Combine
import UIKit

/// Spotify provider using Spotify Web API for playback control
@MainActor
class SpotifyProvider: ObservableObject, MusicProvider {
    
    // MARK: - Published Properties (MusicProvider)
    
    @Published private(set) var currentTrack: Track?
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isConnected: Bool = false
    
    // MARK: - MusicProvider Properties
    
    let supportsLyrics: Bool = false
    let providerName: String = "Spotify"
    let source: MusicSource = .spotify
    
    // MARK: - Private Properties
    
    private let authManager = SpotifyAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    // MARK: - MusicProvider Methods
    
    /// Connect to Spotify (authenticate)
    func connect() async throws {
        try await authManager.authenticate()
        isConnected = authManager.isAuthenticated
        
        if isConnected {
            startPolling()
            await fetchCurrentPlayback()
        }
    }
    
    /// Disconnect from Spotify
    func disconnect() {
        stopPolling()
        authManager.signOut()
        isConnected = false
        currentTrack = nil
        isPlaying = false
    }
    
    /// Start playback
    func play() async {
        await sendPlaybackCommand(endpoint: "play", method: "PUT")
    }
    
    /// Pause playback
    func pause() {
        Task {
            await sendPlaybackCommand(endpoint: "pause", method: "PUT")
        }
    }
    
    /// Seek to specific time (in seconds)
    func seek(to time: TimeInterval) {
        let ms = Int(time * 1000)
        Task {
            await sendPlaybackCommand(endpoint: "seek?position_ms=\(ms)", method: "PUT")
        }
    }
    
    /// Skip to next track
    func skipToNext() async {
        await sendPlaybackCommand(endpoint: "next", method: "POST")
    }
    
    /// Skip to previous track
    func skipToPrevious() async {
        await sendPlaybackCommand(endpoint: "previous", method: "POST")
    }
    
    // MARK: - Public Methods
    
    /// Check if already authenticated and connect
    func checkExistingSession() {
        if authManager.isAuthenticated {
            isConnected = true
            startPolling()
            Task {
                await fetchCurrentPlayback()
            }
        }
    }
    
    /// Handle OAuth callback
    func handleCallback(url: URL) async throws {
        try await authManager.handleCallback(url: url)
        isConnected = authManager.isAuthenticated
        
        if isConnected {
            startPolling()
            await fetchCurrentPlayback()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe auth state changes
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authenticated in
                self?.isConnected = authenticated
            }
            .store(in: &cancellables)
    }
    
    /// Start polling for playback state (every 1 second)
    private func startPolling() {
        stopPolling()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchCurrentPlayback()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    /// Fetch current playback state from Spotify API
    private func fetchCurrentPlayback() async {
        guard let accessToken = authManager.accessToken else { return }
        
        // Refresh token if needed
        try? await authManager.refreshTokenIfNeeded()
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 204 {
                // No content - nothing playing
                currentTrack = nil
                isPlaying = false
                playbackTime = 0
                return
            }
            
            guard httpResponse.statusCode == 200 else { return }
            
            let playback = try JSONDecoder().decode(SpotifyPlaybackResponse.self, from: data)
            updateFromPlayback(playback)
            
        } catch {
            print("Failed to fetch Spotify playback: \(error)")
        }
    }
    
    /// Update state from playback response
    private func updateFromPlayback(_ response: SpotifyPlaybackResponse) {
        isPlaying = response.isPlaying
        playbackTime = TimeInterval(response.progressMs) / 1000.0
        
        guard let item = response.item else {
            currentTrack = nil
            return
        }
        
        // Check if track changed
        if currentTrack?.id != item.id {
            let artworkURL = item.album.images.first.map { URL(string: $0.url) } ?? nil
            
            currentTrack = Track(
                spotifyId: item.id,
                title: item.name,
                artist: item.artists.map { $0.name }.joined(separator: ", "),
                album: item.album.name,
                artworkURL: artworkURL,
                duration: TimeInterval(item.durationMs) / 1000.0
            )
        }
    }
    
    /// Send playback control command
    private func sendPlaybackCommand(endpoint: String, method: String) async {
        guard let accessToken = authManager.accessToken else { return }
        
        try? await authManager.refreshTokenIfNeeded()
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            _ = try await URLSession.shared.data(for: request)
            // Fetch updated state
            await fetchCurrentPlayback()
        } catch {
            print("Failed to send Spotify command: \(error)")
        }
    }
}

// MARK: - Spotify API Response Models

struct SpotifyPlaybackResponse: Decodable {
    let isPlaying: Bool
    let progressMs: Int
    let item: SpotifyTrack?
    
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case progressMs = "progress_ms"
        case item
    }
}

struct SpotifyTrack: Decodable {
    let id: String
    let name: String
    let durationMs: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
        case durationMs = "duration_ms"
    }
}

struct SpotifyArtist: Decodable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Decodable {
    let id: String
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}
