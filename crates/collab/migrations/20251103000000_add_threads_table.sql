-- Add threads table for iOS sync
CREATE TABLE IF NOT EXISTS threads (
    id UUID PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    thread_type TEXT NOT NULL CHECK (thread_type IN ('text', 'coding')),
    title TEXT NOT NULL,
    summary TEXT,
    data_type TEXT NOT NULL DEFAULT 'zstd' CHECK (data_type IN ('json', 'zstd')),
    data BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_threads_user_id ON threads(user_id);
CREATE INDEX idx_threads_updated_at ON threads(updated_at DESC);
CREATE INDEX idx_threads_user_updated ON threads(user_id, updated_at DESC);
