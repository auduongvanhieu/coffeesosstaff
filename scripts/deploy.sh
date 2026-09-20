#!/usr/bin/env bash
# Build the Flutter web app and publish it to nginx on the VPS.
#   DEPLOY_HOST (ssh alias, default hector_vps)
#   DEPLOY_DIR  (remote web root, default /var/www/dev.coffeesos.online/staff)
#   BASE_HREF   (URL prefix the app is served from, default /staff/)
# nginx block for this path lives in deploy/nginx/staff.conf (and in the BE repo's
# deploy/nginx/dev.coffeesos.online.conf, which is the full site file).
set -euo pipefail
HOST="${DEPLOY_HOST:-hector_vps}"
DIR="${DEPLOY_DIR:-/var/www/dev.coffeesos.online/staff}"
BASE_HREF="${BASE_HREF:-/staff/}"
URL="${PUBLIC_URL:-https://dev.coffeesos.online${BASE_HREF}}"
API_BASE_URL="${API_BASE_URL:-https://dev.coffeesos.online/api/v1}"
WS_URL="${WS_URL:-wss://dev.coffeesos.online/api/ws}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"
echo "==> building (base-href $BASE_HREF, api $API_BASE_URL)"
flutter pub get >/dev/null
flutter build web --release \
  --base-href "$BASE_HREF" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_URL="$WS_URL"
echo "==> publishing build/web/ -> $HOST:$DIR"
ssh "$HOST" "mkdir -p '$DIR'"
rsync -az --delete build/web/ "$HOST:$DIR/"
echo "==> done: $URL"
curl -fsS --max-time 10 -o /dev/null -w "    HTTP %{http_code}\n" "$URL"
