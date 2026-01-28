//
//  SourceSelectorView.swift
//  SAEMusicLyrics
//
//  Segmented control for switching between Apple Music and Spotify
//

import SwiftUI

/// Modern source selector view with animated selection
struct SourceSelectorView: View {
    @Binding var selectedSource: MusicSource
    let onSourceChange: (MusicSource) -> Void
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MusicSource.allCases) { source in
                sourceButton(source)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private func sourceButton(_ source: MusicSource) -> some View {
        let isSelected = selectedSource == source
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSource = source
                onSourceChange(source)
            }
        } label: {
            HStack(spacing: 6) {
                sourceIcon(source)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(source.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(sourceGradient(source))
                        .matchedGeometryEffect(id: "selector", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sourceIcon(_ source: MusicSource) -> some View {
        switch source {
        case .appleMusic:
            Image(systemName: "applelogo")
        case .spotify:
            // Custom Spotify icon using SF Symbol
            Image(systemName: "waveform.circle.fill")
        }
    }
    
    private func sourceGradient(_ source: MusicSource) -> LinearGradient {
        switch source {
        case .appleMusic:
            return LinearGradient(
                colors: [Color.pink, Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .spotify:
            return LinearGradient(
                colors: [Color(red: 0.11, green: 0.73, blue: 0.33), Color(red: 0.07, green: 0.55, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        SourceSelectorView(
            selectedSource: .constant(.appleMusic),
            onSourceChange: { _ in }
        )
    }
}
