import Foundation

/// High-level manager for Zed threads with caching and sync
@MainActor
public class ZedThreadManager: ObservableObject {
    @Published public private(set) var threads: [ThreadMetadata] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?

    private let apiClient: ZedAPIClient
    private let credentials: ZedCredentials
    private var lastSyncDate: Date?

    public init(
        credentials: ZedCredentials,
        configuration: ZedAPIConfiguration = .production
    ) {
        self.credentials = credentials
        self.apiClient = ZedAPIClient(configuration: configuration)
    }

    // MARK: - Thread Operations

    /// Fetch all threads from the server
    public func fetchThreads(forceRefresh: Bool = false) async throws {
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        do {
            let since = forceRefresh ? nil : lastSyncDate
            let fetchedThreads = try await apiClient.listThreads(
                credentials: credentials,
                since: since
            )

            // Merge with existing threads if doing incremental sync
            if let since = since {
                // Remove threads that were updated
                let updatedIds = Set(fetchedThreads.map { $0.id })
                threads.removeAll { updatedIds.contains($0.id) }

                // Add new/updated threads
                threads.append(contentsOf: fetchedThreads)

                // Sort by update time
                threads.sort { $0.updatedAt > $1.updatedAt }
            } else {
                threads = fetchedThreads.sorted { $0.updatedAt > $1.updatedAt }
            }

            lastSyncDate = Date()
        } catch {
            self.error = error
            throw error
        }
    }

    /// Get a specific thread's full data
    public func getThread(id: UUID) async throws -> ThreadData {
        do {
            return try await apiClient.getThread(id: id, credentials: credentials)
        } catch {
            self.error = error
            throw error
        }
    }

    /// Create a new thread
    public func createThread(
        type: ThreadType,
        title: String,
        summary: String? = nil,
        data: Data
    ) async throws -> UUID {
        let id = UUID()

        let base64Data = data.base64EncodedString()
        let request = ThreadUpdateRequest(
            threadType: type.rawValue,
            title: title,
            summary: summary,
            dataType: "json",
            data: base64Data
        )

        do {
            let response = try await apiClient.upsertThread(
                id: id,
                update: request,
                credentials: credentials
            )

            // Add to local cache
            let metadata = ThreadMetadata(
                id: id,
                threadType: type.rawValue,
                title: title,
                summary: summary,
                updatedAt: ISO8601DateFormatter().date(from: response.updatedAt) ?? Date()
            )
            threads.insert(metadata, at: 0)

            return id
        } catch {
            self.error = error
            throw error
        }
    }

    /// Update an existing thread
    public func updateThread(
        id: UUID,
        title: String? = nil,
        summary: String? = nil,
        data: Data? = nil
    ) async throws {
        // Get current thread data if we need it
        let currentData: ThreadData
        if title == nil || data == nil {
            currentData = try await getThread(id: id)
        } else {
            // Create a placeholder since we have all the data
            currentData = ThreadData(
                id: id,
                threadType: "text",
                dataType: "json",
                data: "",
                updatedAt: ""
            )
        }

        let base64Data: String
        if let data = data {
            base64Data = data.base64EncodedString()
        } else {
            base64Data = currentData.data
        }

        let request = ThreadUpdateRequest(
            threadType: currentData.threadType,
            title: title ?? threads.first(where: { $0.id == id })?.title ?? "Untitled",
            summary: summary,
            dataType: currentData.dataType,
            data: base64Data
        )

        do {
            let response = try await apiClient.upsertThread(
                id: id,
                update: request,
                credentials: credentials
            )

            // Update local cache
            if let index = threads.firstIndex(where: { $0.id == id }) {
                threads[index] = ThreadMetadata(
                    id: id,
                    threadType: request.threadType,
                    title: request.title,
                    summary: request.summary,
                    updatedAt: ISO8601DateFormatter().date(from: response.updatedAt) ?? Date()
                )

                // Re-sort
                threads.sort { $0.updatedAt > $1.updatedAt }
            }
        } catch {
            self.error = error
            throw error
        }
    }

    /// Delete a thread
    public func deleteThread(id: UUID) async throws {
        do {
            _ = try await apiClient.deleteThread(id: id, credentials: credentials)

            // Remove from local cache
            threads.removeAll { $0.id == id }
        } catch {
            self.error = error
            throw error
        }
    }

    // MARK: - Helpers

    /// Decode thread data from base64
    public func decodeThreadData(_ threadData: ThreadData) throws -> Data {
        guard let data = Data(base64Encoded: threadData.data) else {
            throw ZedAPIError.decodingError(
                NSError(domain: "ZedMobile", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to decode base64 data"
                ])
            )
        }
        return data
    }

    /// Encode data for thread storage
    public func encodeThreadData(_ data: Data) -> String {
        data.base64EncodedString()
    }
}
