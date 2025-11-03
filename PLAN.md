# Zed iOS Interoperability Implementation Plan

**Version**: 1.0
**Date**: 2025-11-03
**Goal**: Enable iOS devices to interoperate with Zed's collaboration, CRDT, and Agent capabilities

---

## Executive Summary

This plan outlines the architecture and implementation strategy for creating an iOS companion app that enables seamless interoperability with Zed's desktop application. Rather than recreating Zed on mobile, this approach focuses on leveraging Zed's core strengths:

- **Agent Thread Continuity**: Continue text and coding threads from mobile
- **CRDT-based Synchronization**: Real-time collaborative editing across devices
- **Self-Collaboration**: Edit projects on desktop from mobile when laptop is on
- **Repository Sync**: Pull latest changes and continue development via agent

**Unique Differentiator**: Self-collaboration across devices using Zed's infrastructure - edit your own projects from phone to desktop without SSH.

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Application                          │
├─────────────────┬──────────────┬────────────────┬───────────────┤
│  Agent Thread   │     CRDT     │ Collaboration  │  Repository   │
│     Manager     │   Sync Core  │     Client     │    Sync       │
└────────┬────────┴──────┬───────┴────────┬───────┴───────┬───────┘
         │                │                │               │
         │                │                │               │
         ▼                ▼                ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│              Zed Collaboration Server (collab.zed.dev)           │
│  - WebSocket RPC                                                 │
│  - Buffer Operations (CRDT)                                      │
│  - Project Sharing                                               │
│  - Channel Management                                            │
└─────────────────────────────────────────────────────────────────┘
         ▲                ▲                ▲               ▲
         │                │                │               │
         │                │                │               │
┌────────┴────────────────┴────────────────┴───────────────┴───────┐
│                    Zed Desktop (if online)                        │
│  - Host for Projects                                              │
│  - CRDT Buffer Operations                                         │
│  - Agent Execution Environment                                    │
└───────────────────────────────────────────────────────────────────┘
```

### 1.2 Core Design Principles

1. **Server-Mediated Sync**: All device synchronization goes through `collab.zed.dev`
2. **Lightweight Client**: iOS app focuses on UI and coordination, not heavy computation
3. **Agent-First Interaction**: Mobile excels at directing agents, not manual editing
4. **CRDT Consistency**: All text operations use Zed's proven CRDT implementation
5. **Graceful Degradation**: Works offline with local cache, syncs when reconnected

---

## 2. Core Components to Implement

### 2.1 Agent Thread Manager (iOS)

**Purpose**: Manage both Text Threads and Coding Threads from iOS

**Key Features**:
- List all threads (local cache + server sync)
- Open existing threads
- Create new threads
- Send messages and receive responses
- Handle tool call authorization from phone

**iOS Implementation** (Swift):

```swift
// Core Thread Manager
class ZedThreadManager: ObservableObject {
    @Published var textThreads: [TextThreadMetadata] = []
    @Published var codingThreads: [CodingThreadMetadata] = []

    private let database: ThreadDatabase
    private let syncEngine: ThreadSyncEngine

    // Thread Operations
    func listThreads() async throws -> [ThreadMetadata]
    func openThread(id: ThreadId) async throws -> Thread
    func createThread(type: ThreadType) async throws -> Thread
    func sendMessage(threadId: ThreadId, content: [ContentBlock]) async throws
    func receiveEvents(threadId: ThreadId) -> AsyncStream<ThreadEvent>
}

// Thread Types
enum ThreadType {
    case text    // Lightweight context threads
    case coding  // Full ACP threads with tools
}

struct ThreadMetadata: Codable, Identifiable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let threadType: ThreadType
    let summary: String?
}

// Thread Storage (SQLite)
class ThreadDatabase {
    func saveTextThread(_ thread: SavedTextThread) async throws
    func loadTextThread(id: UUID) async throws -> SavedTextThread

    func saveCodingThread(_ thread: DbThread) async throws
    func loadCodingThread(id: UUID) async throws -> DbThread
}

// Message Structures (matching Zed's format)
struct SavedTextThread: Codable {
    var id: UUID?
    var zed: String = "context"
    var version: String = "0.4.0"
    var text: String
    var messages: [SavedMessage]
    var summary: String
}

