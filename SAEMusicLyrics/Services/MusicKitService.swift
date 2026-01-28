//
//  MusicKitService.swift
//  SAEMusicLyrics
//
//  Service for interacting with iOS MusicKit framework
//

import Foundation
import MusicKit
import MediaPlayer
import Combine
import QuartzCore

/// Service class handling all MusicKit interactions
@MainActor
class MusicKitService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published private(set) var currentTrack: TrackInfo?
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    
    // MARK: - Private Properties
    
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    private let player = SystemMusicPlayer.shared
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - Authorization
    
    /// Request MusicKit authorization from user
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        
        if status == .authorized {
            await updateCurrentTrack()
            startPlaybackObservation()
        }
    }
    
    /// Check current authorization status
    func checkAuthorization() {
        authorizationStatus = MusicAuthorization.currentStatus
        
        if authorizationStatus == .authorized {
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
        
        currentTrack = TrackInfo(from: entry)
        updatePlaybackState()
    }
    
    // MARK: - Playback Controls
    
    /// Toggle play/pause
    func togglePlayback() async {
        if isPlaying {
            player.pause()
        } else {
            try? await player.play()
        }
    }
    
    /// Play
    func play() async {
        try? await player.play()
    }
    
    /// Pause
    func pause() {
        player.pause()
    }
    
    /// Seek to specific time (in seconds)
    func seek(to time: TimeInterval) {
        player.playbackTime = time
        playbackTime = time
    }
    
    /// Seek to specific time (in milliseconds)
    func seekMilliseconds(_ ms: Double) {
        let seconds = ms / 1000.0
        seek(to: seconds)
    }
    
    /// Skip to next track
    func skipToNext() async {
        try? await player.skipToNextEntry()
    }
    
    /// Skip to previous track
    func skipToPrevious() async {
        try? await player.skipToPreviousEntry()
    }
}
