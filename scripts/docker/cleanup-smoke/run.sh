#!/usr/bin/env bash
set -euo pipefail

cd /repo

export ZOIDBERGBOT_STATE_DIR="/tmp/zoidbergbot-test"
export ZOIDBERGBOT_CONFIG_PATH="${ZOIDBERGBOT_STATE_DIR}/zoidbergbot.json"

echo "==> Build"
pnpm build

echo "==> Seed state"
mkdir -p "${ZOIDBERGBOT_STATE_DIR}/credentials"
mkdir -p "${ZOIDBERGBOT_STATE_DIR}/agents/main/sessions"
echo '{}' >"${ZOIDBERGBOT_CONFIG_PATH}"
echo 'creds' >"${ZOIDBERGBOT_STATE_DIR}/credentials/marker.txt"
echo 'session' >"${ZOIDBERGBOT_STATE_DIR}/agents/main/sessions/sessions.json"

echo "==> Reset (config+creds+sessions)"
pnpm zoidbergbot reset --scope config+creds+sessions --yes --non-interactive

test ! -f "${ZOIDBERGBOT_CONFIG_PATH}"
test ! -d "${ZOIDBERGBOT_STATE_DIR}/credentials"
test ! -d "${ZOIDBERGBOT_STATE_DIR}/agents/main/sessions"

echo "==> Recreate minimal config"
mkdir -p "${ZOIDBERGBOT_STATE_DIR}/credentials"
echo '{}' >"${ZOIDBERGBOT_CONFIG_PATH}"

echo "==> Uninstall (state only)"
pnpm zoidbergbot uninstall --state --yes --non-interactive

test ! -d "${ZOIDBERGBOT_STATE_DIR}"

echo "OK"
