//
//  NowPlayingView.swift
//  SAEMusicLyrics
//
//  Main Now Playing screen with album art, lyrics, and controls
//

import SwiftUI

/// Main Now Playing view with multi-provider support
struct NowPlayingView: View {
    
    @StateObject private var viewModel = NowPlayingViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient with album art blur
                backgroundView
                
                // Main content
                VStack(spacing: 0) {
                    // Source selector at top
                    SourceSelectorView(
                        selectedSource: $viewModel.selectedSource,
                        onSourceChange: { source in
                            viewModel.switchSource(to: source)
                        }
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Content based on source and connection state
                    mainContent(geometry: geometry)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.initialize()
        }
        .onOpenURL { url in
            // Handle Spotify OAuth callback
            if url.scheme == "saemusic-spotify" {
                Task {
                    await viewModel.handleSpotifyCallback(url: url)
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        switch viewModel.selectedSource {
        case .appleMusic:
            appleMusicContent(geometry: geometry)
        case .spotify:
            spotifyContent(geometry: geometry)
        }
    }
    
    // MARK: - Apple Music Content
    
    @ViewBuilder
    private func appleMusicContent(geometry: GeometryProxy) -> some View {
        if viewModel.isConnected {
            if viewModel.currentTrack != nil {
                nowPlayingContent(geometry: geometry)
            } else {
                noTrackView(message: "Play a song in Apple Music\nto see synced lyrics here")
            }
        } else {
            authorizationView
        }
    }
    
    // MARK: - Spotify Content
    
    @ViewBuilder
    private func spotifyContent(geometry: GeometryProxy) -> some View {
        if viewModel.isConnected {
            if viewModel.currentTrack != nil {
                spotifyNowPlayingContent(geometry: geometry)
            } else {
                noTrackView(message: "Play a song in Spotify\nto see track info here")
            }
        } else {
            SpotifyConnectView {
                await viewModel.connectSpotify()
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Album art blur overlay
            if let image = viewModel.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .opacity(0.4)
                    .ignoresSafeArea()
            }
            
            // Dark overlay for readability
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedSource)
    }
    
    private var backgroundColors: [Color] {
        switch viewModel.selectedSource {
        case .appleMusic:
            return [
                Color(red: 0.1, green: 0.1, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ]
        case .spotify:
            return [
                Color(red: 0.05, green: 0.12, blue: 0.08),
                Color(red: 0.02, green: 0.06, blue: 0.04)
            ]
        }
    }
    
    // MARK: - Now Playing Content (Apple Music)
    
    private func nowPlayingContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top section: Album Art + Track Info
            topSection(geometry: geometry)
                .frame(height: geometry.size.height * 0.32)
            
            // Lyrics section
            lyricsSection
                .frame(height: geometry.size.height * 0.40)
            
            // Controls section
            PlaybackControlsView(viewModel: viewModel)
                .frame(height: geometry.size.height * 0.22)
        }
    }
    
    // MARK: - Spotify Now Playing Content
    
    private func spotifyNowPlayingContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Spotify indicator
            SpotifyIndicatorView()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // Top section: Album Art + Track Info
            topSection(geometry: geometry)
                .frame(height: geometry.size.height * 0.30)
            
            // Lyrics unavailable section
            LyricsUnavailableView(providerName: viewModel.currentProviderName)
                .padding(.horizontal, 16)
                .frame(height: geometry.size.height * 0.38)
            
            // Controls section
            PlaybackControlsView(viewModel: viewModel)
                .frame(height: geometry.size.height * 0.22)
        }
    }
    
    // MARK: - Top Section
    
    private func topSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Album Artwork
            albumArtwork(size: min(geometry.size.width * 0.45, 180))
            
            // Track Info
            trackInfo
            
            Spacer()
        }
    }
    
    private func albumArtwork(size: CGFloat) -> some View {
        Group {
            if let image = viewModel.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if viewModel.isLoadingArtwork {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
    
    private var trackInfo: some View {
        VStack(spacing: 4) {
            Text(viewModel.currentTrack?.title ?? "Unknown")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(viewModel.currentTrack?.artist ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Lyrics Section
    
    private var lyricsSection: some View {
        LyricsWebView(bridge: viewModel.webViewBridge)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }
    
    // MARK: - No Track View
    
    private func noTrackView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Track Playing")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Authorization View (Apple Music)
    
    private var authorizationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Apple Music Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("This app needs access to Apple Music\nto display lyrics for the currently playing song")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await viewModel.initialize()
                }
            } label: {
                Text("Grant Access")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NowPlayingView()
}
