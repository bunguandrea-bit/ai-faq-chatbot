-- ai-faq-chatbot: schema (PostgreSQL 16)

CREATE TABLE IF NOT EXISTS faqs (
    id          SERIAL PRIMARY KEY,
    category    TEXT        NOT NULL,
    question    TEXT        NOT NULL,
    answer      TEXT        NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (question)
);

CREATE TABLE IF NOT EXISTS conversations (
    id               BIGSERIAL PRIMARY KEY,
    session_id       TEXT        NOT NULL,
    user_message     TEXT        NOT NULL,
    reply            TEXT        NOT NULL,
    matched_faq_ids  INT[]       NOT NULL DEFAULT '{}',
    confidence       NUMERIC(3,2),
    handoff          BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS conversations_session_idx ON conversations (session_id, created_at);

CREATE TABLE IF NOT EXISTS handoff_requests (
    id          BIGSERIAL PRIMARY KEY,
    session_id  TEXT        NOT NULL,
    email       TEXT        NOT NULL,
    message     TEXT        NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (session_id, email, message)   -- retry-safe: same request is stored once
);

-- Questions the bot could not answer: input for improving the FAQ list.
CREATE OR REPLACE VIEW unanswered_questions AS
SELECT user_message, count(*) AS times_asked, max(created_at) AS last_asked
FROM conversations
WHERE handoff
GROUP BY user_message
ORDER BY times_asked DESC, last_asked DESC;

-- Share of conversations resolved without a human, per day.
CREATE OR REPLACE VIEW daily_resolution AS
SELECT created_at::date AS day,
       count(*)                                   AS messages,
       count(*) FILTER (WHERE NOT handoff)        AS answered,
       round(100.0 * count(*) FILTER (WHERE NOT handoff) / count(*), 1) AS answered_pct
FROM conversations
GROUP BY 1
ORDER BY 1 DESC;
