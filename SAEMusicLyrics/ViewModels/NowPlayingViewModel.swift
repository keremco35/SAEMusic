//
//  NowPlayingViewModel.swift
//  SAEMusicLyrics
//
//  ViewModel for the Now Playing screen
//

import Foundation
import SwiftUI
import Combine

/// Main ViewModel coordinating MusicKit and WebView bridge
@MainActor
class NowPlayingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentTrack: TrackInfo?
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var artworkImage: UIImage?
    @Published private(set) var isLoadingArtwork: Bool = false
    
    // MARK: - Services
    
    private let musicService: MusicKitService
    let webViewBridge: WebViewBridge
    
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
    
    init(musicService: MusicKitService = MusicKitService()) {
        self.musicService = musicService
        self.webViewBridge = WebViewBridge()
        
        setupBindings()
        webViewBridge.delegate = self
    }
    
    // MARK: - Setup
    
    /// Bind MusicKitService publishers to ViewModel properties
    private func setupBindings() {
        // Authorization status
        musicService.$authorizationStatus
            .map { $0 == .authorized }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)
        
        // Current track
        musicService.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.handleTrackChange(track)
            }
            .store(in: &cancellables)
        
        // Playback time - send to WebView
        musicService.$playbackTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.playbackTime = time
                // Convert to milliseconds and send to WebView
                self?.webViewBridge.updateCurrentTime(time * 1000)
            }
            .store(in: &cancellables)
        
        // Playing state
        musicService.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPlaying)
    }
    
    // MARK: - Public Methods
    
    /// Initialize the view model (call on appear)
    func initialize() async {
        // Load the lyrics web view
        webViewBridge.loadLyricsBridge()
        
        // Check or request authorization
        musicService.checkAuthorization()
        
        if musicService.authorizationStatus == .notDetermined {
            await musicService.requestAuthorization()
        }
    }
    
    /// Request MusicKit authorization
    func requestAuthorization() async {
        await musicService.requestAuthorization()
    }
    
    /// Toggle play/pause
    func togglePlayback() async {
        await musicService.togglePlayback()
    }
    
    /// Seek to position (0.0 to 1.0)
    func seek(to progress: Double) {
        guard let track = currentTrack else { return }
        let time = progress * track.duration
        musicService.seek(to: time)
    }
    
    /// Skip to next track
    func skipNext() async {
        await musicService.skipToNext()
    }
    
    /// Skip to previous track
    func skipPrevious() async {
        await musicService.skipToPrevious()
    }
    
    // MARK: - Private Methods
    
    /// Handle track change
    private func handleTrackChange(_ track: TrackInfo?) {
        currentTrack = track
        
        if let track = track {
            // Only update if track actually changed
            if track.id != lastTrackId {
                lastTrackId = track.id
                webViewBridge.updateTrackInfo(track)
                loadArtwork(for: track)
            }
        } else {
            lastTrackId = nil
            artworkImage = nil
            webViewBridge.clearLyrics()
        }
    }
    
    /// Load artwork image
    private func loadArtwork(for track: TrackInfo) {
        guard let url = track.artworkURL else {
            artworkImage = nil
            return
        }
        
        isLoadingArtwork = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.artworkImage = image
                        self.isLoadingArtwork = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.artworkImage = nil
                    self.isLoadingArtwork = false
                }
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
        musicService.seek(to: seconds)
        
        // Resume playback after seeking
        Task {
            await musicService.play()
        }
    }
    
    func webViewBridgeDidFinishLoading(_ bridge: WebViewBridge) {
        // If we already have a track, send it to the web view
        if let track = currentTrack {
            bridge.updateTrackInfo(track)
            bridge.updateCurrentTime(playbackTime * 1000)
        }
    }
}