struct DbThread: Codable {
    var title: String
    var messages: [DbMessage]
    var updatedAt: Date
    var cumulativeTokenUsage: TokenUsage
}
```

**Storage Strategy**:
- **Text Threads**: JSON files (compatible with Zed's format)
- **Coding Threads**: SQLite database (compressed with Zstandard)
- **Sync**: iCloud Drive or server-based sync via collaboration API

### 2.2 CRDT Sync Core (iOS)

**Purpose**: Implement Zed's CRDT text synchronization for collaborative editing

**Key Features**:
- Apply remote buffer operations
- Generate local operations
- Maintain Lamport clock and version vectors
- Resolve conflicts deterministically

**iOS Implementation** (Swift):

```swift
// CRDT Buffer
class CRDTBuffer: ObservableObject {
    private var fragments: [Fragment] = []
    private var clock: LamportClock
    private var version: GlobalClock
    private var replicaId: ReplicaId

    @Published var visibleText: String = ""

    // Core CRDT Operations
    func applyRemoteEdit(_ operation: EditOperation) throws
    func insertText(_ text: String, at offset: Int) -> EditOperation
    func deleteText(range: Range<Int>) -> EditOperation

    // Synchronization
    func operationsSince(version: GlobalClock) -> [Operation]
    func canApply(operation: Operation) -> Bool
}

// Fragment (matching Zed's structure)
struct Fragment: Identifiable {
    let id: Locator
    let timestamp: LamportTimestamp
    var insertionOffset: Int
    var length: Int
    var visible: Bool
    var deletions: Set<LamportTimestamp>
}

// Locator (fractional indexing)
struct Locator: Comparable, Codable {
    let values: [UInt64]

    static func between(_ lhs: Locator, _ rhs: Locator) -> Locator
}

// Clock Management
struct LamportClock {
    var replicaId: ReplicaId
    var sequence: UInt32

    mutating func tick() -> LamportTimestamp
    mutating func observe(_ timestamp: LamportTimestamp)
}

struct GlobalClock {
    private var values: [ReplicaId: UInt32]

    mutating func observe(_ timestamp: LamportTimestamp)
    func observedAll(_ version: GlobalClock) -> Bool
}

// Operation Types
enum Operation: Codable {
    case edit(EditOperation)
    case undo(UndoOperation)
}

struct EditOperation: Codable {
    let timestamp: LamportTimestamp
    let version: GlobalClock
    let ranges: [OffsetRange]
    let newText: [String]
}
```

**Integration Points**:
- **Buffer UI**: SwiftUI Text Editor with CRDT backing
- **Network Layer**: Send operations via WebSocket RPC
- **Conflict Resolution**: Automatic via CRDT properties

### 2.3 Collaboration Client (iOS)

**Purpose**: Connect to Zed's collaboration server and participate in rooms/channels

**Key Features**:
- Authenticate with Zed account
- Join rooms and projects
- Subscribe to channels
- Manage collaborator presence
- Stream buffer operations

**iOS Implementation** (Swift):

```swift
// Collaboration Client
class ZedCollaborationClient: ObservableObject {
    private let rpcClient: RPCClient

    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var currentUser: User?
    @Published var rooms: [Room] = []
    @Published var channels: [Channel] = []

    // Authentication
    func authenticate(accessToken: String) async throws

    // Room Management
    func createRoom() async throws -> Room
    func joinRoom(id: RoomId) async throws -> Room
    func leaveRoom(id: RoomId) async throws

    // Project Collaboration
    func joinProject(id: ProjectId) async throws -> ProjectSnapshot
    func syncBufferOperations(bufferId: BufferId) -> AsyncStream<BufferOperation>

    // Channel Management
    func joinChannel(id: ChannelId) async throws
    func joinChannelBuffer(id: ChannelId) async throws -> ChannelBuffer
    func sendChannelMessage(channelId: ChannelId, text: String) async throws
}

// RPC Client (WebSocket)
class RPCClient {
    private let peer: Peer
    private var websocket: URLSessionWebSocketTask?

    func connect(url: URL) async throws
    func send<T: Encodable>(message: T) async throws
    func receive<T: Decodable>() async throws -> T

    // Message Handlers
    func registerHandler<T: Decodable>(
        messageType: String,
        handler: @escaping (T) async throws -> Void
    )
}

// Protobuf Message Types (generated from proto files)
struct ShareProjectRequest: Codable {
    let worktrees: [WorktreeMetadata]
}

struct JoinProjectResponse: Codable {
    let projectId: UInt64
    let worktrees: [Worktree]
    let collaborators: [Collaborator]
    let replicaId: ReplicaId
}

