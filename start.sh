#!/bin/bash
set -e

CONFIG_DIR="/app/config"
HERMES_DIR="/data/.hermes"

# ── Required deploy-time secrets (check before touching /data) ────────────────
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "[start] ERROR: OPENROUTER_API_KEY is required. Set it in Railway Variables." >&2
  exit 1
fi
if [ -z "${COMPOSIO_API_KEY:-}" ]; then
  echo "[start] ERROR: COMPOSIO_API_KEY is required. Set it in Railway Variables." >&2
  exit 1
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

export COMPOSIO_API_KEY OPENROUTER_API_KEY

# Render baked config from templates (envsubst injects secrets).
envsubst '${COMPOSIO_API_KEY}' < "$CONFIG_DIR/config.yaml.template" > "$HERMES_DIR/config.yaml"
envsubst '${OPENROUTER_API_KEY} ${API_SERVER_KEY}' < "$CONFIG_DIR/env.template" > "$HERMES_DIR/.env"
chmod 600 "$HERMES_DIR/.env"

# Clear stale gateway PID file from previous container on the persistent volume.
rm -f "$HERMES_DIR/gateway.pid"

echo "[start] Config written to $HERMES_DIR (model=google/gemini-3.1-flash-lite, composio MCP enabled)" >&2
exec python3 /app/proxy.py
