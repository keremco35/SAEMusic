//
//  PlaybackControlsView.swift
//  SAEMusicLyrics
//
//  Playback control buttons and progress slider
//

import SwiftUI

/// Playback controls with play/pause, skip, and progress slider
struct PlaybackControlsView: View {
    
    @ObservedObject var viewModel: NowPlayingViewModel
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            progressBar
            
            // Time Labels
            timeLabels
            
            // Control Buttons
            controlButtons
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                
                // Progress fill
                Capsule()
                    .fill(Color.white)
                    .frame(width: progressWidth(for: geometry.size.width), height: 4)
                
                // Drag handle (visible when dragging)
                if isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: progressWidth(for: geometry.size.width) - 6)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = progress
                    }
                    .onEnded { value in
                        isDragging = false
                        let progress = min(max(value.location.x / geometry.size.width, 0), 1)
                        viewModel.seek(to: progress)
                    }
            )
        }
        .frame(height: 20)
    }
    
    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        let progress = isDragging ? dragProgress : viewModel.playbackProgress
        return totalWidth * CGFloat(progress)
    }
    
    // MARK: - Time Labels
    
    private var timeLabels: some View {
        HStack {
            Text(viewModel.currentTimeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            Spacer()
            
            Text(viewModel.durationFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 48) {
            // Previous
            Button {
                Task {
                    await viewModel.skipPrevious()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            // Play/Pause
            Button {
                Task {
                    await viewModel.togglePlayback()
                }
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
            
            // Next
            Button {
                Task {
                    await viewModel.skipNext()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PlaybackControlsView(viewModel: NowPlayingViewModel())
    }
}