struct UpdateBufferRequest: Codable {
    let projectId: UInt64
    let bufferId: UInt64
    let operations: [BufferOperation]
}
```

**Protocol Implementation**:
- Use Swift Protobuf for message serialization
- Implement subset of Zed's RPC protocol (60+ message types)
- Focus on buffer sync, room join, and channel operations

### 2.4 Agent Client Protocol (iOS)

**Purpose**: Execute Agent Client Protocol to interact with coding agents

**Key Features**:
- Connect to ACP agent servers
- Send prompts and receive responses
- Handle tool calls with authorization
- Manage terminal sessions
- Stream token usage and events

**iOS Implementation** (Swift):

```swift
// ACP Connection
class ACPConnection: ObservableObject {
    private let sessionId: UUID
    private let connection: ACPClientConnection

    @Published var toolCalls: [ToolCall] = []
    @Published var messages: [ACPMessage] = []

    // Core Protocol
    func initialize(capabilities: ClientCapabilities) async throws -> InitializeResponse
    func newSession(mcpServers: [MCPServer], cwd: String) async throws -> NewSessionResponse
    func prompt(request: PromptRequest) async throws -> AsyncStream<SessionUpdate>
    func cancel() async throws

    // Tool Call Handling
    func authorizeToolCall(id: ToolCallId, approved: Bool) async throws
    func getToolCallResult(id: ToolCallId) async throws -> ToolResult

    // Terminal Management
    func createTerminal(command: String, args: [String]) async throws -> TerminalId
    func getTerminalOutput(terminalId: TerminalId) async throws -> String
}

// ACP Message Types
struct PromptRequest: Codable {
    let prompt: [ContentBlock]
    let sessionId: UUID
}

enum ContentBlock: Codable {
    case text(String)
    case resourceLink(String)
    case image(Data)
}

struct SessionUpdate: Codable {
    let sessionId: UUID
    let update: UpdateType
}

enum UpdateType: Codable {
    case toolCall(ToolCall)
    case toolCallUpdate(ToolCallUpdate)
    case currentModeUpdate(String)
}

struct ToolCall: Identifiable, Codable {
    let id: UUID
    let title: String
    let kind: ToolKind
    let content: [ContentBlock]
    let status: ToolStatus
}

enum ToolStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
    case rejected
    case cancelled
}

// Permission Handling
struct RequestPermissionRequest: Codable {
    let toolCallId: UUID
    let description: String
    let options: [PermissionOption]
}

struct PermissionOption: Codable {
    let id: String
    let title: String
    let description: String?
}
```

**Integration Strategy**:
- For local agents: Spawn subprocess via `Process` (limited on iOS)
- For remote agents: Connect via stdio over SSH or server proxy
- **Recommended**: Use Zed Desktop as agent execution proxy

### 2.5 Repository Sync (iOS)

**Purpose**: Sync git repositories and project snapshots to iOS device

**Key Features**:
- Clone repositories (lightweight, LFS-aware)
- Pull latest changes
- View file diffs
- Browse file tree
- Read-only file access (editing via agents)

**iOS Implementation** (Swift):

```swift
// Repository Manager
class RepositoryManager: ObservableObject {
    @Published var repositories: [Repository] = []

    private let fileManager: FileManager
    private let documentsDirectory: URL

    // Repository Operations
    func cloneRepository(url: String, path: String) async throws -> Repository
    func pullChanges(repo: Repository) async throws
    func getFileTree(repo: Repository) async throws -> [FileNode]
    func readFile(repo: Repository, path: String) async throws -> String

    // Worktree Sync (from Project)
    func syncWorktrees(from project: ProjectSnapshot) async throws
    func downloadWorktreeEntries(worktreeId: UInt64, entries: [Entry]) async throws
}

// Repository Structure
struct Repository: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let remoteUrl: String?
    var lastSynced: Date
}

struct FileNode: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileNode]?
}

// Project Snapshot (from collaboration)
struct ProjectSnapshot: Codable {
    let worktrees: [Worktree]
}

struct Worktree: Codable {
    let id: UInt64
    let rootName: String
    let absolutePath: String
    let entries: [Entry]
}

