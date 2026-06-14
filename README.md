# Bare Hermes — Railway Template

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on [Railway](https://railway.app) with zero post-deploy configuration. Paste two API keys at deploy time and you're live — OpenRouter for the LLM, Composio for MCP tools.

Pre-baked defaults:

- **Model:** `google/gemini-3.1-flash-lite` via OpenRouter
- **MCP:** Composio (`https://connect.composio.dev/mcp`)
- **API:** OpenAI-compatible server at `/v1/*`
- **Dashboard:** Native Hermes web UI at `/`

No admin wizard, no cookie auth, no setup screens.

## Deploy to Railway

1. Fork or push this repo, then create a new Railway project from it (or publish as a Railway template).
2. Set **required** service variables:
   - `OPENROUTER_API_KEY` — from [OpenRouter](https://openrouter.ai/keys)
   - `COMPOSIO_API_KEY` — from [Composio](https://app.composio.dev/)
3. Attach a **volume** mounted at `/data` (persists sessions, memory, and config across redeploys).
4. Enable **HTTP** public networking on the service (Railway sets `PORT` automatically).
5. Deploy. Check deploy logs for `API_SERVER_KEY` if you didn't set one.

### Optional variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_SERVER_KEY` | auto-generated | Bearer token for `/v1/*` API calls. Use `${{ secret(32) }}` in Railway Template Composer, or read from deploy logs. |
| `HERMES_REF` | `v2026.6.5` | Hermes Agent git tag to install (Docker build arg). |

## What you get

```
Railway URL ($PORT)
├── /health          → API health check
├── /v1/*            → OpenAI-compatible API (Bearer auth)
└── /*               → Hermes dashboard (no login at proxy layer)
```

Internal processes (loopback only):

- Gateway + API server on `127.0.0.1:8642`
- Dashboard on `127.0.0.1:9119`

## API usage

After deploy, find your `API_SERVER_KEY` in Railway deploy logs (unless you set it yourself).

```bash
# Health
curl https://your-app.up.railway.app/health

# List models
curl -H "Authorization: Bearer $API_SERVER_KEY" \
  https://your-app.up.railway.app/v1/models

# Chat completion
curl -X POST https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hermes-agent",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

Point any OpenAI-compatible client at `https://your-app.up.railway.app/v1` with `Authorization: Bearer <API_SERVER_KEY>`.

## Dashboard

Open your Railway URL in a browser. The native Hermes dashboard loads directly — no login prompt from this template.

**Security note:** The dashboard is publicly reachable at your Railway URL without authentication. Anyone with the URL can access session data and key management UI. The API is protected by `API_SERVER_KEY`. For production, consider Railway private networking or placing your own auth layer in front.

## Running locally

```bash
docker build -t bare-hermes .
docker run --rm -it -p 8080:8080 \
  -e PORT=8080 \
  -e OPENROUTER_API_KEY=sk-or-... \
  -e COMPOSIO_API_KEY=comp_... \
  -v hermes-data:/data \
  bare-hermes
```

- Dashboard: `http://localhost:8080/`
- API: `http://localhost:8080/v1/` (Bearer token printed in container logs)

## Publishing as a Railway template

1. Deploy this repo once on Railway with a volume at `/data` and HTTP enabled.
2. In Railway project **Settings → Template**, click **Generate Template from Project**.
3. In Template Composer, mark `OPENROUTER_API_KEY` and `COMPOSIO_API_KEY` as **required**.
4. Optionally set `API_SERVER_KEY` default to `${{ secret(32) }}`.
5. Publish and share the template URL.

## Architecture

```
Internet → Railway $PORT → proxy.py (no auth)
                              ├── /health, /v1/* → gateway API :8642
                              └── /* + WebSockets → dashboard :9119
```

Config is rendered at boot from [`config/config.yaml.template`](config/config.yaml.template) and [`config/env.template`](config/env.template) by [`start.sh`](start.sh).

## Updating Hermes

Bump `HERMES_REF` in the Dockerfile (or pass as a Railway Docker build arg) and redeploy. See [Hermes releases](https://github.com/NousResearch/hermes-agent/releases).

## Credits

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by [Nous Research](https://nousresearch.com/)
