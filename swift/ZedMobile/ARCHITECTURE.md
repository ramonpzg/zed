# ZedMobile Architecture

## Overview

ZedMobile is a Swift package enabling iOS apps to sync agent threads with Zed's collaboration server.

## Component Layers

```
┌─────────────────────────────────────┐
│        iOS Application              │
│         (SwiftUI)                   │
├─────────────────────────────────────┤
│      ZedThreadManager               │
│    (@MainActor, ObservableObject)   │
├─────────────────────────────────────┤
│      ZedAPIClient (Actor)           │
│        URLSession                   │
├─────────────────────────────────────┤
│   Zed Collaboration Server          │
│     (collab.zed.dev)                │
└─────────────────────────────────────┘
```

## Core Components

### Models (Sources/ZedMobile/Models/)

**Thread.swift**
- `ThreadMetadata` - List item (id, title, type, timestamp)
- `ThreadData` - Full content (base64 encoded)
- `ThreadUpdateRequest` - Create/update payload
- Response types for all operations

**Authentication.swift**
- `ZedCredentials` - User ID + access token
- `AuthenticationError` - Type-safe errors

### Network (Sources/ZedMobile/Network/)

**ZedAPIClient.swift**
- Actor-based HTTP client using URLSession
- Async/await operations
- Environment configuration (production/staging/local)
- RFC3339 date handling
- Base64 encoding/decoding

API Methods:
- `listThreads(credentials:since:)` - GET /threads
- `getThread(id:credentials:)` - GET /threads/:id
- `upsertThread(id:update:credentials:)` - PUT /threads/:id
- `deleteThread(id:credentials:)` - DELETE /threads/:id

### Core (Sources/ZedMobile/Core/)

**ZedThreadManager.swift**
- Main actor for thread operations
- Observable object for SwiftUI reactivity
- Published properties for state
- Local caching with incremental sync
- Error state management

### Storage (Sources/ZedMobile/Storage/)

**KeychainStorage.swift**
- Actor-based keychain wrapper
- Secure credential persistence
- After-first-unlock access policy

## Data Flow

### Fetching Threads

```
User -> fetchThreads()
    -> ZedThreadManager
    -> ZedAPIClient.listThreads()
    -> URLSession GET /threads
    -> Decode JSON
    -> Merge with cache
    -> Update @Published threads
    -> SwiftUI re-renders
```

### Creating Thread

```
User -> createThread()
    -> Encode data to base64
    -> Build ThreadUpdateRequest
    -> ZedAPIClient.upsertThread()
    -> URLSession PUT /threads/:id
    -> Decode response
    -> Update local cache
    -> Update @Published threads
    -> SwiftUI re-renders
```

## Concurrency Model

**Main Actor** - UI and state updates
- `ZedThreadManager` runs on main actor
- All `@Published` updates on main thread
- UI reads from main thread

**Background Actor** - Network operations
- `ZedAPIClient` is an actor (background)
- Network calls on background thread
- JSON encoding/decoding on background thread

**Keychain Actor** - Secure storage
- `KeychainStorage` is an actor
- Serializes keychain access
- Async operations

## Error Handling

Errors propagate through Result types:
- Network errors -> `ZedAPIError`
- Authentication errors -> `AuthenticationError`
- Keychain errors -> `KeychainError`

All errors conform to `LocalizedError` for user-facing messages.

## Testing Strategy

**Unit Tests**
- Model encoding/decoding
- Configuration validation
- Manager initialization

**Integration Tests** (Manual)
- Test against local Zed server
- Verify thread sync with desktop
- Check authentication flow

## Security

**Credentials**
- Stored in iOS Keychain
- Never in UserDefaults or files
- After-first-unlock access

**Network**
- HTTPS only (URLSession default)
- Certificate validation (system default)
- No certificate pinning (relies on system trust)

**Data**
- Base64 encoding for transport
- No local encryption (relies on iOS file encryption)

## Performance

**Caching**
- In-memory thread list
- Incremental sync (fetch only updated)
- No eviction policy (unlimited cache)

**Network**
- 30-second timeout
- No retry logic
- No request coalescing

## Future Components

### Phase 2: Real-Time Collaboration
- WebSocket client for live updates
- Room/project management
- Presence tracking

### Phase 3: CRDT
- Fragment-based text buffer
- Lamport timestamps
- Conflict-free merge

### Phase 4: Agent Integration
- ACP client
- Tool call handling
- Terminal management

## Dependencies

None. Uses only Foundation framework.

## Platform Support

- iOS 16.0+
- macOS 13.0+
- Swift 5.9+
