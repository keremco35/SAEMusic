//
//  NowPlayingViewModel.swift
//  SAEMusicLyrics
//
//  ViewModel for the Now Playing screen with multi-provider support
//

import Foundation
import SwiftUI
import Combine

/// Main ViewModel coordinating music providers and WebView bridge
@MainActor
final class NowPlayingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentTrack: Track?
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var artworkImage: UIImage?
    @Published private(set) var isLoadingArtwork: Bool = false
    @Published var selectedSource: MusicSource = .appleMusic
    
    /// Whether lyrics are available for the current provider
    var lyricsAvailable: Bool {
        switch selectedSource {
        case .appleMusic:
            return appleMusicProvider.supportsLyrics
        case .spotify:
            return spotifyProvider.supportsLyrics
        }
    }
    
    /// Current provider name for display
    var currentProviderName: String {
        switch selectedSource {
        case .appleMusic:
            return appleMusicProvider.providerName
        case .spotify:
            return spotifyProvider.providerName
        }
    }
    
    // MARK: - Providers
    
    private let appleMusicProvider = AppleMusicProvider()
    private let spotifyProvider = SpotifyProvider()
    
    // MARK: - Services
    
    let webViewBridge = WebViewBridge()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var lastTrackId: String?
    
    // MARK: - Computed Properties
    
    /// Playback progress (0.0 to 1.0)
    var playbackProgress: Double {
        guard let track = currentTrack, track.duration > 0 else { return 0 }
        return min(playbackTime / track.duration, 1.0)
    }
    
    /// Formatted current time string (MM:SS)
    var currentTimeFormatted: String {
        formatTime(playbackTime)
    }
    
    /// Formatted duration string (MM:SS)
    var durationFormatted: String {
        guard let track = currentTrack else { return "0:00" }
        return formatTime(track.duration)
    }
    
    // MARK: - Initialization
    
    init() {
        webViewBridge.delegate = self
        setupProviderObservers()
    }
    
    // MARK: - Setup
    
    /// Setup observers for both providers
    private func setupProviderObservers() {
        // Apple Music provider observers
        appleMusicProvider.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                guard self?.selectedSource == .appleMusic else { return }
                self?.handleTrackChange(track)
            }
            .store(in: &cancellables)
        
        appleMusicProvider.$playbackTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard self?.selectedSource == .appleMusic else { return }
                self?.playbackTime = time
                self?.webViewBridge.updateCurrentTime(time * 1000)
            }
            .store(in: &cancellables)
        
        appleMusicProvider.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard self?.selectedSource == .appleMusic else { return }
                self?.isPlaying = playing
            }
            .store(in: &cancellables)
        
        appleMusicProvider.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard self?.selectedSource == .appleMusic else { return }
                self?.isConnected = connected
            }
            .store(in: &cancellables)
        
        // Spotify provider observers
        spotifyProvider.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                guard self?.selectedSource == .spotify else { return }
                self?.handleTrackChange(track)
            }
            .store(in: &cancellables)
        
        spotifyProvider.$playbackTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard self?.selectedSource == .spotify else { return }
                self?.playbackTime = time
                // Don't update web view for Spotify (no lyrics)
            }
            .store(in: &cancellables)
        
        spotifyProvider.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard self?.selectedSource == .spotify else { return }
                self?.isPlaying = playing
            }
            .store(in: &cancellables)
        
        spotifyProvider.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard self?.selectedSource == .spotify else { return }
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Initialize the view model (call on appear)
    func initialize() async {
        // Load the lyrics web view
        webViewBridge.loadLyricsBridge()
        
        // Initialize Apple Music by default
        appleMusicProvider.checkAuthorization()
        
        if !appleMusicProvider.isConnected {
            try? await appleMusicProvider.connect()
        }
        
        // Check if Spotify has existing session
        spotifyProvider.checkExistingSession()
        
        // Update connection state for current provider
        updateConnectionState()
    }
    
    /// Switch to a different music source
    func switchSource(to source: MusicSource) {
        guard source != selectedSource else { return }
        
        // Clear current state
        currentTrack = nil
        artworkImage = nil
        playbackTime = 0
        isPlaying = false
        webViewBridge.clearLyrics()
        lastTrackId = nil
        
        selectedSource = source
        updateConnectionState()
        
        // Sync with new provider's current state
        switch source {
        case .appleMusic:
            currentTrack = appleMusicProvider.currentTrack
            playbackTime = appleMusicProvider.playbackTime
            isPlaying = appleMusicProvider.isPlaying
            if let track = currentTrack {
                handleTrackChange(track)
            }
        case .spotify:
            currentTrack = spotifyProvider.currentTrack
            playbackTime = spotifyProvider.playbackTime
            isPlaying = spotifyProvider.isPlaying
            if let track = currentTrack {
                handleTrackChange(track)
            }
        }
    }
    
    /// Connect to Spotify
    func connectSpotify() async {
        do {
            try await spotifyProvider.connect()
            updateConnectionState()
        } catch {
            print("Spotify connection failed: \(error)")
        }
    }
    
    /// Handle Spotify OAuth callback
    func handleSpotifyCallback(url: URL) async {
        do {
            try await spotifyProvider.handleCallback(url: url)
            updateConnectionState()
        } catch {
            print("Spotify callback failed: \(error)")
        }
    }
    
    /// Toggle play/pause for current provider
    func togglePlayback() async {
        switch selectedSource {
        case .appleMusic:
            await appleMusicProvider.togglePlayback()
        case .spotify:
            await spotifyProvider.togglePlayback()
        }
    }
    
    /// Seek to position (0.0 to 1.0)
    func seek(to progress: Double) {
        guard let track = currentTrack else { return }
        let time = progress * track.duration
        
        switch selectedSource {
        case .appleMusic:
            appleMusicProvider.seek(to: time)
        case .spotify:
            spotifyProvider.seek(to: time)
        }
    }
    
    /// Skip to next track
    func skipNext() async {
        switch selectedSource {
        case .appleMusic:
            await appleMusicProvider.skipToNext()
        case .spotify:
            await spotifyProvider.skipToNext()
        }
    }
    
    /// Skip to previous track
    func skipPrevious() async {
        switch selectedSource {
        case .appleMusic:
            await appleMusicProvider.skipToPrevious()
        case .spotify:
            await spotifyProvider.skipToPrevious()
        }
    }
    
    // MARK: - Private Methods
    
    /// Update connection state for current provider
    private func updateConnectionState() {
        switch selectedSource {
        case .appleMusic:
            isConnected = appleMusicProvider.isConnected
        case .spotify:
            isConnected = spotifyProvider.isConnected
        }
    }
    
    /// Handle track change
    private func handleTrackChange(_ track: Track?) {
        currentTrack = track
        
        if let track = track {
            // Only update if track actually changed
            if track.id != lastTrackId {
                lastTrackId = track.id
                
                // Only update lyrics for Apple Music
                if selectedSource == .appleMusic {
                    webViewBridge.updateTrackInfo(track.toTrackInfo())
                }
                
                loadArtwork(for: track)
            }
        } else {
            lastTrackId = nil
            artworkImage = nil
            webViewBridge.clearLyrics()
        }
    }
    
    /// Load artwork image
    private func loadArtwork(for track: Track) {
        guard let url = track.artworkURL else {
            artworkImage = nil
            return
        }
        
        isLoadingArtwork = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.artworkImage = image
                    self.isLoadingArtwork = false
                }
            } catch {
                self.artworkImage = nil
                self.isLoadingArtwork = false
            }
        }
    }
    
    /// Format time interval as MM:SS
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - WebViewBridgeDelegate

extension NowPlayingViewModel: WebViewBridgeDelegate {
    
    func webViewBridge(_ bridge: WebViewBridge, didRequestSeekTo milliseconds: Double) {
        let seconds = milliseconds / 1000.0
        
        switch selectedSource {
        case .appleMusic:
            appleMusicProvider.seek(to: seconds)
            // Resume playback after seeking
            Task {
                await appleMusicProvider.play()
            }
        case .spotify:
            spotifyProvider.seek(to: seconds)
        }
    }
    
    func webViewBridgeDidFinishLoading(_ bridge: WebViewBridge) {
        // If we already have a track from Apple Music, send it to the web view
        if selectedSource == .appleMusic, let track = currentTrack {
            bridge.updateTrackInfo(track.toTrackInfo())
            bridge.updateCurrentTime(playbackTime * 1000)
        }
    }
}
