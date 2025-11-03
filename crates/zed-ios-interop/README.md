# Zed iOS Interop

This directory contains the iOS interoperability layer for Zed, enabling iOS devices to sync threads and collaborate with Zed desktop.

## Overview

The iOS interop consists of:

1. **Server-side API** (`/crates/collab`) - Thread sync endpoints
2. **Swift Package** (future) - iOS SDK for connecting to Zed
3. **iOS App** (future) - Native iOS companion app

## Implementation Status

### ✅ Completed

- [x] Database migration for `threads` table
- [x] Database query layer (`/crates/collab/src/db/queries/threads.rs`)
- [x] REST API endpoints for thread sync
- [x] Authentication integration
- [x] Comprehensive implementation plan (PLAN.md)

### 🚧 In Progress

- [ ] Swift package for CRDT
- [ ] iOS thread manager
- [ ] iOS collaboration client

### 📋 Planned

- [ ] iOS app UI
- [ ] Agent integration on iOS
- [ ] Repository sync
- [ ] Self-collaboration features

## API Endpoints

All endpoints require authentication via `Authorization: <user-id> <access-token>` header.

### List Threads

```
GET /threads?since=<ISO8601>
```

Returns metadata for all threads owned by the authenticated user.

### Get Thread

```
GET /threads/:id
```

Returns full thread data (base64-encoded, optionally zstd-compressed).

### Update Thread

```
PUT /threads/:id
Content-Type: application/json

{
  "thread_type": "text" | "coding",
  "title": "Thread title",
  "summary": "Optional summary",
  "data_type": "json" | "zstd",
  "data": "<base64-encoded thread data>"
}
```

### Delete Thread

```
DELETE /threads/:id
```

## Database Schema

```sql
CREATE TABLE threads (
    id UUID PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    thread_type TEXT NOT NULL CHECK (thread_type IN ('text', 'coding')),
    title TEXT NOT NULL,
    summary TEXT,
    data_type TEXT NOT NULL DEFAULT 'zstd',
    data BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);
```

## Next Steps

See [PLAN.md](/home/user/zed/PLAN.md) for detailed implementation roadmap.

Key priorities:
1. Create Swift package for CRDT implementation
2. Implement iOS thread manager using the new API
3. Build prototype iOS app
4. Test end-to-end thread sync

## Development

### Running Migration

```bash
# Apply migration
sqlx migrate run --database-url <postgres-url>
```

### Testing API Endpoints

```bash
# List threads
curl -H "Authorization: <user-id> <token>" \
  https://collab.zed.dev/threads

# Get thread
curl -H "Authorization: <user-id> <token>" \
  https://collab.zed.dev/threads/<uuid>

# Create/update thread
curl -X PUT \
  -H "Authorization: <user-id> <token>" \
  -H "Content-Type: application/json" \
  -d '{"thread_type":"text","title":"My Thread","data_type":"json","data":"<base64>"}' \
  https://collab.zed.dev/threads/<uuid>
```

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  iOS App    │◄───────►│ Collab Server │◄───────►│ Zed Desktop │
│             │  HTTPS  │               │  RPC    │             │
│ Swift SDK   │         │ Thread API    │         │  Threads    │
└─────────────┘         └──────────────┘         └─────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │  PostgreSQL  │
                        │   threads    │
                        └──────────────┘
```

## License

Same as Zed - see LICENSE
