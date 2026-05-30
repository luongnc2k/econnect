#!/usr/bin/env bash
# Chay Flutter client kem cac --dart-define FCM_* lay tu client/.env.fcm.
# Su dung: tu thu muc client/, chay `./scripts/run-dev.sh [tham so flutter run them]`
# Vi du: `./scripts/run-dev.sh -d emulator-5554`

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$CLIENT_DIR/.env.fcm"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[run-dev] Thieu $ENV_FILE. Copy tu .env.fcm.example va dien gia tri tu Firebase Console." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

cd "$CLIENT_DIR"
exec flutter run \
  --dart-define=FCM_API_KEY="${FCM_API_KEY:-}" \
  --dart-define=FCM_PROJECT_ID="${FCM_PROJECT_ID:-}" \
  --dart-define=FCM_MESSAGING_SENDER_ID="${FCM_MESSAGING_SENDER_ID:-}" \
  --dart-define=FCM_ANDROID_APP_ID="${FCM_ANDROID_APP_ID:-}" \
  --dart-define=FCM_IOS_APP_ID="${FCM_IOS_APP_ID:-}" \
  --dart-define=FCM_IOS_BUNDLE_ID="${FCM_IOS_BUNDLE_ID:-}" \
  --dart-define=FCM_STORAGE_BUCKET="${FCM_STORAGE_BUCKET:-}" \
  "$@"
