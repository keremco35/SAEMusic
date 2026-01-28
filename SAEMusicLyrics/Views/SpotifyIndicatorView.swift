//
//  SpotifyIndicatorView.swift
//  SAEMusicLyrics
//
//  "Playing via Spotify" indicator banner
//

import SwiftUI

/// Indicator showing that playback is controlled via Spotify
struct SpotifyIndicatorView: View {
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated bars icon
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(spotifyGreen)
                        .frame(width: 3, height: isAnimating ? CGFloat.random(in: 8...14) : 6)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 14)
            
            Text("Playing via Spotify")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            // Spotify logo placeholder
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(spotifyGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(spotifyGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
    
    private var spotifyGreen: Color {
        Color(red: 0.11, green: 0.73, blue: 0.33)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.black, .gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        SpotifyIndicatorView()
            .padding()
    }
}
