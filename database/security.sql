
-- Personal AI Assistant
-- Database security policies
-- Run after auth.sql, schema.sql and memory.sql.
-- Execute as the database migration/table owner.

CREATE SCHEMA IF NOT EXISTS app_private;

-- 1. Current authenticated application user
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

-- 2. Internal customer lookup
-- Returns only the internal ID, never customer details.
CREATE OR REPLACE FUNCTION app_private.lookup_contact_id(
    p_customer_number BIGINT,
    p_profile_role TEXT
)
RETURNS UUID
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT c.id
    FROM public.contacts AS c
    WHERE c.customer_number = p_customer_number
      AND c.profile_role = p_profile_role
      AND c.status = 'active'
      AND c.verification_status <> 'rejected'
    LIMIT 1;
$$;

-- 3. Verify that a transaction uses the correct contact type.
-- A purchase must refer to a seller.
-- A sale must refer to a buyer.
CREATE OR REPLACE FUNCTION app_private.contact_matches_transaction(
    p_contact_id UUID,
    p_operation_type TEXT
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.contacts AS c
        WHERE c.id = p_contact_id
          AND c.status = 'active'
          AND (
              (p_operation_type = 'buy' AND c.profile_role = 'seller')
              OR
              (p_operation_type = 'sell' AND c.profile_role = 'buyer')
          )
    );
$$;

-- 4. Enable row-level security
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_regions ENABLE ROW LEVEL SECURITY;

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistant_memories ENABLE ROW LEVEL SECURITY;

-- The application must not own these tables.
-- The contacts lookup functions use the migration owner's privileges.
ALTER TABLE contacts NO FORCE ROW LEVEL SECURITY;

ALTER TABLE transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE messages FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_followups FORCE ROW LEVEL SECURITY;
ALTER TABLE business_regions FORCE ROW LEVEL SECURITY;

ALTER TABLE conversations FORCE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE assistant_memories FORCE ROW LEVEL SECURITY;

-- 5. Remove previous policies
DROP POLICY IF EXISTS contacts_manager_all ON contacts;
DROP POLICY IF EXISTS contacts_collaborator_insert ON contacts;

DROP POLICY IF EXISTS transactions_manager_all ON transactions;
DROP POLICY IF EXISTS transactions_collaborator_insert ON transactions;

DROP POLICY IF EXISTS messages_manager_all ON messages;
DROP POLICY IF EXISTS messages_collaborator_insert ON messages;

DROP POLICY IF EXISTS audit_manager_only ON audit_log;
DROP POLICY IF EXISTS followups_manager_only ON contact_followups;
DROP POLICY IF EXISTS regions_manager_only ON business_regions;

DROP POLICY IF EXISTS conversations_user_access ON conversations;
DROP POLICY IF EXISTS conversation_messages_user_access ON conversation_messages;
DROP POLICY IF EXISTS memories_user_access ON assistant_memories;

-- 6. Contacts
-- Managers can manage all contacts.
CREATE POLICY contacts_manager_all
ON contacts FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Collaborators can only create new contacts.
-- They cannot read, update or delete existing contacts.
CREATE POLICY contacts_collaborator_insert
ON contacts FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND created_by = app_private.current_user_id()
    AND verification_status = 'needs_review'
);

-- 7. Transactions
CREATE POLICY transactions_manager_all
ON transactions FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Collaborators can only submit pending transactions
-- recorded under their own user ID.
CREATE POLICY transactions_collaborator_insert
ON transactions FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND recorded_by = app_private.current_user_id()
    AND status = 'pending'
    AND contact_id IS NOT NULL
    AND app_private.contact_matches_transaction(
        contact_id,
        operation_type
    )
);

-- 8. Incoming messages
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

-- 9. Manager-only business information
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

-- 10. Conversations
-- Each user can access only their own conversations.
-- Managers can access all conversations.
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

-- 11. Conversation messages
CREATE POLICY conversation_messages_user_access
ON conversation_messages FOR ALL
USING (
    app_private.is_manager()
    OR EXISTS (
        SELECT 1
        FROM conversations AS c
        WHERE c.id = conversation_id
          AND c.user_id = app_private.current_user_id()
    )
)
WITH CHECK (
    app_private.is_manager()
    OR EXISTS (
        SELECT 1
        FROM conversations AS c
        WHERE c.id = conversation_id
          AND c.user_id = app_private.current_user_id()
    )
);

-- 12. Persistent memories
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

-- 13. Do not expose internal functions to PUBLIC by default.
REVOKE ALL ON SCHEMA app_private FROM PUBLIC;

REVOKE ALL ON FUNCTION app_private.current_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.is_manager() FROM PUBLIC;

REVOKE ALL ON FUNCTION app_private.lookup_contact_id(BIGINT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.contact_matches_transaction(UUID, TEXT) FROM PUBLIC;
