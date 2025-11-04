import XCTest
@testable import ZedMobile

final class ZedMobileTests: XCTestCase {

    // MARK: - Model Tests

    func testThreadMetadataEncoding() throws {
        let metadata = ThreadMetadata(
            id: UUID(),
            threadType: "text",
            title: "Test Thread",
            summary: "Test summary",
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ThreadMetadata.self, from: data)

        XCTAssertEqual(metadata.id, decoded.id)
        XCTAssertEqual(metadata.threadType, decoded.threadType)
        XCTAssertEqual(metadata.title, decoded.title)
        XCTAssertEqual(metadata.summary, decoded.summary)
    }

    func testThreadUpdateRequestEncoding() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let base64 = testData.base64EncodedString()

        let request = ThreadUpdateRequest(
            threadType: "text",
            title: "My Thread",
            summary: "A test thread",
            dataType: "json",
            data: base64
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        // Verify it can be decoded
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ThreadUpdateRequest.self, from: data)

        XCTAssertEqual(request.threadType, decoded.threadType)
        XCTAssertEqual(request.title, decoded.title)
        XCTAssertEqual(request.summary, decoded.summary)
        XCTAssertEqual(request.data, decoded.data)
    }

    func testCredentialsAuthHeader() {
        let credentials = ZedCredentials(userId: 123, accessToken: "test_token")
        XCTAssertEqual(credentials.authorizationHeader, "123 test_token")
    }

    func testAPIConfiguration() {
        let production = ZedAPIConfiguration.production
        XCTAssertEqual(production.baseURL.absoluteString, "https://collab.zed.dev")

        let staging = ZedAPIConfiguration.staging
        XCTAssertEqual(staging.baseURL.absoluteString, "https://staging-collab.zed.dev")

        let local = ZedAPIConfiguration.local(port: 3000)
        XCTAssertEqual(local.baseURL.absoluteString, "http://localhost:3000")
    }

    // MARK: - Thread Manager Tests

    func testThreadManagerInitialization() async {
        let credentials = ZedCredentials(userId: 1, accessToken: "test")
        let manager = await ZedThreadManager(
            credentials: credentials,
            configuration: .local()
        )

        let threads = await manager.threads
        XCTAssertTrue(threads.isEmpty)
    }

    func testBase64EncodingDecoding() async throws {
        let credentials = ZedCredentials(userId: 1, accessToken: "test")
        let manager = await ZedThreadManager(
            credentials: credentials,
            configuration: .local()
        )

        let originalData = "Test thread content".data(using: .utf8)!
        let base64 = await manager.encodeThreadData(originalData)

        // Create a mock ThreadData
        let threadData = ThreadData(
            id: UUID(),
            threadType: "text",
            dataType: "json",
            data: base64,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        let decoded = try await manager.decodeThreadData(threadData)
        XCTAssertEqual(originalData, decoded)
    }
}
