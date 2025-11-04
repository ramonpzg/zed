import Foundation

/// Authentication credentials for Zed API
public struct ZedCredentials: Codable, Sendable {
    public let userId: Int
    public let accessToken: String

    public init(userId: Int, accessToken: String) {
        self.userId = userId
        self.accessToken = accessToken
    }

    /// Creates the Authorization header value
    public var authorizationHeader: String {
        "\(userId) \(accessToken)"
    }
}

/// Errors that can occur during authentication
public enum AuthenticationError: Error, LocalizedError {
    case missingCredentials
    case invalidCredentials
    case unauthorized
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "No credentials found. Please authenticate first."
        case .invalidCredentials:
            return "The provided credentials are invalid."
        case .unauthorized:
            return "Unauthorized. Please re-authenticate."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