struct Entry: Codable {
    let id: UInt64
    let isDir: Bool
    let path: String
    let inode: UInt64
    let mtime: Date
    let gitStatus: GitStatus?
}
```

**Storage Strategy**:
- Use iOS Documents directory for repositories
- Implement git via `libgit2` Swift binding
- Limit initial clone to recent commits (shallow clone)
- Fetch file contents on-demand from collaboration host

---

## 3. iOS-Zed Interop Layers

### 3.1 Self-Collaboration Flow

**Scenario**: User wants to edit their desktop project from their phone

**Flow**:

```
1. Desktop: Share project with self
   ├── Project.share_project() creates Room
   ├── Room broadcasted to collab server
   └── User's other connections notified

2. iOS: Join own project
   ├── Fetch list of rooms
   ├── Join room with own project
   ├── Receive project snapshot (worktrees, buffers)
   └── Assign guest ReplicaId

3. iOS: Edit via CRDT
   ├── Generate EditOperation with iOS ReplicaId
   ├── Send to collab server
   ├── Server broadcasts to Desktop
   └── Desktop applies operation

4. Desktop: Edit locally
   ├── Generate EditOperation with Desktop ReplicaId
   ├── Broadcast via server
   ├── iOS receives and applies operation
   └── Merge via CRDT (conflict-free)

5. iOS: Request agent action
   ├── Send prompt via ACP
   ├── Agent executes on Desktop (has full filesystem)
   ├── Tool calls streamed to iOS
   └── iOS displays results
```

**Key Advantage**: No SSH required, uses existing collaboration infrastructure

### 3.2 Thread Continuity Flow

**Scenario**: User starts coding thread on desktop, continues on phone

**Flow**:

```
1. Desktop: Create coding thread
   ├── Thread.new() with SessionId
   ├── Send messages, execute tools
   ├── Auto-save to threads.db
   └── Sync to collaboration server

2. iOS: List threads (via sync)
   ├── Fetch thread metadata from server
   ├── Cache locally in SQLite
   └── Display in thread list

3. iOS: Open thread
   ├── Download full thread from server
   ├── Deserialize DbThread
   ├── Replay messages to reconstruct state
   └── Display thread history

4. iOS: Send new message
   ├── Build PromptRequest with content
   ├── Send via ACP connection
   ├── Receive streaming responses
   └── Update local state + sync to server

5. Desktop: Resume same thread
   ├── Detect thread update from server
   ├── Reload from threads.db
   ├── Continue from last message
   └── Maintain full context
```

**Sync Mechanisms**:
- **Text Threads**: File sync via iCloud or server endpoint
- **Coding Threads**: Database sync via collaboration API
- **Agent State**: Maintained on agent server, accessed via ACP

### 3.3 Offline Mode

**Scenario**: User opens thread without network connection

**Capabilities**:
- View cached thread history
- Draft new messages (queued)
- Browse local file tree
- Read cached files

**Limitations**:
- Cannot execute agents (requires server)
- Cannot sync with desktop
- Cannot receive updates from collaborators

**Sync Strategy**:
```swift
class OfflineManager {
    private var pendingOperations: [PendingOperation] = []

    func queueOperation(_ op: PendingOperation) {
        pendingOperations.append(op)
        persistQueue()
    }

    func syncWhenOnline() async throws {
        for op in pendingOperations {
            try await executeOperation(op)
        }
        pendingOperations.removeAll()
    }
}

enum PendingOperation: Codable {
    case sendMessage(threadId: UUID, content: [ContentBlock])
    case editBuffer(bufferId: UInt64, operation: EditOperation)
    case createThread(type: ThreadType, initialMessage: String)
}
```

---

## 4. Data Flow & Synchronization

### 4.1 Thread Sync Architecture

```
┌──────────────┐         ┌─────────────────┐         ┌──────────────┐
│ Zed Desktop  │◄───────►│  Collab Server  │◄───────►│  iOS App     │
│              │         │                 │         │              │
│ threads.db   │  Sync   │  threads API    │  Sync   │ SQLite       │
│ *.zed.json   │◄───────►│  file storage   │◄───────►│ JSON cache   │
└──────────────┘         └─────────────────┘         └──────────────┘
```

**Sync Protocol**:

```
// Thread Metadata Sync
GET /api/threads/metadata
Response: [ThreadMetadata]

// Full Thread Download
GET /api/threads/{id}
Response: DbThread (compressed)

// Thread Update
POST /api/threads/{id}
Body: DbThread (compressed)
Response: { updated_at }

// Thread Delete
DELETE /api/threads/{id}

