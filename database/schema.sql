
-- Personal AI Assistant
-- Core business database schema
-- Run assistant/database/auth.sql first.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Buyer and seller profiles
CREATE SEQUENCE customer_number_seq START 1001;

CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_number BIGINT NOT NULL
        UNIQUE DEFAULT nextval('customer_number_seq'),

    profile_role TEXT NOT NULL
        CHECK (profile_role IN ('buyer', 'seller')),

    business_name TEXT NOT NULL,
    phone TEXT,
    exact_address TEXT,
    business_type TEXT,

    region_number SMALLINT
        CHECK (region_number BETWEEN 1 AND 5),

    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('needs_review', 'verified', 'rejected')),

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),

    notes TEXT,

    created_by BIGINT REFERENCES assistant_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX contacts_phone_idx ON contacts(phone);
CREATE INDEX contacts_region_idx ON contacts(region_number);
CREATE INDEX contacts_role_idx ON contacts(profile_role);

-- 2. Prevent duplicate buyer phone numbers
CREATE UNIQUE INDEX contacts_buyer_phone_unique
ON contacts(phone)
WHERE profile_role = 'buyer' AND phone IS NOT NULL;

-- 3. Purchase and sale transactions
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    operation_type TEXT NOT NULL
        CHECK (operation_type IN ('buy', 'sell')),

    contact_id UUID NOT NULL REFERENCES contacts(id),

    transaction_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    performed_by BIGINT REFERENCES assistant_users(id),
    recorded_by BIGINT REFERENCES assistant_users(id),

    weight_kg NUMERIC(14,3) NOT NULL
        CHECK (weight_kg > 0),

    purchase_price_per_kg NUMERIC(16,2)
        CHECK (purchase_price_per_kg IS NULL OR purchase_price_per_kg >= 0),

    sale_price_per_kg NUMERIC(16,2)
        CHECK (sale_price_per_kg IS NULL OR sale_price_per_kg >= 0),

    total_amount NUMERIC(20,2)
        GENERATED ALWAYS AS (
            weight_kg *
            CASE
                WHEN operation_type = 'buy'
                    THEN purchase_price_per_kg
                ELSE sale_price_per_kg
            END
        ) STORED,

    payment_method TEXT,
    payment_status TEXT,
    delivery_status TEXT,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'cancelled')),

    notes TEXT
);

CREATE INDEX transactions_date_idx ON transactions(transaction_at);
CREATE INDEX transactions_contact_idx ON transactions(contact_id);
CREATE INDEX transactions_type_idx ON transactions(operation_type);
CREATE INDEX transactions_status_idx ON transactions(status);

-- 4. Incoming text messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id BIGINT REFERENCES assistant_users(id),
    message_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    related_transaction_id UUID REFERENCES transactions(id),
    processing_status TEXT NOT NULL DEFAULT 'received'
        CHECK (processing_status IN ('received', 'processed', 'needs_review'))
);

-- 5. Audit history
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id BIGINT REFERENCES assistant_users(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    action TEXT NOT NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Contact follow-ups
CREATE TABLE contact_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES contacts(id),
    due_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'completed', 'cancelled')),
    created_by BIGINT REFERENCES assistant_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Five business regions
CREATE TABLE business_regions (
    region_number SMALLINT PRIMARY KEY
        CHECK (region_number BETWEEN 1 AND 5),
    region_name TEXT NOT NULL,
    boundary_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
