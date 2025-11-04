import Foundation

/// Configuration for the Zed API client
public struct ZedAPIConfiguration: Sendable {
    public let baseURL: URL
    public let timeout: TimeInterval

    public init(
        baseURL: URL = URL(string: "https://collab.zed.dev")!,
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    /// Configuration for staging environment
    public static var staging: ZedAPIConfiguration {
        ZedAPIConfiguration(
            baseURL: URL(string: "https://staging-collab.zed.dev")!
        )
    }

    /// Configuration for production environment
    public static var production: ZedAPIConfiguration {
        ZedAPIConfiguration(
            baseURL: URL(string: "https://collab.zed.dev")!
        )
    }

    /// Configuration for local development
    public static func local(port: Int = 3000) -> ZedAPIConfiguration {
        ZedAPIConfiguration(
            baseURL: URL(string: "http://localhost:\(port)")!
        )
    }
}

/// Errors that can occur in API operations
public enum ZedAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case notFound

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - please check your credentials"
        case .notFound:
            return "Resource not found"
        }
    }
}

/// HTTP client for Zed API
public actor ZedAPIClient {
    private let configuration: ZedAPIConfiguration
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    public init(configuration: ZedAPIConfiguration = .production) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.urlSession = URLSession(configuration: sessionConfig)

        // Configure JSON decoder to handle RFC3339 dates
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 formatter
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(dateString)"
            )
        }

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Thread API

    /// List all threads for the authenticated user
    public func listThreads(
        credentials: ZedCredentials,
        since: Date? = nil
    ) async throws -> [ThreadMetadata] {
        var urlComponents = URLComponents(
            url: configuration.baseURL.appendingPathComponent("/threads"),
            resolvingAgainstBaseURL: true
        )

        if let since = since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            urlComponents?.queryItems = [
                URLQueryItem(name: "since", value: formatter.string(from: since))
            ]
        }

        guard let url = urlComponents?.url else {
            throw ZedAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")

        let response: ListThreadsResponse = try await performRequest(request)
        return response.threads
    }

    /// Get a specific thread by ID
    public func getThread(
        id: UUID,
        credentials: ZedCredentials
    ) async throws -> ThreadData {
        let url = configuration.baseURL
            .appendingPathComponent("/threads")
            .appendingPathComponent(id.uuidString)

        var request = URLRequest(url: url)
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")

        return try await performRequest(request)
    }

    /// Create or update a thread
    public func upsertThread(
        id: UUID,
        update: ThreadUpdateRequest,
        credentials: ZedCredentials
    ) async throws -> UpsertThreadResponse {
        let url = configuration.baseURL
            .appendingPathComponent("/threads")
            .appendingPathComponent(id.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try jsonEncoder.encode(update)
        } catch {
            throw ZedAPIError.encodingError(error)
        }

        return try await performRequest(request)
    }

    /// Delete a thread
    public func deleteThread(
        id: UUID,
        credentials: ZedCredentials
    ) async throws -> DeleteThreadResponse {
        let url = configuration.baseURL
            .appendingPathComponent("/threads")
            .appendingPathComponent(id.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")

        return try await performRequest(request)
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZedAPIError.invalidResponse
        }

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw ZedAPIError.unauthorized
        case 404:
            throw ZedAPIError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw ZedAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw ZedAPIError.decodingError(error)
        }
    }
}