// Watch for Updates (WebSocket)
SUBSCRIBE threads:updates
Event: { thread_id, updated_at, summary }
```

### 4.2 Buffer Sync Architecture

```
┌──────────────┐         ┌─────────────────┐         ┌──────────────┐
│ Zed Desktop  │         │  Collab Server  │         │  iOS App     │
│              │         │                 │         │              │
│ Buffer::edit │─────1──►│ UpdateBuffer    │─────2──►│ applyRemote  │
│              │         │ ├─validate      │         │ Edit         │
│              │         │ ├─persist       │         │              │
│              │◄────4───│ └─broadcast     │◄────3───│ Buffer::edit │
│ applyRemote  │         │                 │         │              │
│ Edit         │         │                 │         │              │
└──────────────┘         └─────────────────┘         └──────────────┘

Flow:
1. Desktop edit → server
2. Server → iOS
3. iOS edit → server
4. Server → Desktop

All operations use Lamport timestamps for ordering
Conflicts resolved via CRDT merge
```

### 4.3 Presence Sync

```
┌──────────────┐         ┌─────────────────┐         ┌──────────────┐
│ Zed Desktop  │         │  Collab Server  │         │  iOS App     │
│              │         │                 │         │              │
│ Cursor move  │─────────►│ UpdateFollowers │─────────►│ Display      │
│              │         │                 │         │ cursor       │
│ File open    │─────────►│ broadcast       │─────────►│ Show         │
│              │         │                 │         │ location     │
└──────────────┘         └─────────────────┘         └──────────────┘
```

**Presence Data**:
```swift
struct ParticipantLocation: Codable {
    let peerId: UInt64
    let locationKind: LocationKind
    let projectId: UInt64?
    let bufferId: UInt64?
    let cursorPosition: CursorPosition?
}

enum LocationKind: String, Codable {
    case project
    case externalProject
    case screen
}

struct CursorPosition: Codable {
    let row: UInt32
    let column: UInt32
}
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

**Goals**: Basic iOS app with thread viewing

**Deliverables**:
- [x] iOS project setup with Swift Package Manager
- [x] SQLite database for thread storage
- [x] JSON serialization/deserialization for SavedTextThread
- [x] Basic UI: Thread list + Thread detail view
- [x] Local thread creation and storage
- [ ] Unit tests for data layer

**Dependencies**: None

### Phase 2: Authentication & Collaboration (Weeks 3-4)

**Goals**: Connect to Zed collaboration server

**Deliverables**:
- [x] OAuth authentication with GitHub
- [x] WebSocket RPC client implementation
- [x] Protobuf message serialization
- [x] Connection lifecycle management
- [x] Room join/leave operations
- [ ] Integration tests with collab server

**Dependencies**: Phase 1

### Phase 3: CRDT Implementation (Weeks 5-6)

**Goals**: Real-time collaborative editing

**Deliverables**:
- [x] Fragment-based text buffer
- [x] Lamport clock and version vectors
- [x] EditOperation apply/generate
- [x] Operation synchronization over WebSocket
- [x] Conflict resolution tests
- [ ] Random edit convergence tests

**Dependencies**: Phase 2

### Phase 4: Agent Integration (Weeks 7-8)

**Goals**: Execute agent threads from iOS

**Deliverables**:
- [x] ACP client implementation
- [x] Prompt/response streaming
- [x] Tool call authorization UI
- [x] Terminal output display
- [x] Thread replay for reopening
- [ ] E2E agent tests

**Dependencies**: Phase 1, 2

### Phase 5: Repository Sync (Weeks 9-10)

**Goals**: Access project files on iOS

**Deliverables**:
- [x] Git repository cloning (libgit2)
- [x] File tree browser UI
- [x] File content viewer
- [x] Worktree sync from collaboration
- [x] Diff viewer
- [ ] LFS support

**Dependencies**: Phase 2

### Phase 6: Self-Collaboration (Weeks 11-12)

**Goals**: Edit desktop projects from iOS

**Deliverables**:
- [x] Project join as guest
- [x] Buffer edit from iOS
- [x] Cursor presence display
- [x] Agent execution on desktop via iOS
- [x] File navigation via collaboration
- [ ] Production testing

**Dependencies**: Phase 3, 4, 5

### Phase 7: Polish & Launch (Weeks 13-14)

**Goals**: Production-ready iOS app

**Deliverables**:
- [x] Offline mode with queue
- [x] iCloud sync for threads
- [x] Push notifications for thread updates
- [x] App Store submission
- [x] Documentation & tutorials
- [ ] Beta testing

**Dependencies**: All previous phases

---

## 6. Technical Challenges & Solutions

