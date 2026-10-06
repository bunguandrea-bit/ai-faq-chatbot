# ai-faq-chatbot

FAQ chatbot for an online shop, built on n8n. Answers the repetitive support questions instantly, in the customer's language, **only from the shop's own approved FAQ**, and hands over to a human when it is not sure.

Built as an MVP for a demo client (fictional tea shop, "Nordic Tea Co.").

## Problem
Two people handle support by email; ~70% of tickets are the same ten questions (shipping times, returns, tracking, brewing, allergens). The shop wants instant answers on the website, but a bot that invents policies is worse than no bot.

## How it works
```
Widget ──POST /webhook/faq-chat──▶ ValidateInput ─▶ LoadFaqs (PostgreSQL)
                                        │                │
                                  400 if invalid     BuildPrompt (whole FAQ catalogue)
                                                         │
                                                  gpt-4o-mini (JSON: language, faq_ids, confidence, reply)
                                                         │
                                                  ParseAnswer  ◀── rules decide
                                                         │
                                         SaveConversation ─▶ JSON reply to the widget
```
If the answer is not reliable, the bot replies with a fixed hand-off message (en/it/de/fr/es) asking for an email. A second call (`action: leave_contact`) stores the email with the unanswered question in `handoff_requests` and **emails the support team** (`NotifyTeam` node: question, customer email, Reply-To set to the customer so support just hits "reply"). The email is sent only for new requests (a repeated identical request does not notify twice) and a mail failure never blocks the customer's response: the request is already safe in the database.

### Design choices
- **The LLM proposes, the rules decide.** The reply is shown only if it cites at least one real FAQ id from the database, is non-empty and has confidence ≥ 0.6. Anything else (invalid JSON, API error, unknown ids, out-of-scope question) becomes a hand-off. The hand-off text is a fixed template, never LLM-generated.
- **No vector DB.** The whole catalogue (25 FAQs ≈ 2.5k tokens) goes in the prompt: simpler, no embeddings to keep in sync, < $0.001 per message with gpt-4o-mini. Beyond ~200 FAQs, pre-filter with pgvector.
- **FAQs live in PostgreSQL**, not in the workflow: the client edits rows (or re-runs `seed_faqs.sql` with their own text) without touching n8n.
- **Prompt-injection hardening**: customer text is passed as untrusted data in delimiters, and the fixed rules in `ParseAnswer` limit what can be shown.
- **Everything is logged** (`conversations`) with the FAQ ids used and the confidence, so any answer can be traced to its source.
- **Language**: detected from the text of the message (not from countries it mentions); the model answers in that language.

### Useful queries
```sql
SELECT * FROM unanswered_questions;   -- what to add to the FAQ next
SELECT * FROM daily_resolution;       -- % of messages answered without a human
SELECT * FROM handoff_requests WHERE status = 'open';
```

## Run it
1. `cp .env.example .env` and fill in the values.
2. `docker compose up -d` (creates the schema and loads the sample FAQs on first start).
3. In n8n: create the credentials **Postgres** (host `postgres`, DB/user/password from `.env`) and **OpenAI**, and **SMTP** (the client's mail provider; for local tests use [Mailpit](https://github.com/axllent/mailpit): `docker run -p 1025:1025 -p 8025:8025 axllent/mailpit`). Import `workflow/ai-faq-chatbot.json`, assign the credentials to the Postgres, OpenAI and NotifyTeam nodes, set the real sender/recipient addresses in `NotifyTeam`, and activate it.
4. Put your public n8n URL in `widget/index.html` (`WEBHOOK`) and paste the widget block into the site theme.
5. Test: `powershell -File examples/test-chat.ps1 -BaseUrl http://localhost:5678`

Production: put n8n behind an Nginx reverse proxy with HTTPS (Let's Encrypt/certbot) and replace `allowedOrigins: *` on the Webhook node with the shop's domain.

### API
`POST /webhook/faq-chat`
```json
{ "session_id": "abc12345", "message": "How long does delivery take?" }
→ { "status": "ok", "reply": "…", "handoff": false, "needs_contact": false, "sources": [1] }
```
```json
{ "session_id": "abc12345", "action": "leave_contact", "email": "customer@example.com" }
```

## Known limits (MVP)
- No order lookup (Shopify API is the natural phase 2; needs identity checks before showing order data).
- Each message is answered on its own: no conversation memory ("and to the UK?" will not work).
- No rate limiting on the webhook (add it in Nginx or via a bot-protection token before going public).
- The model could in theory add detail that is not in the FAQ; the prompt forbids it and the test suite checks the main cases, but there is no automatic fact check on the reply text.
- The notification address is hard-coded in the `NotifyTeam` node (and the support address in `ParseAnswer`); move both to environment variables if several shops share one instance.
- The customer is not told if the notification email failed (the request is saved and visible in `handoff_requests WHERE status = 'open'`).
