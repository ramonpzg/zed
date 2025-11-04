# Testing ZedMobile

## Prerequisites

1. Zed desktop installed with existing threads
2. Zed user ID and access token
3. Xcode 15.0+ installed

## Getting Credentials

### Option 1: From Zed Desktop (Current)

Until OAuth is fully wired up, get credentials from Zed:

1. Open Zed
2. Open developer console (Cmd+Option+I)
3. Run: `zed.currentUser()`
4. Note the `id` (your user ID)
5. Get access token from keychain or Zed settings

### Option 2: OAuth Flow (Requires Server Setup)

Once Zed's OAuth endpoints are configured for mobile:

```swift
let oauth = ZedMobile.createOAuthCoordinator()
let credentials = try await oauth.authenticate()
```

## Testing Against Local Server

### 1. Start Zed Collaboration Server

```bash
cd crates/collab
cargo run
```

Server runs on http://localhost:3000

### 2. Configure ZedMobile for Local

```swift
let manager = ZedMobile.createThreadManager(
    credentials: credentials,
    configuration: .local(port: 3000)
)
```

### 3. Run Tests

```bash
cd swift/ZedMobile
swift test
```

## Testing Against Production

### 1. Configure for Production

```swift
let manager = ZedMobile.createThreadManager(
    credentials: credentials,
    configuration: .production
)
```

### 2. Test Thread Sync

```swift
// List threads
try await manager.fetchThreads()
print("Found \(manager.threads.count) threads")

// Get thread
if let first = manager.threads.first {
    let data = try await manager.getThread(id: first.id)
    print("Thread data: \(data)")
}

// Create thread
let content = """
{
    "version": "0.4.0",
    "messages": [{"role": "user", "content": "Test from iOS"}]
}
"""
let id = try await manager.createThread(
    type: .text,
    title: "iOS Test Thread",
    data: content.data(using: .utf8)!
)
print("Created thread: \(id)")
```

### 3. Verify in Desktop

Open Zed desktop and check:
- Thread created from iOS appears in list
- Thread metadata is correct
- Thread content is readable

### 4. Test Bidirectional Sync

From desktop:
1. Create a new thread
2. Note the title and timestamp

From iOS:
```swift
try await manager.fetchThreads(forceRefresh: true)
// Desktop thread should appear
```

## Testing with Xcode

### 1. Open Package

```bash
cd swift/ZedMobile
open Package.swift
```

### 2. Create Test Target

File > New > Target > Unit Testing Bundle

### 3. Write Integration Test

```swift
import XCTest
@testable import ZedMobile

final class IntegrationTests: XCTestCase {
    func testThreadSync() async throws {
        let credentials = ZedCredentials(
            userId: /* your user id */,
            accessToken: /* your token */
        )

        let manager = ZedMobile.createThreadManager(
            credentials: credentials,
            configuration: .local(port: 3000)
        )

        try await manager.fetchThreads()
        XCTAssertGreaterThan(manager.threads.count, 0)
    }
}
```

### 4. Run Test

Product > Test (Cmd+U)

## Testing OAuth Flow

### 1. Configure URL Scheme

In your iOS app's Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zedmobile</string>
        </array>
    </dict>
</array>
```

### 2. Handle Callback

In SceneDelegate or App:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }

    Task {
        let credentials = try await oauth.handleCallback(url: url)
        // Store and use credentials
    }
}
```

### 3. Test Flow

1. Call `oauth.authenticate()`
2. Safari opens Zed OAuth page
3. User logs in with GitHub
4. Zed redirects to zedmobile://oauth/callback
5. App receives credentials

## Testing Keychain Storage

```swift
let keychain = KeychainStorage()

// Save
let credentials = ZedCredentials(userId: 123, accessToken: "test")
try await keychain.saveCredentials(credentials)

// Load
let loaded = try await keychain.loadCredentials()
XCTAssertEqual(loaded?.userId, 123)

// Delete
try await keychain.deleteCredentials()
let deleted = try await keychain.loadCredentials()
XCTAssertNil(deleted)
```

## Common Issues

### "Unauthorized" Error

- Check user ID is correct
- Check access token is valid
- Check token hasn't expired
- Try re-authenticating

### "Connection Refused"

- Check collab server is running
- Check configuration URL is correct
- Check firewall/network settings

### "Thread Not Found"

- Check thread ID exists
- Check user has access to thread
- Try fetching threads first

## Performance Testing

### Measure Sync Time

```swift
let start = Date()
try await manager.fetchThreads()
let duration = Date().timeIntervalSince(start)
print("Sync took: \(duration)s")
```

### Measure with Many Threads

Create 100 threads and measure sync performance.

### Memory Usage

Use Xcode Instruments to check memory:
1. Product > Profile
2. Select "Allocations"
3. Run thread sync
4. Check peak memory usage

## Next Steps

Once basic sync works:
1. Test with large threads (>1MB content)
2. Test with many threads (>100)
3. Test offline mode
4. Test incremental sync
5. Test error recovery
