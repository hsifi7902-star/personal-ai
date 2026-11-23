
-- Security foundation
-- Run after auth.sql and schema.sql.

CREATE SCHEMA IF NOT EXISTS app_private;

CREATE OR REPLACE FUNCTION app_private.current_user_id()
RETURNS BIGINT
LANGUAGE SQL STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::BIGINT;
$$;

CREATE OR REPLACE FUNCTION app_private.current_user_role()
RETURNS TEXT
LANGUAGE SQL STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_role', true), '');
$$;

CREATE OR REPLACE FUNCTION app_private.is_manager()
RETURNS BOOLEAN
LANGUAGE SQL STABLE
AS $$
    SELECT COALESCE(app_private.current_user_role() = 'manager', FALSE);
$$;

ALTER TABLE assistant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_regions ENABLE ROW LEVEL SECURITY;

ALTER TABLE assistant_users FORCE ROW LEVEL SECURITY;
ALTER TABLE contacts FORCE ROW LEVEL SECURITY;
ALTER TABLE transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE messages FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_followups FORCE ROW LEVEL SECURITY;
ALTER TABLE business_regions FORCE ROW LEVEL SECURITY;

CREATE POLICY users_read_own
ON assistant_users FOR SELECT
USING (
    id = app_private.current_user_id()
    OR app_private.is_manager()
);

CREATE POLICY users_manager_update
ON assistant_users FOR UPDATE
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

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

CREATE POLICY messages_manager_all
ON messages FOR ALL
USING (app_private.is_manager())
WITH CHECK (app_private.is_manager());

CREATE POLICY messages_collaborator_insert
ON messages FOR INSERT
WITH CHECK (
    sender_id = app_private.current_user_id()
);

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

REVOKE ALL ON SCHEMA app_private FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
