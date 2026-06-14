# Bare Hermes + Supermemory — Railway Template

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) with self-hosted [Supermemory](https://supermemory.ai/docs/self-hosting/overview) on [Railway](https://railway.app). Paste two API keys at deploy time — zero post-deploy configuration.

**Two services:**

| Service | Role |
|---------|------|
| **hermes** | Agent gateway, API (`/v1/*`), dashboard — public HTTP |
| **supermemory** | Long-term memory engine — **private** networking only |

Pre-baked defaults:

- **Model:** `google/gemini-3.1-flash-lite` via OpenRouter
- **Memory:** Supermemory (`memory.provider: supermemory`)
- **MCP:** Composio
- **API:** OpenAI-compatible at `/v1/*`

## Deploy to Railway (2 services)

### 1. Create the project

**You need two services in the same Railway project.** Adding env vars to a single Hermes-only deploy will not work — Supermemory is a separate service on the private network.

Add **two services** from this repo:

| Service name | Root directory | Dockerfile |
|--------------|----------------|------------|
| `hermes` (any public name is fine) | `/` (repo root) | `Dockerfile` |
| **`supermemory`** (name must be exactly this) | `/` | `supermemory/Dockerfile` |

In Railway, set each service's **Root Directory** to the repo root, then set **Dockerfile Path** to `Dockerfile` or `supermemory/Dockerfile` respectively.

### 2. Volumes

| Service | Mount path |
|---------|------------|
| `hermes` | `/data` |
| `supermemory` | `/data` |

### 3. Networking

| Service | Networking |
|---------|------------|
| `hermes` | **Public HTTP** (Railway sets `PORT`) |
| `supermemory` | **Private only** — do not expose publicly |

### 4. Variables

Set these as **Shared Variables** (Project Settings → Shared Variables) so both services receive the same values:

| Variable | Required | Notes |
|----------|----------|-------|
| `OPENROUTER_API_KEY` | Yes | Hermes LLM + Supermemory extraction LLM |
| `COMPOSIO_MCP_KEY` | Yes | Composio MCP |
| `SUPERMEMORY_API_KEY` | Yes (auto on template) | Random per deployment — use `sm_${{secret(48, "0123456789abcdef")}}` in the template default so Railway generates it; both services share the same value |

Memory is isolated to this Hermes + Supermemory pair: each template install gets its own generated key.

Hermes connects to Supermemory at `http://supermemory.railway.internal:6767` by default (private Railway DNS). Name the supermemory service **`supermemory`**.

**Optional (Hermes):**

| Variable | Default |
|----------|---------|
| `API_SERVER_KEY` | auto-generated, logged on deploy |
| `HERMES_REF` | `v2026.6.5` (Docker build arg) |

### 5. Deploy order

Deploy **supermemory first**, confirm its logs show `[supermemory] API on :6767`, then deploy **hermes**. Hermes tries Supermemory for ~30s on boot; if it's not up yet, Hermes still starts (memory tools fail until Supermemory is healthy).

## Architecture

```
Internet → hermes ($PORT) → proxy.py
                              ├── /health, /v1/* → gateway API :8642
                              └── /* → dashboard :9119
                                    │
                                    └── memory provider → Supermemory (private :6767)
                                                              └── volume /data
```

Supermemory uses your OpenRouter key for memory extraction (same model as Hermes by default). Embeddings run locally inside the Supermemory binary.

## API usage

```bash
curl https://your-hermes.up.railway.app/health

curl -H "Authorization: Bearer $API_SERVER_KEY" \
  https://your-hermes.up.railway.app/v1/models
```

See deploy logs for `API_SERVER_KEY` if you did not set one.

## Memory tools

With Supermemory configured, Hermes exposes tools such as `supermemory_search`, `supermemory_store`, `supermemory_profile`, and `supermemory_forget`, plus automatic recall/capture each turn. Config: [`config/supermemory.json`](config/supermemory.json).

**Note:** Hermes session-end conversation ingest currently posts to Supermemory Cloud (`api.supermemory.ai`) in upstream Hermes — turn-by-turn memory via the SDK still uses your self-hosted `SUPERMEMORY_BASE_URL`. Watch [hermes-agent](https://github.com/NousResearch/hermes-agent) for self-hosted ingest fixes.

## Running locally

```bash
cp .env.example .env
# Fill OPENROUTER_API_KEY and COMPOSIO_MCP_KEY in .env, then generate a shared memory key:
echo "SUPERMEMORY_API_KEY=sm_$(openssl rand -hex 24)" >> .env
docker compose up --build
```

- Dashboard: http://localhost:8080/
- Supermemory: http://localhost:6767 (internal to compose network; not published by default)

Use the same OpenRouter + Composio keys and one shared `SUPERMEMORY_API_KEY` in `.env` (see above).

## Publishing as a Railway template

1. Deploy both services with volumes and variables as above.
2. Project **Settings → Template → Generate Template from Project**.
3. Mark `OPENROUTER_API_KEY` and `COMPOSIO_MCP_KEY` as **required shared** variables.
4. Set shared `SUPERMEMORY_API_KEY` default to `sm_${{secret(48, "0123456789abcdef")}}` (Railway generates a unique value per install).
5. Name the supermemory service **`supermemory`** (Hermes uses `http://supermemory.railway.internal:6767` by default).
6. Ensure the supermemory service has **no public domain**.

## Security

- **Hermes dashboard** is public without login at your Railway URL.
- **Supermemory** should stay on private networking only.
- **API** is protected by `API_SERVER_KEY`.
- **Supermemory API** is protected by shared `SUPERMEMORY_API_KEY` (random per deployment via Railway `secret()`).

## Updating Hermes

Bump `HERMES_REF` in the root `Dockerfile` and redeploy the hermes service.

## Credits

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by [Nous Research](https://nousresearch.com/)
- [Supermemory](https://supermemory.ai/) self-hosted binary
