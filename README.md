# Group Chat Web App + LLM Bot

FastAPI + MySQL + vanilla HTML/JS group chat with LLM bot (OpenAI-compatible server such as self-hosted Llama 3 via llama.cpp).

## Quick Start (Dev)

```bash
# 1) MySQL
- Create database in MySQL

CREATE DATABASE groceryshopperai CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON groceryshopperai.* TO 'chatuser'@'localhost';
FLUSH PRIVILEGES;

- Load GroceryDataset.csv
cd backend
python load_groceries.csv

# 2) Backend
cd backend
python -m venv .venv && source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# copy env and edit values
cp ../.env.example ../.env

# 3) Run app
uvicorn app:app --host 0.0.0.0 --port 8000
```

Open http://localhost:8000

LLM endpoint defaults to http://localhost:8001/v1 (llama.cpp server). Set `LLM_API_BASE`, `LLM_MODEL`, `LLM_API_KEY` if needed in `.env`.
