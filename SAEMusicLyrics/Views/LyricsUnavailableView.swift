//
//  LyricsUnavailableView.swift
//  SAEMusicLyrics
//
//  Placeholder view when lyrics are not available (for Spotify tracks)
//

import SwiftUI

/// Placeholder view for when lyrics are unavailable
struct LyricsUnavailableView: View {
    
    let providerName: String
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "text.quote")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
            
            VStack(spacing: 8) {
                Text("Lyrics Unavailable")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("\(providerName) doesn't provide synced lyrics.\nEnjoy the music!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Visual equalizer bars
            HStack(spacing: 4) {
                ForEach(0..<7) { index in
                    EqualizerBar(delay: Double(index) * 0.1)
                }
            }
            .frame(height: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .onAppear {
            pulseAnimation = true
        }
    }
}

/// Single animated equalizer bar
private struct EqualizerBar: View {
    let delay: Double
    
    @State private var height: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.green.opacity(0.6), .green.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    height = CGFloat.random(in: 12...28)
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        LyricsUnavailableView(providerName: "Spotify")
            .padding()
    }
}
