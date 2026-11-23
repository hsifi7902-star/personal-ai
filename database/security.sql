

-- Personal AI Assistant
-- Security policies
-- Run after auth.sql, schema.sql and memory.sql.

CREATE SCHEMA IF NOT EXISTS app_private;

CREATE OR REPLACE FUNCTION app_private.current_user_id()
RETURNS BIGINT
LANGUAGE SQL
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::BIGINT;
$$;

CREATE OR REPLACE FUNCTION app_private.current_user_role()
RETURNS TEXT
LANGUAGE SQL
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_role', true), '');
$$;

CREATE OR REPLACE FUNCTION app_private.is_manager()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
    SELECT COALESCE(app_private.current_user_role() = 'manager', FALSE);
$$;

-- Business data protection
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_regions ENABLE ROW LEVEL SECURITY;

ALTER TABLE contacts FORCE ROW LEVEL SECURITY;
ALTER TABLE transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE messages FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_followups FORCE ROW LEVEL SECURITY;
ALTER TABLE business_regions FORCE ROW LEVEL SECURITY;

-- Remove old policies before creating them
DROP POLICY IF EXISTS contacts_manager_all ON contacts;
DROP POLICY IF EXISTS contacts_collaborator_insert ON contacts;
DROP POLICY IF EXISTS transactions_manager_all ON transactions;
DROP POLICY IF EXISTS transactions_collaborator_insert ON transactions;
DROP POLICY IF EXISTS messages_manager_all ON messages;
DROP POLICY IF EXISTS messages_collaborator_insert ON messages;
DROP POLICY IF EXISTS audit_manager_only ON audit_log;
DROP POLICY IF EXISTS followups_manager_only ON contact_followups;
DROP POLICY IF EXISTS regions_manager_only ON business_regions;

-- Contacts
CREATE POLICY contacts_manager_all
ON contacts FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY contacts_collaborator_insert
ON contacts FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND created_by = app_private.current_user_id()
    AND verification_status = 'needs_review'
);

-- Transactions
CREATE POLICY transactions_manager_all
ON transactions FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY transactions_collaborator_insert
ON transactions FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND recorded_by = app_private.current_user_id()
    AND status = 'pending'
);

-- Incoming messages
CREATE POLICY messages_manager_all
ON messages FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY messages_collaborator_insert
ON messages FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND sender_id = app_private.current_user_id()
);

-- Manager-only records
CREATE POLICY audit_manager_only
ON audit_log FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY followups_manager_only
ON contact_followups FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY regions_manager_only
ON business_regions FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Conversation memory
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations FORCE ROW LEVEL SECURITY;

ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages FORCE ROW LEVEL SECURITY;

ALTER TABLE assistant_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistant_memories FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversations_user_access ON conversations;
DROP POLICY IF EXISTS conversation_messages_user_access ON conversation_messages;
DROP POLICY IF EXISTS memories_user_access ON assistant_memories;

CREATE POLICY conversations_user_access
ON conversations FOR ALL
USING (
    app_private.is_manager()
    OR user_id = app_private.current_user_id()
)
WITH CHECK (
    app_private.is_manager()
    OR user_id = app_private.current_user_id()
);

CREATE POLICY conversation_messages_user_access
ON conversation_messages FOR ALL
USING (
    app_private.is_manager()
    OR EXISTS (
        SELECT 1
        FROM conversations c
        WHERE c.id = conversation_id
          AND c.user_id = app_private.current_user_id()
    )
)
WITH CHECK (
    app_private.is_manager()
    OR EXISTS (
        SELECT 1
        FROM conversations c
        WHERE c.id = conversation_id
          AND c.user_id = app_private.current_user_id()
    )
);

CREATE POLICY memories_user_access
ON assistant_memories FOR ALL
USING (
    app_private.is_manager()
    OR user_id = app_private.current_user_id()
)
WITH CHECK (
    app_private.is_manager()
    OR user_id = app_private.current_user_id()
);
