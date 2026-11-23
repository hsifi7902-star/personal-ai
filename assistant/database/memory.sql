
-- Persistent conversation memory

CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES assistant_users(id),
    title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX conversations_user_idx
ON conversations(user_id, updated_at DESC);

CREATE TABLE conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL
        REFERENCES conversations(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL
        CHECK (sender_role IN ('user', 'assistant')),
    message_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX conversation_messages_history_idx
ON conversation_messages(conversation_id, created_at);

CREATE TABLE assistant_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT REFERENCES assistant_users(id),
    memory_category TEXT NOT NULL,
    memory_key TEXT NOT NULL,
    memory_value TEXT NOT NULL,
    source_message_id UUID REFERENCES conversation_messages(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, memory_category, memory_key)
);

CREATE INDEX assistant_memories_user_idx
ON assistant_memories(user_id, memory_category);
