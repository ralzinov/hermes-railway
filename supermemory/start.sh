#!/bin/bash
set -e

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "[supermemory] ERROR: OPENROUTER_API_KEY is required (LLM extraction for memory pipeline)." >&2
  exit 1
fi
if [ -z "${SUPERMEMORY_API_KEY:-}" ]; then
  echo "[supermemory] ERROR: SUPERMEMORY_API_KEY is required (shared with hermes service)." >&2
  exit 1
fi

export SUPERMEMORY_DATA_DIR="${SUPERMEMORY_DATA_DIR:-/data}"
mkdir -p "$SUPERMEMORY_DATA_DIR"

export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://openrouter.ai/api/v1}"
export OPENAI_API_KEY="${OPENROUTER_API_KEY}"
export OPENAI_MODEL="${OPENAI_MODEL:-google/gemini-3.1-flash-lite}"

export PORT="${PORT:-6767}"

echo "[supermemory] API on :${PORT}" >&2
exec supermemory-server
