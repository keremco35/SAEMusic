//
//  WebViewBridge.swift
//  SAEMusicLyrics
//
//  Bridge for JavaScript <-> Swift communication via WKWebView
//

import Foundation
import WebKit

/// Delegate protocol for receiving events from the web view
protocol WebViewBridgeDelegate: AnyObject {
    func webViewBridge(_ bridge: WebViewBridge, didRequestSeekTo milliseconds: Double)
    func webViewBridgeDidFinishLoading(_ bridge: WebViewBridge)
}

/// Bridge class for WKWebView JavaScript communication
class WebViewBridge: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: WebViewBridgeDelegate?
    private(set) var webView: WKWebView!
    
    @Published private(set) var isLoaded = false
    @Published private(set) var loadingError: String?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupWebView()
    }
    
    /// Configure WKWebView with message handlers
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        
        // Allow inline media playback
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add message handler for lyrics events
        let contentController = WKUserContentController()
        contentController.add(self, name: "lyricsHandler")
        configuration.userContentController = contentController
        
        // Create web view
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Disable scrolling (lyrics component handles its own scroll)
        webView.scrollView.isScrollEnabled = false
    }
    
    // MARK: - Load HTML
    
    /// Load the lyrics bridge HTML
    func loadLyricsBridge() {
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    /// Generate HTML content with am-lyrics component
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script type="module">
                import 'https://cdn.jsdelivr.net/npm/@uimaxbai/am-lyrics@latest/dist/src/am-lyrics.min.js';
            </script>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                html, body {
                    width: 100%;
                    height: 100%;
                    background: transparent;
                    overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif;
                }
                
                am-lyrics {
                    width: 100%;
                    height: 100%;
                    display: block;
                    --am-lyrics-highlight-color: var(--highlight-color, #ffffff);
                    --hover-background-color: rgba(255, 255, 255, 0.1);
                }
                
                /* Dark mode styling */
                @media (prefers-color-scheme: dark) {
                    am-lyrics {
                        --am-lyrics-highlight-color: #ffffff;
                        --hover-background-color: rgba(255, 255, 255, 0.08);
                    }
                }
                
                /* Loading state */
                .loading-message {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100%;
                    color: rgba(255, 255, 255, 0.5);
                    font-size: 16px;
                }
                
                /* No lyrics state */
                .no-lyrics {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100%;
                    color: rgba(255, 255, 255, 0.4);
                    font-size: 18px;
                    text-align: center;
                    padding: 20px;
                }
            </style>
        </head>
        <body>
            <div id="lyrics-container">
                <am-lyrics
                    id="am-lyrics"
                    song-title=""
                    song-artist=""
                    song-album=""
                    song-duration="0"
                    query=""
                    current-time="0"
                    highlight-color="#ffffff"
                    hover-background-color="rgba(255, 255, 255, 0.1)"
                    font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif"
                    autoscroll
                    interpolate
                ></am-lyrics>
            </div>
            
            <script>
                // Get reference to lyrics component
                const amLyrics = document.getElementById('am-lyrics');
                
                // Listen for line-click events
                if (amLyrics) {
                    amLyrics.addEventListener('line-click', (event) => {
                        // Send seek request to Swift
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lyricsHandler) {
                            window.webkit.messageHandlers.lyricsHandler.postMessage({
                                type: 'seek',
                                timestamp: event.detail.timestamp
                            });
                        }
                    });
                }
                
                // Function called from Swift to update current time
                function updateCurrentTime(milliseconds) {
                    if (amLyrics) {
                        amLyrics.currentTime = milliseconds;
                    }
                }
                
                // Function called from Swift to update track info
                function updateTrackInfo(title, artist, album, durationMs, musicId, isrc) {
                    if (amLyrics) {
                        amLyrics.songTitle = title || '';
                        amLyrics.songArtist = artist || '';
                        amLyrics.songAlbum = album || '';
                        amLyrics.songDuration = durationMs || 0;
                        amLyrics.query = title && artist ? `${title} ${artist}` : (title || '');
                        amLyrics.musicId = musicId || '';
                        amLyrics.isrc = isrc || '';
                        
                        // Reset current time when track changes
                        amLyrics.currentTime = 0;
                    }
                }
                
                // Function to clear lyrics (e.g., when no track is playing)
                function clearLyrics() {
                    if (amLyrics) {
                        amLyrics.songTitle = '';
                        amLyrics.songArtist = '';
                        amLyrics.query = '';
                        amLyrics.musicId = '';
                        amLyrics.currentTime = 0;
                        amLyrics.duration = -1; // Reset/stop playback
                    }
                }
                
                // Notify Swift that the page is loaded
                document.addEventListener('DOMContentLoaded', () => {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lyricsHandler) {
                        window.webkit.messageHandlers.lyricsHandler.postMessage({
                            type: 'loaded'
                        });
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - JavaScript Communication (Swift → JS)
    
    /// Update current playback time in the web component
    func updateCurrentTime(_ milliseconds: Double) {
        guard isLoaded else { return }
        let js = "updateCurrentTime(\(milliseconds));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    /// Update track information in the web component
    func updateTrackInfo(_ track: TrackInfo) {
        guard isLoaded else { return }
        
        // Escape strings for JavaScript
        let title = escapeJS(track.title)
        let artist = escapeJS(track.artist)
        let album = escapeJS(track.album)
        let isrc = escapeJS(track.isrc ?? "")
        
        let js = "updateTrackInfo('\(title)', '\(artist)', '\(album)', \(track.durationMilliseconds), '\(track.id)', '\(isrc)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    /// Clear lyrics display
    func clearLyrics() {
        guard isLoaded else { return }
        webView.evaluateJavaScript("clearLyrics();", completionHandler: nil)
    }
    
    /// Escape string for JavaScript
    private func escapeJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - WKNavigationDelegate

extension WebViewBridge: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Loaded state is set via message handler when DOM is ready
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingError = error.localizedDescription
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadingError = error.localizedDescription
    }
}

// MARK: - WKScriptMessageHandler

extension WebViewBridge: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, 
                               didReceive message: WKScriptMessage) {
        guard message.name == "lyricsHandler",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }
        
        switch type {
        case "loaded":
            DispatchQueue.main.async {
                self.isLoaded = true
                self.delegate?.webViewBridgeDidFinishLoading(self)
            }
            
        case "seek":
            if let timestamp = body["timestamp"] as? Double {
                DispatchQueue.main.async {
                    self.delegate?.webViewBridge(self, didRequestSeekTo: timestamp)
                }
            }
            
        default:
            break
        }
    }
}
