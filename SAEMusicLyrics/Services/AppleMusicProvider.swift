//
//  AppleMusicProvider.swift
//  SAEMusicLyrics
//
//  Apple Music provider implementing MusicProvider protocol
//

import Foundation
import MusicKit
import MediaPlayer
import Combine
import QuartzCore

/// Apple Music provider using MusicKit
@MainActor
class AppleMusicProvider: ObservableObject, MusicProvider {
    
    // MARK: - Published Properties (MusicProvider)
    
    @Published private(set) var currentTrack: Track?
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isConnected: Bool = false
    
    // MARK: - MusicProvider Properties
    
    let supportsLyrics: Bool = true
    let providerName: String = "Apple Music"
    let source: MusicSource = .appleMusic
    
    // MARK: - Private Properties
    
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    private let player = SystemMusicPlayer.shared
    private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - MusicProvider Methods
    
    /// Connect/authorize with Apple Music
    func connect() async throws {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        
        if status == .authorized {
            isConnected = true
            await updateCurrentTrack()
            startPlaybackObservation()
        } else {
            isConnected = false
            throw AppleMusicError.authorizationDenied
        }
    }
    
    /// Disconnect (stop observing)
    func disconnect() {
        stopPlaybackObservation()
        isConnected = false
        currentTrack = nil
    }
    
    /// Start playback
    func play() async {
        try? await player.play()
    }
    
    /// Pause playback
    func pause() {
        player.pause()
    }
    
    /// Seek to specific time (in seconds)
    func seek(to time: TimeInterval) {
        player.playbackTime = time
        playbackTime = time
    }
    
    /// Skip to next track
    func skipToNext() async {
        try? await player.skipToNextEntry()
    }
    
    /// Skip to previous track
    func skipToPrevious() async {
        try? await player.skipToPreviousEntry()
    }
    
    // MARK: - Public Methods
    
    /// Check current authorization status and initialize if authorized
    func checkAuthorization() {
        authorizationStatus = MusicAuthorization.currentStatus
        
        if authorizationStatus == .authorized {
            isConnected = true
            Task {
                await updateCurrentTrack()
            }
            startPlaybackObservation()
        }
    }
    
    // MARK: - Playback Observation
    
    /// Setup NotificationCenter observers for playback changes
    private func setupObservers() {
        // Observe now playing item changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentTrack()
                }
            }
            .store(in: &cancellables)
        
        // Observe playback state changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
    }
    
    /// Start high-frequency playback time observation (60fps)
    private func startPlaybackObservation() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
        
        // Begin generating playback notifications
        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    /// Stop playback observation
    private func stopPlaybackObservation() {
        displayLink?.invalidate()
        displayLink = nil
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }
    
    /// Called by CADisplayLink at 60fps to update playback time
    @objc private func updatePlaybackTime() {
        guard isPlaying else { return }
        playbackTime = player.playbackTime
    }
    
    /// Update playback state (playing/paused)
    private func updatePlaybackState() {
        let state = player.state.playbackStatus
        isPlaying = (state == .playing)
        
        // Update time immediately when state changes
        playbackTime = player.playbackTime
    }
    
    // MARK: - Track Information
    
    /// Fetch and update current track information
    private func updateCurrentTrack() async {
        guard let entry = player.queue.currentEntry else {
            currentTrack = nil
            return
        }
        
        currentTrack = Track(from: entry)
        updatePlaybackState()
    }
}

// MARK: - Errors

enum AppleMusicError: Error, LocalizedError {
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music access was denied. Please enable in Settings."
        }
    }
}