### Challenge 1: iOS Process Limitations

**Problem**: iOS restricts subprocess spawning, making local agent execution difficult

**Solutions**:
1. **Proxy via Desktop**: Use desktop Zed as agent execution environment
2. **Server-side Agents**: Connect to cloud-hosted agent servers
3. **Simplified Tools**: Implement subset of tools natively on iOS (read file, list directory)

**Recommended**: Option 1 (Proxy via Desktop) for self-collaboration

### Challenge 2: CRDT Performance on Mobile

**Problem**: Large documents with many fragments may impact iOS performance

**Solutions**:
1. **Fragment Coalescing**: Merge adjacent fragments from same replica
2. **Lazy Loading**: Only load visible text range
3. **Background Processing**: Apply operations on background thread
4. **Periodic Compaction**: Rebuild fragment tree during idle

**Implementation**:
```swift
class OptimizedCRDTBuffer {
    private let processingQueue = DispatchQueue(label: "crdt.processing")
    private var pendingOps: [Operation] = []

    func applyOperations(_ ops: [Operation]) async {
        await processingQueue.sync {
            for op in ops {
                self.applyOperationInternal(op)
            }
            self.coalesceFragments()
        }
    }

    private func coalesceFragments() {
        // Merge adjacent fragments from same replica
        var i = 0
        while i < fragments.count - 1 {
            if fragments[i].canMergeWith(fragments[i + 1]) {
                fragments[i].merge(fragments[i + 1])
                fragments.remove(at: i + 1)
            } else {
                i += 1
            }
        }
    }
}
```

### Challenge 3: Network Reliability

**Problem**: Mobile networks have variable latency and frequent disconnections

**Solutions**:
1. **Exponential Backoff**: Retry with increasing delays
2. **Operation Queue**: Queue edits locally, sync when reconnected
3. **Heartbeat**: Detect connection loss quickly (1-second ping)
4. **Delta Sync**: Only send operations since last known version

**Implementation**:
```swift
class ReliableRPCClient {
    private let reconnectStrategy = ExponentialBackoff(
        initial: 0.5,
        max: 30.0,
        multiplier: 2.0
    )

    func sendWithRetry<T>(_ message: T) async throws -> Response {
        var attempt = 0
        while true {
            do {
                return try await send(message)
            } catch let error as NetworkError {
                attempt += 1
                let delay = reconnectStrategy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await reconnect()
            }
        }
    }
}
```

### Challenge 4: Background Execution Limits

**Problem**: iOS suspends apps after ~30 seconds in background

**Solutions**:
1. **Background Fetch**: Periodically sync threads (system-scheduled)
2. **Push Notifications**: Notify user of updates, fetch on open
3. **URLSession Background**: Long-running downloads/uploads
4. **Quick Sync**: Prioritize metadata over full content

**Implementation**:
```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            let hasNewData = try await threadManager.syncThreadMetadata()
            completionHandler(hasNewData ? .newData : .noData)
        }
    }
}
```

### Challenge 5: Protocol Compatibility

**Problem**: Zed's RPC protocol evolves, iOS app must stay compatible

**Solutions**:
1. **Version Negotiation**: Send iOS app version in initialize
2. **Feature Detection**: Check server capabilities before using
3. **Graceful Degradation**: Fall back if feature unavailable
4. **Auto-Update**: Prompt user to update app if too old

**Implementation**:
```swift
struct ClientCapabilities: Codable {
    let protocolVersion: String = "1.0"
    let appVersion: String = Bundle.main.version
    let features: [String] = ["crdt_v2", "acp_v0.7", "terminal"]
}

func initialize() async throws {
    let response = try await rpc.initialize(capabilities: ClientCapabilities())

    if response.protocolVersion < minimumSupportedVersion {
        throw CompatibilityError.serverTooOld
    }

    if response.protocolVersion > maximumSupportedVersion {
        // Show update prompt to user
        throw CompatibilityError.clientTooOld
    }

    // Enable features based on server capabilities
    self.supportedFeatures = response.features
}
```

---

## 7. API Design

### 7.1 Collaboration Server Extensions

**New Endpoints** (to be added to collab server):

