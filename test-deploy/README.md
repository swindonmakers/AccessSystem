# Local Production Test Environment

This directory contains configuration and scripts to run the production Docker container locally with a full PostgreSQL database.

## 🚀 Quick Start

1. **Run the start script:**
   ```bash
   ./start.sh
   ```
   This will:
   - Build the production image
   - Start containers (App + Postgres 17)
   - Deploy the database schema
   - Seed test data (Tiers + "The Door")

2. **Access the App:**
   - [http://localhost:3000/login](http://localhost:3000/login)
   - [http://localhost:3000/register](http://localhost:3000/register)

## 🛑 Stop & Cleanup

```bash
docker compose down -v
```

## 📂 Structure

- **`docker-compose.yaml`**: Orchestrates valid Prod container + Postgres DB.
- **`config/accesssystem_api_local.conf`**: Test-specific config (connects to local DB, dummy keys).
- **`seed_data.sql`**: Initial data needed for the app to function (Membership Tiers, Tools).
- **`start.sh`**: Automates build, deploy, and seed steps.
