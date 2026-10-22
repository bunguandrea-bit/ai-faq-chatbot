-- Demo "Cantina Bricco Alto" (cantina inventata): stesse tabelle del demo principale, in uno schema separato.
-- Le conversazioni restano nella tabella public.conversations (sub-workflow Sub_LogConversation condiviso).
CREATE SCHEMA IF NOT EXISTS cantina;

CREATE TABLE IF NOT EXISTS cantina.faqs (
    id          SERIAL PRIMARY KEY,
    category    TEXT        NOT NULL,
    question    TEXT        NOT NULL,
    answer      TEXT        NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (question)
);

CREATE TABLE IF NOT EXISTS cantina.handoff_requests (
    id          BIGSERIAL PRIMARY KEY,
    session_id  TEXT        NOT NULL,
    email       TEXT        NOT NULL,
    message     TEXT        NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (session_id, email, message)
);

GRANT USAGE ON SCHEMA cantina TO faq_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA cantina TO faq_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA cantina TO faq_user;
