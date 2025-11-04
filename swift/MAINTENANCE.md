# ZedMobile Maintenance

## Keeping in Sync with Zed Changes

### When Zed's Collaboration API Changes

If the thread API in `/crates/collab/src/api/threads.rs` changes:

1. Update models in `Sources/ZedMobile/Models/Thread.swift`
2. Update `ZedAPIClient` if endpoints change
3. Run tests: `swift test`
4. Update version in `Package.swift`

### When New Features Are Added to Zed

Monitor these Zed components for relevant changes:
- `/crates/collab/src/api/` - API endpoints
- `/crates/collab/src/db/tables/thread.rs` - Database schema
- `/crates/assistant_text_thread/` - Text thread format
- `/crates/agent/src/db.rs` - Coding thread format

### Testing Against Zed Changes

```bash
# 1. Pull latest Zed changes
git pull origin main

# 2. Check if migrations were added
ls crates/collab/migrations/

# 3. Review API changes
git diff HEAD~1 crates/collab/src/api/

# 4. Test ZedMobile against updated server
cd swift/ZedMobile
swift test
```

### Isolation Benefits

ZedMobile is in `swift/` subdirectory, which provides:
- Clean separation from Rust codebase
- Independent Swift Package Manager lifecycle
- Can be opened directly in Xcode
- Separate build artifacts
- Can have own CI/CD pipeline

### Staying Synchronized

To keep ZedMobile in sync with Zed server changes:
- Subscribe to Zed repository notifications
- Review PRs that touch `/crates/collab/src/api/`
- Run integration tests after pulling Zed changes
- Update ZedMobile models when server schema changes

## Development Workflow

### Working on ZedMobile

```bash
# Open in Xcode
cd swift/ZedMobile
open Package.swift

# Or use command line
swift build
swift test
```

### Testing with Local Zed Server

```bash
# Terminal 1: Run Zed collab server
cd crates/collab
cargo run

# Terminal 2: Test ZedMobile
cd swift/ZedMobile
swift test
```

### Committing Changes

Changes to ZedMobile and Zed can be in separate commits:

```bash
# Commit Zed changes
git add crates/collab/
git commit -m "Add new thread API endpoint"

# Commit ZedMobile changes
git add swift/ZedMobile/
git commit -m "Update ZedMobile for new API"
```

Or in same commit if tightly coupled:

```bash
git add crates/collab/ swift/ZedMobile/
git commit -m "Add thread sharing API and iOS client support"
```
