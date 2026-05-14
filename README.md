# Black Diamond Salesforce Service

Salesforce data extraction engine for the Glynac platform. Pulls CRM data from Salesforce using the Bulk API 2.0 and feeds it into the analytics pipeline (MinIO, Kafka, ClickHouse).

## Architecture

```
BD Core Service (orchestrator)
        │
        │ HTTP + HMAC
        ▼
BD Salesforce Service (this service)
        │
        │ OAuth 2.0 JWT Bearer
        ▼
Salesforce Bulk API 2.0
        │
        ▼
MinIO / Kafka / ClickHouse
```

## What It Extracts

| Object | Description |
|--------|-------------|
| Contact | People/customers — name, email, phone |
| Account | Companies — name, industry, location |
| Opportunity | Sales deals — amount, stage, close date |
| Task | Activities — subject, status, priority |
| Lead | Potential customers — name, company, status |
| User | Salesforce users — name, email, active |
| CampaignMember | Marketing campaign participation |

## Tech Stack

- **Python 3.13** + Flask
- **Salesforce Bulk API 2.0** — large-scale async data extraction
- **OAuth 2.0 JWT Bearer** — service-to-service auth with RSA key signing
- **MinIO** — S3-compatible object storage (Parquet files)
- **Kafka** — event streaming for downstream consumers
- **Pydantic** — config validation with fail-fast startup
- **SQLAlchemy** — scan/job state persistence

## Quick Start

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure environment

```bash
cp .env.example .env
# Fill in your Salesforce credentials (see below)
```

### 3. Run the service

```bash
flask --app "app.main:create_app" run --port 5711
```

### 4. Test health endpoint

```bash
curl http://127.0.0.1:5711/api/health
```

## Salesforce Setup

You need a Salesforce Connected App with JWT Bearer flow:

1. Generate RSA key pair:
   ```bash
   openssl genrsa -traditional -out private_key_rsa.pem 2048
   openssl req -new -x509 -key private_key_rsa.pem -out public_key.crt -days 365
   ```

2. Create Connected App in Salesforce Setup:
   - Enable OAuth Settings
   - Add scopes: Full access + Perform requests at any time
   - Enable JWT Bearer Flow
   - Upload `public_key.crt`

3. Configure policies:
   - Permitted Users: Admin approved users are pre-authorized
   - IP Relaxation: Relax IP restrictions
   - Add System Administrator profile

4. Update `.env`:
   ```
   SF_CONSUMER_KEY=<your-consumer-key>
   SF_PRIVATE_KEY_PEM="-----BEGIN RSA PRIVATE KEY-----\nMIIE...\n-----END RSA PRIVATE KEY-----\n"
   SF_USERNAME=<your-salesforce-username>
   SF_LOGIN_URL=https://login.salesforce.com
   ```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | None | Health check (Nomad) |
| POST | `/api/scan/start` | HMAC | Start extraction scan |
| GET | `/api/scan/status/<id>` | HMAC | Get scan progress |
| POST | `/api/scan/cancel/<id>` | HMAC | Cancel running scan |
| POST | `/api/scan/resume/<id>` | HMAC | Resume failed scan |
| GET | `/api/scan/list` | HMAC | List scans with filters |
| POST | `/api/maintenance/cleanup` | HMAC | Purge old records |
| GET | `/api/maintenance/status` | HMAC | Dependency health |

## Start a Scan

```bash
curl -X POST http://127.0.0.1:5711/api/scan/start \
  -H "Content-Type: application/json" \
  -d '{"org_id": "my-org-123", "scan_type": "full"}'
```

Response:
```json
{
  "scan_id": "uuid-here",
  "status": "in_progress",
  "jobs": {
    "Contact": "in_progress",
    "Account": "in_progress",
    "Opportunity": "in_progress",
    "Task": "in_progress",
    "Lead": "in_progress",
    "User": "in_progress",
    "CampaignMember": "in_progress"
  }
}
```

## Project Structure

```
app/
├── main.py                  # Flask app factory
├── config.py                # Pydantic settings + validation
├── routes.py                # API endpoints
├── auth/
│   └── salesforce_auth.py   # JWT Bearer token manager
├── clients/
│   └── bulk_api_client.py   # Salesforce Bulk API 2.0
├── services/
│   ├── extraction_service.py    # Scan orchestrator
│   ├── polling_service.py       # Background job poller
│   ├── normalization_service.py # CSV → Parquet
│   ├── deduplication_service.py # Remove duplicates
│   └── maintenance_service.py   # Cleanup old scans
├── storage/
│   ├── minio_client.py      # S3-compatible upload
│   └── kafka_producer.py    # Event streaming
└── models/
    ├── scan.py              # Scan state model
    └── job.py               # SF job model
```

## Environment Variables

See `.env.example` for the full list. Key ones:

| Variable | Description |
|----------|-------------|
| `SF_CONSUMER_KEY` | Salesforce Connected App consumer key |
| `SF_PRIVATE_KEY_PEM` | RSA private key (single-line with `\n` escapes) |
| `SF_USERNAME` | Salesforce integration user |
| `SF_LOGIN_URL` | `https://login.salesforce.com` (prod) or `https://test.salesforce.com` (sandbox) |
| `MINIO_ENABLED` | Enable MinIO uploads (`true`/`false`) |
| `KAFKA_ENABLED` | Enable Kafka publishing (`true`/`false`) |

## Deployment

Deployed via Nomad on the Glynac infrastructure:
- Dev: port 5710
- Staging: port 5711
- Production: port 5712

See `nomad/` directory for HCL configs.

## License

Internal — Glynac Engineering
