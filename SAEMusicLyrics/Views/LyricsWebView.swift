//
//  LyricsWebView.swift
//  SAEMusicLyrics
//
//  UIViewRepresentable wrapper for WKWebView displaying lyrics
//

import SwiftUI
import WebKit

/// SwiftUI wrapper for WKWebView displaying the am-lyrics component
struct LyricsWebView: UIViewRepresentable {
    
    @ObservedObject var bridge: WebViewBridge
    
    func makeUIView(context: Context) -> WKWebView {
        return bridge.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates are handled through the bridge
    }
}

// MARK: - Preview

#Preview {
    LyricsWebView(bridge: WebViewBridge())
        .background(Color.black)
}
