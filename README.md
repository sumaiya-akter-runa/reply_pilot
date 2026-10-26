<div align="center">

# ReplyPilot AI

**FastAPI REST API for ReplyPilot AI, which helps Facebook sellers reply faster and track customers, orders, stock and follow-ups.**

![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)

[Flutter App Repository](https://github.com/sumaiya-akter-runa/ReplyPilot_AI) · [Download APK](https://github.com/sumaiya-akter-runa/ReplyPilot_AI/releases/latest)

</div>

---

## Overview

The backend stores each seller's products, customers and orders, and asks the Grok API to write replies.

> **Prices and stock come from the database. The AI only writes the language.**
> If an AI reply contains a number that does not match the data, it is flagged for the seller.

## Features

- **Auth:** register, login, refresh, JWT, Argon2 password hashing
- **Products:** size variants, stock quantity, low-stock threshold
- **Customers (leads):** status (new, interested, follow-up, ordered, lost), saved messages, reminder date
- **Orders:** stock decreases on create, cancel restores stock, delete supported
- **AI:** reply, refine, follow-up draft, order-fill from a message, number-guard
- **Usage limit:** monthly AI limit checked on the server, returns `429` when exceeded
- **Dashboard:** summary for the Home screen
- **FAQs and business setup**

## Project Structure

```
app/
├── main.py            App entry point
├── config.py          Environment settings
├── database.py        Database engine and session
├── deps.py            Shared dependencies (current user)
├── models.py          SQLAlchemy tables
├── schemas.py         Pydantic request/response models
├── security.py        JWT and password hashing
├── routers/           auth, business, products, faqs, leads, orders, dashboard, ai
└── services/          ai_service, order_service, usage_service
tests/                 API and order-delete tests
Dockerfile
requirements.txt
```

## Database Tables

`users`, `faqs`, `leads`, `messages`, `products`, `product_variants`, `orders`, `order_items`, `usage_records` (plus the business table).

## Run Locally

```bash
docker compose up -d --build
```

- API: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

## Environment Variables

| Name | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (`postgresql+psycopg://...`) |
| `SECRET_KEY` | JWT signing key |
| `GROK_API_KEY` | Grok API key |
| `GROK_MODEL` | Grok model name |
| `AI_PROVIDER` | `grok` |

Never commit your `.env` file.

## Run Tests

```bash
pytest
```

## Deployment

Docker container on **Render**, PostgreSQL on **Neon**.
Live URL: `https://replypilot-backend-recc.onrender.com`

## Tech Stack

FastAPI · SQLAlchemy · PostgreSQL · psycopg 3 · Pydantic · Docker · Grok API

## Known Limitations

- No Messenger integration yet, customer messages are pasted into the app
- No push notifications
- The free server may take up to a minute to wake after being idle

## Future Work

- Messenger webhook (needs Meta App Review for real customers)
- Push notifications for follow-ups

## Author

**Sumaiya Akter Runa**
