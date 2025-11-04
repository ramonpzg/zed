import Foundation
import AuthenticationServices

public actor OAuthClient {
    private let clientId: String
    private let redirectURI: String
    private let baseURL: URL

    public init(
        clientId: String = "zed-mobile",
        redirectURI: String = "zedmobile://oauth/callback",
        baseURL: URL = URL(string: "https://zed.dev")!
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.baseURL = baseURL
    }

    public func startAuthentication() -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/oauth/github"),
            resolvingAgainstBaseURL: true
        )!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "user:email")
        ]

        return components.url!
    }

    public func handleCallback(url: URL) async throws -> ZedCredentials {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.invalidCallback
        }

        return try await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async throws -> ZedCredentials {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("/api/oauth/token")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        return ZedCredentials(
            userId: tokenResponse.userId,
            accessToken: tokenResponse.accessToken
        )
    }
}

public enum OAuthError: Error, LocalizedError {
    case invalidCallback
    case tokenExchangeFailed
    case authenticationCancelled

    public var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid OAuth callback URL"
        case .tokenExchangeFailed:
            return "Failed to exchange code for access token"
        case .authenticationCancelled:
            return "Authentication was cancelled"
        }
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}

@MainActor
public class OAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding, ObservableObject {
    @Published public private(set) var isAuthenticating = false
    @Published public private(set) var error: Error?

    private let oauthClient: OAuthClient
    private let keychain: KeychainStorage

    public init(
        oauthClient: OAuthClient = OAuthClient(),
        keychain: KeychainStorage = KeychainStorage()
    ) {
        self.oauthClient = oauthClient
        self.keychain = keychain
    }

    public func authenticate() async throws -> ZedCredentials {
        isAuthenticating = true
        error = nil

        defer {
            isAuthenticating = false
        }

        do {
            let authURL = await oauthClient.startAuthentication()

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "zedmobile"
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        self.error = error
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            guard session.start() else {
                throw OAuthError.authenticationCancelled
            }

            let callbackURL = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let error = self.error {
                        continuation.resume(throwing: error)
                    }
                }
            }

            let credentials = try await oauthClient.handleCallback(url: callbackURL)

            try await keychain.saveCredentials(credentials)

            return credentials
        } catch {
            self.error = error
            throw error
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
