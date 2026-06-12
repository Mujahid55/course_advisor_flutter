# Course Advisor

An AI-powered academic assistant that helps university students understand their course
syllabus, get personalized study guidance, and find high-quality textbooks and references.
The project consists of a Flutter client app and a FastAPI backend.

## Project structure

```
course_advisor_flutter/
├── Backend/    FastAPI backend (chat, auth, file upload, admin & analytics APIs)
└── Flutter/    Flutter client (chat UI, login/register, admin dashboard)
```

## Backend

Built with FastAPI, SQLAlchemy (async, MySQL), JWT auth, and OpenAI for chat completions
and embeddings (RAG over uploaded syllabus documents).

### Setup

```bash
cd Backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then fill in OPENAI_API_KEY, JWT_SECRET_KEY, MySQL credentials, etc.
```

### Run

```bash
uvicorn main:app --reload
```

The API serves on `http://localhost:8000` by default. On startup it creates the database
tables and seeds a default admin account: `admin@courseadvisor.com` / `Admin@12345`.

### Key configuration (`.env`)

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Required — used for chat completions and embeddings |
| `OPENAI_MODEL`, `MAX_TOKENS`, `TEMPERATURE` | Chat completion tuning |
| `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE` | Database connection |
| `JWT_SECRET_KEY`, `JWT_ALGORITHM`, `JWT_EXPIRE_MINUTES` | Auth token settings |
| `SESSION_TTL_SECONDS`, `SESSION_CLEANUP_INTERVAL`, `MAX_HISTORY_TURNS` | Chat session lifecycle |
| `MAX_FILE_BYTES` | Max upload size for syllabus documents |
| `CORS_ORIGINS` | Allowed origins (JSON list) |
| `EMBEDDING_MODEL_NAME` | Embedding model used for RAG search |

### API routes

- `health` — service health check
- `auth` — register/login (JWT)
- `chat` — chat sessions with the AI advisor
- `upload` — syllabus document upload & indexing
- `users` — user profile management
- `admin` — admin user/account management
- `analytics` — usage statistics

## Flutter app

A cross-platform Flutter client (Android, iOS, web, desktop) with chat, authentication,
and an admin dashboard.

### Setup & run

```bash
cd Flutter
flutter pub get
flutter run
```

The app points to the backend at `http://localhost:8000` by default
(`http://10.0.2.2:8000` on the Android emulator) — see `lib/config.dart` to change it.

### Key screens

- `login_screen` / `register_screen` — authentication
- `chat_screen` — main AI advisor chat experience
- `admin_dashboard_screen` (`admin_overview_tab`, `admin_users_tab`, `admin_activity_tab`) — admin tools
# course_advisor_flutter
# course_advisor_flutter
# course_advisor_flutter
# course_advisor_flutter
# course_advisor_flutter
