# ZedKit - iOS SDK for Zed

ZedKit is a Swift package that enables iOS apps to interact with Zed's collaboration server, providing thread synchronization, real-time collaboration, and agent interactions.

## Features

- ✅ **Thread Synchronization** - Sync agent threads between iOS and desktop
- ✅ **Secure Authentication** - Keychain storage for credentials
- ✅ **Type-Safe API** - Full Swift type safety with Codable models
- ✅ **Async/Await** - Modern Swift concurrency
- ✅ **ObservableObject** - SwiftUI integration ready
- 🚧 **Real-Time Collaboration** - Coming soon
- 🚧 **CRDT Support** - Coming soon
- 🚧 **Agent Integration** - Coming soon

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ZedKit to your project in Xcode:

1. File > Add Package Dependencies
2. Enter the package URL (when published)
3. Select version

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zed-industries/zed-kit", from: "0.1.0")
]
```

## Quick Start

### 1. Create Credentials

```swift
import ZedKit

let credentials = ZedCredentials(
    userId: 123,
    accessToken: "your_access_token"
)
```

### 2. Initialize Thread Manager

```swift
let threadManager = ZedKit.createThreadManager(
    credentials: credentials,
    configuration: .production
)
```

### 3. Fetch Threads

```swift
try await threadManager.fetchThreads()

for thread in threadManager.threads {
    print("\(thread.title) - updated: \(thread.updatedAt)")
}
```

### 4. Create a Thread

```swift
let content = """
{
    "version": "0.4.0",
    "messages": [{"role": "user", "content": "Hello!"}]
}
"""

let threadData = content.data(using: .utf8)!

let threadId = try await threadManager.createThread(
    type: .text,
    title: "My Thread",
    summary: "Created from iOS",
    data: threadData
)
```

### 5. Update a Thread

```swift
try await threadManager.updateThread(
    id: threadId,
    title: "Updated Title",
    summary: "New summary"
)
```

### 6. Delete a Thread

```swift
try await threadManager.deleteThread(id: threadId)
```

## SwiftUI Integration

ZedKit's `ZedThreadManager` conforms to `ObservableObject`, making it perfect for SwiftUI:

```swift
import SwiftUI
import ZedKit

struct ThreadListView: View {
    @StateObject private var threadManager: ZedThreadManager

    init(credentials: ZedCredentials) {
        _threadManager = StateObject(wrappedValue: ZedKit.createThreadManager(
            credentials: credentials
        ))
    }

    var body: some View {
        List(threadManager.threads) { thread in
            VStack(alignment: .leading) {
                Text(thread.title)
                    .font(.headline)
                Text(thread.summary ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            try? await threadManager.fetchThreads()
        }
        .refreshable {
            try? await threadManager.fetchThreads(forceRefresh: true)
        }
    }
}
```

## Secure Credential Storage

ZedKit includes keychain storage for secure credential management:

```swift
let keychain = KeychainStorage()

// Save credentials
try await keychain.saveCredentials(credentials)

// Load credentials
if let credentials = try await keychain.loadCredentials() {
    let manager = ZedKit.createThreadManager(credentials: credentials)
}

// Delete credentials (on logout)
try await keychain.deleteCredentials()
```

## Configuration

### Environments

```swift
// Production (default)
let config = ZedAPIConfiguration.production

// Staging
let config = ZedAPIConfiguration.staging

// Local development
let config = ZedAPIConfiguration.local(port: 3000)

// Custom
let config = ZedAPIConfiguration(
    baseURL: URL(string: "https://custom.server.com")!,
    timeout: 30
)
```

## API Reference

### ZedThreadManager

Main interface for thread management.

**Properties:**
- `threads: [ThreadMetadata]` - Cached list of threads
- `isLoading: Bool` - Loading state
- `error: Error?` - Last error

**Methods:**
- `fetchThreads(forceRefresh:)` - Fetch threads from server
- `getThread(id:)` - Get full thread data
- `createThread(type:title:summary:data:)` - Create new thread
- `updateThread(id:title:summary:data:)` - Update thread
- `deleteThread(id:)` - Delete thread

### ZedAPIClient

Low-level HTTP client for direct API access.

**Methods:**
- `listThreads(credentials:since:)` - List threads
- `getThread(id:credentials:)` - Get thread
- `upsertThread(id:update:credentials:)` - Create/update thread
- `deleteThread(id:credentials:)` - Delete thread

### Models

- `ThreadMetadata` - Thread list item
- `ThreadData` - Full thread data
- `ThreadType` - `.text` or `.coding`
- `ZedCredentials` - Authentication credentials
- `ZedAPIConfiguration` - API client configuration

## Error Handling

ZedKit uses Swift's native error handling:

```swift
do {
    try await threadManager.fetchThreads()
} catch ZedAPIError.unauthorized {
    // Handle authentication error
    print("Please re-authenticate")
} catch ZedAPIError.notFound {
    // Handle not found
    print("Thread not found")
} catch {
    // Handle other errors
    print("Error: \(error.localizedDescription)")
}
```

## Testing

Run tests with:

```bash
swift test
```

## Examples

See the `Examples/` directory for complete usage examples:

- `BasicUsage.swift` - Getting started guide
- More examples coming soon

## Roadmap

### Phase 1: Foundation ✅ (Current)
- [x] Thread synchronization API
- [x] Authentication
- [x] Keychain storage
- [x] SwiftUI integration
- [x] Basic tests

### Phase 2: Real-Time Collaboration (Next)
- [ ] WebSocket connection
- [ ] Buffer synchronization
- [ ] Presence tracking
- [ ] Collaborative editing

### Phase 3: CRDT Implementation
- [ ] Port Zed's CRDT to Swift
- [ ] Fragment-based text buffer
- [ ] Conflict-free merge
- [ ] Real-time editing

### Phase 4: Agent Integration
- [ ] ACP client implementation
- [ ] Tool call handling
- [ ] Terminal management
- [ ] Session continuity

### Phase 5: Repository Sync
- [ ] Git integration
- [ ] File tree browser
- [ ] Diff viewer
- [ ] Worktree sync

### Phase 6: Self-Collaboration
- [ ] Project join as guest
- [ ] Edit desktop projects from iOS
- [ ] Cursor presence
- [ ] Agent execution proxy

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

ZedKit is released under the same license as Zed. See [LICENSE](../LICENSE) for details.

## Support

- Documentation: [Full docs](https://zed.dev/docs/ios)
- Issues: [GitHub Issues](https://github.com/zed-industries/zed/issues)
- Discord: [Zed Community](https://discord.gg/zed)

## Architecture

```
┌─────────────────────────────────────────────────┐
│              iOS App (SwiftUI)                   │
├─────────────────────────────────────────────────┤
│           ZedThreadManager (@MainActor)          │
│                      ↓                           │
│              ZedAPIClient (Actor)                │
│                      ↓                           │
│              URLSession (HTTPS)                  │
└─────────────────────┬───────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  Zed Collaboration     │
         │      Server            │
         │  (collab.zed.dev)      │
         └────────────────────────┘
                      │
                      ▼
              ┌──────────────┐
              │  PostgreSQL  │
              │   threads    │
              └──────────────┘
```

## Credits

Built by the Zed team and contributors.

---

**Note**: ZedKit is currently in beta. APIs may change before 1.0 release.
