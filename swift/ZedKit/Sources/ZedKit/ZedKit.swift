import Foundation

/// Main entry point for ZedKit framework
///
/// ZedKit provides iOS integration with Zed's collaboration server,
/// enabling thread synchronization, real-time collaboration, and agent interactions.
///
/// ## Topics
///
/// ### Getting Started
///
/// 1. Create credentials:
/// ```swift
/// let credentials = ZedCredentials(userId: 123, accessToken: "your_token")
/// ```
///
/// 2. Initialize the thread manager:
/// ```swift
/// let threadManager = ZedThreadManager(
///     credentials: credentials,
///     configuration: .production
/// )
/// ```
///
/// 3. Fetch threads:
/// ```swift
/// try await threadManager.fetchThreads()
/// ```
///
/// ### Core Types
/// - ``ZedThreadManager`` - High-level thread management
/// - ``ZedAPIClient`` - Low-level HTTP client
/// - ``ZedCredentials`` - Authentication credentials
/// - ``ThreadMetadata`` - Thread list item
/// - ``ThreadData`` - Full thread data
///
public enum ZedKit {
    /// Current version of ZedKit
    public static let version = "0.1.0"

    /// Create a thread manager with the given credentials
    public static func createThreadManager(
        credentials: ZedCredentials,
        configuration: ZedAPIConfiguration = .production
    ) -> ZedThreadManager {
        ZedThreadManager(credentials: credentials, configuration: configuration)
    }

    /// Create an API client for low-level operations
    public static func createAPIClient(
        configuration: ZedAPIConfiguration = .production
    ) -> ZedAPIClient {
        ZedAPIClient(configuration: configuration)
    }
}

// Re-export public types
public typealias Thread = ThreadMetadata
