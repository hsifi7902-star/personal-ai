-- Security foundation for Personal AI Assistant
-- Access is denied by default.
-- Server authentication must set app.user_id and app.user_role.

CREATE SCHEMA IF NOT EXISTS app_private;

-- Read the authenticated user's identity from the server session.
CREATE OR REPLACE FUNCTION app_private.current_user_id()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::UUID;
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

-- Enable row-level security.
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE stored_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_regions ENABLE ROW LEVEL SECURITY;

-- Remove broad access from ordinary application roles.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC;

-- Users can see only their own account.
CREATE POLICY users_read_own
ON app_users FOR SELECT
USING (id = app_private.current_user_id() OR app_private.is_manager());

-- Collaborators can register a new contact.
-- They cannot browse existing contacts.
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

-- Managers can access all transactions.
CREATE POLICY transactions_manager_all
ON transactions FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Collaborators can submit their own transactions.
CREATE POLICY transactions_collaborator_insert
ON transactions FOR INSERT
WITH CHECK (
    app_private.current_user_role() = 'collaborator'
    AND recorded_by = app_private.current_user_id()
    AND status = 'pending'
);

-- Collaborators can submit messages.
CREATE POLICY messages_manager_all
ON messages FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY messages_collaborator_insert
ON messages FOR INSERT
WITH CHECK (sender_id = app_private.current_user_id());

-- Managers control files.
CREATE POLICY files_manager_all
ON stored_files FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY files_collaborator_insert
ON stored_files FOR INSERT
WITH CHECK (uploaded_by = app_private.current_user_id());

-- Audit history is manager-only.
CREATE POLICY audit_manager_only
ON audit_log FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Follow-up reminders are manager-only.
CREATE POLICY followups_manager_only
ON contact_followups FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

-- Business region definitions are manager-only.
CREATE POLICY regions_manager_only
ON business_regions FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());
