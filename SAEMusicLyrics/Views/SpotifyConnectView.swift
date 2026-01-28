//
//  SpotifyConnectView.swift
//  SAEMusicLyrics
//
//  View for connecting to Spotify
//

import SwiftUI

/// View prompting user to connect to Spotify
struct SpotifyConnectView: View {
    
    let onConnect: () async -> Void
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Spotify brand green color
    private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
    
    var body: some View {
        VStack(spacing: 28) {
            // Spotify icon
            ZStack {
                Circle()
                    .fill(spotifyGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(spotifyGreen)
            }
            
            VStack(spacing: 8) {
                Text("Connect to Spotify")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Link your Spotify account to control playback\nand see what's playing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Connect button
            Button {
                Task {
                    isConnecting = true
                    await onConnect()
                    isConnecting = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isConnecting ? "Connecting..." : "Connect with Spotify")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(width: 220, height: 50)
                .background(
                    Capsule()
                        .fill(spotifyGreen)
                        .shadow(color: spotifyGreen.opacity(0.4), radius: 10, y: 5)
                )
            }
            .disabled(isConnecting)
            
            // Info text
            Text("You'll be redirected to Spotify to authorize")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .alert("Connection Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SpotifyConnectView(onConnect: {})
    }
}
