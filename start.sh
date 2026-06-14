#!/bin/bash
set -e

CONFIG_DIR="/app/config"
HERMES_DIR="/data/.hermes"

# ── Required deploy-time secrets (check before touching /data) ────────────────
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "[start] ERROR: OPENROUTER_API_KEY is required. Set it in Railway Variables." >&2
  exit 1
fi
if [ -z "${COMPOSIO_MCP_KEY:-}" ]; then
  echo "[start] ERROR: COMPOSIO_MCP_KEY is required. Set it in Railway Variables." >&2
  exit 1
fi
export SUPERMEMORY_BASE_URL="${SUPERMEMORY_BASE_URL:-http://supermemory.railway.internal:6767}"

if [ -z "${SUPERMEMORY_API_KEY:-}" ]; then
  echo "[start] ERROR: SUPERMEMORY_API_KEY is required (shared with supermemory service)." >&2
  echo "[start]   Railway template: sm_\${{secret(48, \"0123456789abcdef\")}}" >&2
  exit 1
fi

# Wait briefly for Supermemory (starts in parallel on Railway). Don't block the whole deploy.
_sm_url="${SUPERMEMORY_BASE_URL%/}/health"
echo "[start] Supermemory URL: ${SUPERMEMORY_BASE_URL}" >&2
echo "[start] Checking Supermemory at ${_sm_url} ..." >&2
_sm_ready=0
for _i in $(seq 1 15); do
  if curl -sf "$_sm_url" >/dev/null 2>&1; then
    echo "[start] Supermemory API is up" >&2
    _sm_ready=1
    break
  fi
  if [ $((_i % 5)) -eq 0 ]; then
    echo "[start] Still waiting for Supermemory (attempt ${_i}/15) ..." >&2
  fi
  sleep 2
done
if [ "$_sm_ready" -eq 0 ]; then
  echo "[start] WARN: Supermemory not reachable yet — starting Hermes anyway." >&2
  echo "[start]   Need a second Railway service named 'supermemory' (Dockerfile: supermemory/Dockerfile," >&2
  echo "[start]   private networking, volume /data, shared OPENROUTER_API_KEY + SUPERMEMORY_API_KEY)." >&2
  echo "[start]   Memory tools will fail until Supermemory is healthy." >&2
fi

# Create every directory hermes expects on the persistent volume.
mkdir -p "$HERMES_DIR"/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,workspace,skins,plans,home}

# Stamp install method so hermes treats this as an immutable container image.
printf 'docker\n' > "$HERMES_DIR/.install_method"

# Generate API bearer token if not provided (for external service access).
if [ -z "${API_SERVER_KEY:-}" ]; then
  API_SERVER_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
  export API_SERVER_KEY
  echo "[start] Generated API_SERVER_KEY (save this for API clients): ${API_SERVER_KEY}" >&2
else
  echo "[start] Using provided API_SERVER_KEY" >&2
fi

export COMPOSIO_MCP_KEY OPENROUTER_API_KEY SUPERMEMORY_API_KEY SUPERMEMORY_BASE_URL

# Render baked config from templates (envsubst injects secrets).
envsubst '${COMPOSIO_MCP_KEY}' < "$CONFIG_DIR/config.yaml.template" > "$HERMES_DIR/config.yaml"
envsubst '${OPENROUTER_API_KEY} ${API_SERVER_KEY} ${SUPERMEMORY_API_KEY} ${SUPERMEMORY_BASE_URL}' \
  < "$CONFIG_DIR/env.template" > "$HERMES_DIR/.env"
chmod 600 "$HERMES_DIR/.env"

cp "$CONFIG_DIR/supermemory.json" "$HERMES_DIR/supermemory.json"
chmod 600 "$HERMES_DIR/supermemory.json"

# Clear stale gateway PID file from previous container on the persistent volume.
rm -f "$HERMES_DIR/gateway.pid"

echo "[start] Config written (model=google/gemini-3.1-flash-lite, composio MCP, supermemory memory)" >&2
exec python3 /app/proxy.py