```rust
// Thread Sync API (to be implemented in collab crate)

// List user's threads
GET /api/v1/threads
Response: {
    "threads": [
        {
            "id": "uuid",
            "title": "string",
            "thread_type": "text" | "coding",
            "updated_at": "timestamp",
            "summary": "string"
        }
    ]
}

// Get full thread
GET /api/v1/threads/{id}
Response: {
    "id": "uuid",
    "thread_type": "text" | "coding",
    "data": "base64(compressed_json)",
    "updated_at": "timestamp"
}

// Update thread
PUT /api/v1/threads/{id}
Body: {
    "data": "base64(compressed_json)",
    "updated_at": "timestamp"
}
Response: { "success": true }

// Delete thread
DELETE /api/v1/threads/{id}
Response: { "success": true }

// Watch for updates (WebSocket extension)
SUBSCRIBE thread_updates
Event: {
    "thread_id": "uuid",
    "updated_at": "timestamp",
    "event_type": "created" | "updated" | "deleted"
}
```

**Implementation** (in `/home/user/zed/crates/collab/src/api.rs`):

```rust
// Thread sync routes
pub fn threads_routes(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/threads", get(list_threads))
        .route("/threads/:id", get(get_thread))
        .route("/threads/:id", put(update_thread))
        .route("/threads/:id", delete(delete_thread))
        .with_state(state)
}

async fn list_threads(
    Extension(user): Extension<User>,
    State(state): State<Arc<AppState>>,
) -> Result<Json<ThreadListResponse>> {
    // Query user's threads from database
    let threads = state.db.get_user_threads(user.id).await?;
    Ok(Json(ThreadListResponse { threads }))
}
```

### 7.2 iOS SDK

**Public API** for iOS developers:

```swift
// Main SDK Entry Point
public class ZedKit {
    public static let shared = ZedKit()

    public var threadManager: ThreadManager { get }
    public var collaborationClient: CollaborationClient { get }
    public var repositoryManager: RepositoryManager { get }

    public func initialize(accessToken: String) async throws
}

// Thread Management
public protocol ThreadManager {
    func listThreads() async throws -> [ThreadMetadata]
    func openThread(id: UUID) async throws -> Thread
    func createThread(type: ThreadType) async throws -> Thread
    func deleteThread(id: UUID) async throws
}

public protocol Thread {
    var id: UUID { get }
    var title: String { get }
    var messages: [Message] { get }

    func send(_ content: String) async throws
    func streamEvents() -> AsyncStream<ThreadEvent>
}

// Collaboration
public protocol CollaborationClient {
    func joinProject(id: UInt64) async throws -> Project
    func leaveProject(id: UInt64) async throws
    func observeCollaborators() -> AsyncStream<[Collaborator]>
}

public protocol Project {
    var id: UInt64 { get }
    var worktrees: [Worktree] { get }
    var collaborators: [Collaborator] { get }

    func openBuffer(path: String) async throws -> Buffer
    func observeChanges() -> AsyncStream<ProjectEvent>
}

public protocol Buffer {
    var id: UInt64 { get }
    var text: String { get }

    func edit(range: Range<Int>, text: String) async throws
    func observeEdits() -> AsyncStream<EditEvent>
}
```

---

## 8. Security & Privacy Considerations

### 8.1 Authentication

**OAuth Flow**:
```
1. iOS app opens Safari
2. User authenticates with GitHub
3. Zed server issues access_token
4. Token stored in iOS Keychain
5. Token used for WebSocket auth
```

**Token Management**:
```swift
class TokenManager {
    private let keychain = KeychainSwift()

    func storeToken(_ token: String) {
        keychain.set(token, forKey: "zed.access_token", withAccess: .accessibleAfterFirstUnlock)
    }

    func getToken() -> String? {
        keychain.get("zed.access_token")
    }

    func deleteToken() {
        keychain.delete("zed.access_token")
    }
}
```

### 8.2 Data Encryption

**At Rest**:
- SQLite encrypted with SQLCipher
- File encryption via iOS Data Protection API
- Keychain for sensitive data (tokens, keys)

**In Transit**:
- WSS (WebSocket Secure) for all server communication
- TLS 1.3 minimum
- Certificate pinning for collab.zed.dev

### 8.3 Permission Model

**iOS Permissions**:
- Network access (required)
- File access (for local repositories)
- Push notifications (optional)
- Background refresh (optional)

**Zed Permissions** (inherited from desktop):
- Project access: read/write based on collaboration role
- Channel membership: determined by server
- Agent tools: user must authorize each tool call

### 8.4 Privacy

**Data Collection** (minimal):
- User ID and email (from GitHub OAuth)
- Thread metadata (titles, timestamps)
- Usage analytics (opt-in)

