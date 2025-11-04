import Foundation

/// Represents the type of thread
public enum ThreadType: String, Codable, Sendable {
    case text
    case coding
}

/// Data encoding type for thread storage
public enum DataType: String, Codable, Sendable {
    case json
    case zstd
}

/// Metadata for a thread (used in list operations)
public struct ThreadMetadata: Codable, Identifiable, Sendable {
    public let id: UUID
    public let threadType: String
    public let title: String
    public let summary: String?
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadType = "thread_type"
        case title
        case summary
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID,
        threadType: String,
        title: String,
        summary: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.threadType = threadType
        self.title = title
        self.summary = summary
        self.updatedAt = updatedAt
    }
}

/// Full thread data (used in get/update operations)
public struct ThreadData: Codable, Sendable {
    public let id: UUID
    public let threadType: String
    public let dataType: String
    public let data: String  // Base64-encoded
    public let updatedAt: String  // RFC3339 timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case threadType = "thread_type"
        case dataType = "data_type"
        case data
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID,
        threadType: String,
        dataType: String,
        data: String,
        updatedAt: String
    ) {
        self.id = id
        self.threadType = threadType
        self.dataType = dataType
        self.data = data
        self.updatedAt = updatedAt
    }
}

/// Request for creating/updating a thread
public struct ThreadUpdateRequest: Codable, Sendable {
    public let threadType: String
    public let title: String
    public let summary: String?
    public let dataType: String
    public let data: String  // Base64-encoded

    enum CodingKeys: String, CodingKey {
        case threadType = "thread_type"
        case title
        case summary
        case dataType = "data_type"
        case data
    }

    public init(
        threadType: String,
        title: String,
        summary: String?,
        dataType: String,
        data: String
    ) {
        self.threadType = threadType
        self.title = title
        self.summary = summary
        self.dataType = dataType
        self.data = data
    }
}

/// Response from list threads endpoint
public struct ListThreadsResponse: Codable, Sendable {
    public let threads: [ThreadMetadata]

    public init(threads: [ThreadMetadata]) {
        self.threads = threads
    }
}

/// Response from upsert thread endpoint
public struct UpsertThreadResponse: Codable, Sendable {
    public let success: Bool
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case success
        case updatedAt = "updated_at"
    }

    public init(success: Bool, updatedAt: String) {
        self.success = success
        self.updatedAt = updatedAt
    }
}

/// Response from delete thread endpoint
public struct DeleteThreadResponse: Codable, Sendable {
    public let success: Bool

    public init(success: Bool) {
        self.success = success
    }
}
