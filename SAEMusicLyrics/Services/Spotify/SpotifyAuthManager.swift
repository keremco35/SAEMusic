//
//  SpotifyAuthManager.swift
//  SAEMusicLyrics
//
//  Handles Spotify OAuth 2.0 authentication flow
//

import Foundation
import UIKit

/// Manages Spotify OAuth authentication
@MainActor
class SpotifyAuthManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published var authError: SpotifyAuthError?
    
    // MARK: - Properties
    
    private let keychain = KeychainHelper.shared
    private var authCompletion: ((Result<String, SpotifyAuthError>) -> Void)?
    
    /// Current access token
    var accessToken: String? {
        keychain.read(SpotifyConfig.KeychainKeys.accessToken)
    }
    
    // MARK: - Singleton
    
    static let shared = SpotifyAuthManager()
    
    private init() {
        checkExistingSession()
    }
    
    // MARK: - Public Methods
    
    /// Start OAuth authentication flow
    func authenticate() async throws {
        isAuthenticating = true
        authError = nil
        
        defer { isAuthenticating = false }
        
        // Build authorization URL
        guard let authURL = buildAuthorizationURL() else {
            throw SpotifyAuthError.invalidAuthURL
        }
        
        // Open Spotify for authentication
        guard await UIApplication.shared.open(authURL) else {
            throw SpotifyAuthError.cannotOpenSpotify
        }
        
        // Wait for callback - handled by handleCallback
        // The actual token exchange happens when the URL callback is received
    }
    
    /// Handle OAuth callback URL
    func handleCallback(url: URL) async throws {
        guard url.scheme == "saemusic-spotify" else { return }
        
        // Extract authorization code from URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            
            // Check for error
            if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
                throw SpotifyAuthError.authorizationDenied(error)
            }
            throw SpotifyAuthError.invalidCallback
        }
        
        // Exchange code for access token
        try await exchangeCodeForToken(code)
    }
    
    /// Sign out and clear tokens
    func signOut() {
        keychain.delete(SpotifyConfig.KeychainKeys.accessToken)
        keychain.delete(SpotifyConfig.KeychainKeys.refreshToken)
        keychain.delete(SpotifyConfig.KeychainKeys.tokenExpiration)
        isAuthenticated = false
    }
    
    /// Refresh access token if needed
    func refreshTokenIfNeeded() async throws {
        guard let expirationDate = keychain.readDate(SpotifyConfig.KeychainKeys.tokenExpiration),
              Date() >= expirationDate.addingTimeInterval(-300) else {
            return // Token still valid
        }
        
        guard let refreshToken = keychain.read(SpotifyConfig.KeychainKeys.refreshToken) else {
            throw SpotifyAuthError.noRefreshToken
        }
        
        try await refreshAccessToken(using: refreshToken)
    }
    
    // MARK: - Private Methods
    
    /// Check for existing session on startup
    private func checkExistingSession() {
        if let _ = keychain.read(SpotifyConfig.KeychainKeys.accessToken) {
            isAuthenticated = true
        }
    }
    
    /// Build OAuth authorization URL
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURL.absoluteString),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        
        return components?.url
    }
    
    /// Exchange authorization code for access token
    private func exchangeCodeForToken(_ code: String) async throws {
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURL.absoluteString,
            "client_id": SpotifyConfig.clientID
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        saveTokens(tokenResponse)
        isAuthenticated = true
    }
    
    /// Refresh access token
    private func refreshAccessToken(using refreshToken: String) async throws {
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": SpotifyConfig.clientID
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        saveTokens(tokenResponse)
    }
    
    /// Save tokens to Keychain
    private func saveTokens(_ response: SpotifyTokenResponse) {
        _ = keychain.save(response.accessToken, forKey: SpotifyConfig.KeychainKeys.accessToken)
        
        if let refreshToken = response.refreshToken {
            _ = keychain.save(refreshToken, forKey: SpotifyConfig.KeychainKeys.refreshToken)
        }
        
        let expirationDate = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        _ = keychain.save(date: expirationDate, forKey: SpotifyConfig.KeychainKeys.tokenExpiration)
    }
}

// MARK: - Token Response

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Errors

enum SpotifyAuthError: Error, LocalizedError {
    case invalidAuthURL
    case cannotOpenSpotify
    case invalidCallback
    case authorizationDenied(String)
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .invalidAuthURL:
            return "Failed to build authorization URL"
        case .cannotOpenSpotify:
            return "Cannot open Spotify. Is it installed?"
        case .invalidCallback:
            return "Invalid callback URL"
        case .authorizationDenied(let reason):
            return "Authorization denied: \(reason)"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .noRefreshToken:
            return "No refresh token available"
        }
    }
}