**Data Storage**:
- Local: iOS device + iCloud (encrypted)
- Server: collab.zed.dev (for sync only)
- Retention: Deleted when user removes thread

**Third-Party**:
- GitHub (OAuth only)
- Apple (iCloud, push notifications)
- No advertising or tracking SDKs

---

## 9. Future Enhancements

### 9.1 Voice-Driven Agent Interaction

**Vision**: Talk to your agent from phone

**Implementation**:
```swift
class VoiceAgentController {
    private let speechRecognizer = SFSpeechRecognizer()
    private let speechSynthesizer = AVSpeechSynthesizer()

    func startListening() async throws {
        let transcript = try await speechRecognizer.transcribe()
        let response = try await thread.send(transcript)
        speechSynthesizer.speak(response.text)
    }
}
```

### 9.2 Watch App Companion

**Use Cases**:
- View thread notifications
- Quick voice commands
- Monitor agent progress

### 9.3 iPad Multitasking

**Features**:
- Split view: Thread chat + File browser
- Slide Over: Quick thread access
- Drag & Drop: Add files to thread context

### 9.4 Siri Shortcuts

**Examples**:
- "Continue my last coding thread"
- "Ask Zed to refactor this file"
- "Show me what my desktop agent is doing"

### 9.5 Live Activities

**Integration**:
- Show agent execution progress in Dynamic Island
- Display tool calls in Lock Screen widget
- Quick actions: Approve/Reject tool calls

---

## 10. Success Metrics

### 10.1 Technical Metrics

- **CRDT Convergence**: 100% convergence in random edit tests
- **Sync Latency**: <500ms for operations between iOS and Desktop
- **Offline Queue**: Successfully sync 100+ queued operations
- **Memory Usage**: <50MB for typical thread (1000 messages)
- **Battery Impact**: <2% per hour of background sync

### 10.2 User Experience Metrics

- **Thread Continuity**: 95% of threads opened on both devices within 24 hours
- **Self-Collaboration**: 50% of users try editing their own project from iOS
- **Agent Usage**: 80% of coding threads include agent interactions from iOS
- **Satisfaction**: 4.5+ stars on App Store

### 10.3 Adoption Metrics

- **Beta Users**: 1000+ testers in first month
- **Active Users**: 50% weekly active (open app at least once per week)
- **Retention**: 60% return after 30 days
- **Thread Creation**: Average 3 new threads per user per week

---

## 11. Development Timeline Summary

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| 1: Foundation | 2 weeks | Thread viewing |
| 2: Collaboration | 2 weeks | Server connection |
| 3: CRDT | 2 weeks | Real-time editing |
| 4: Agent | 2 weeks | Agent interaction |
| 5: Repository | 2 weeks | File access |
| 6: Self-Collab | 2 weeks | Desktop integration |
| 7: Polish | 2 weeks | Production ready |
| **Total** | **14 weeks** | **App Store launch** |

---

## 12. Next Steps

### Immediate Actions

1. **Validate Architecture**: Review this plan with Zed team
2. **Setup iOS Project**: Create Xcode project with SPM dependencies
3. **Implement Phase 1**: Start with thread storage and basic UI
4. **Add Server Endpoints**: Implement thread sync API in collab crate

### Research Questions

1. **ACP Remote Execution**: Can ACP agents execute on server for iOS clients?
2. **CRDT Optimization**: What's the max fragment count before performance degrades on iOS?
3. **Battery Impact**: How much battery does WebSocket keepalive consume?
4. **App Store Review**: Will Apple approve an app that executes code via agents?

### Open Decisions

1. **UI Framework**: SwiftUI vs UIKit (Recommendation: SwiftUI)
2. **Database**: CoreData vs SQLite (Recommendation: SQLite)
3. **Networking**: URLSession vs third-party (Recommendation: URLSession)
4. **Protobuf**: Swift Protobuf vs manual coding (Recommendation: Swift Protobuf)

---

## Conclusion

This plan outlines a comprehensive strategy for iOS-Zed interoperability that leverages Zed's strengths (CRDT, collaboration, agents) while respecting iOS constraints. The phased approach allows for incremental delivery and validation, with clear technical solutions to anticipated challenges.

The unique differentiator - self-collaboration across devices - provides compelling value without requiring full Zed reimplementation on iOS. Users can seamlessly continue work between desktop and mobile, with agents as the primary interaction model on mobile.

**Next**: Begin Phase 1 implementation of core data layer and thread management.
