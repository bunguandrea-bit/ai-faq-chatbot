# Demo "Cantina Bricco Alto"

Variante di settore di `ai-faq-chatbot` (cantina con visite e degustazioni): una demo pronta per clienti di hospitality e wine. Cantina e dati sono inventati.

## Cosa c'è
| File | A cosa serve |
|---|---|
| `schema.sql` | Schema `cantina` con `faqs` e `handoff_requests` nel database `faq_chatbot` |
| `seed_faqs.sql` | 20 informazioni della cantina, in italiano (degustazioni, orari, prenotazioni, cani, bambini, spedizioni, tartufo…) |
| `index.html` | Sito finto della cantina con il widget in basso a destra |
| `test-cantina.ps1` | 7 domande di prova, comprese quelle del video (7/7 superate il 14/10/2026) |

Workflow n8n: **Ai_FaqChatbot_Cantina** (id `hmgYrm1iX4T3fjRN`), webhook `POST /webhook/faq-chat-cantina`. È una copia di `workflow/ai-faq-chatbot.json` con queste differenze:
- legge `cantina.faqs` e salva in `cantina.handoff_requests`;
- prompt da cantina di famiglia: risponde nella lingua dell'ospite traducendo le informazioni italiane, **non conferma mai disponibilità o prenotazioni** (le conferma Marco), usa anche le risposte negative ("spediamo solo in UE");
- messaggi di passaggio al titolare e email di avviso in italiano, a `marco@briccoalto.example` (Mailpit in locale);
- le conversazioni finiscono nella stessa tabella `conversations` del demo principale (sub-workflow condiviso).

Per tenere una copia del workflow nel repo: in n8n, menu del workflow → Download, salvarlo qui come `workflow.json`.

## Avvio
1. Container `n8n`, `postgres-n8n`, `mailpit` attivi.
2. Una volta sola: `schema.sql` e `seed_faqs.sql` (già eseguiti il 14/10/2026):
   `docker exec -i postgres-n8n psql -U n8n_user -d faq_chatbot < schema.sql`
3. Pagina: servirla da `http://localhost:8090` (configurazione `demo-cantina` in `.claude/launch.json`, oppure `npx http-server progetti/ai-faq-chatbot/demo-cantina -p 8090`). Aperta come file il browser può bloccare le chiamate a n8n.
4. Email di avviso: http://localhost:8025

## Limiti da sapere (anche durante le chiamate)
- **Ogni messaggio è a sé**: niente memoria della conversazione. Un "sì, alle 11:30" dopo una risposta non viene capito. Nel video si usano domande complete.
- Il messaggio di conferma dopo l'email è fisso in italiano e inglese.
- Il passaggio al titolare impiega 5–10 secondi (invio email): nel video si taglia l'attesa.
- WhatsApp non è collegato: solo widget per il sito.
