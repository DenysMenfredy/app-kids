#!/usr/bin/env bash
#
# Local backend for development.
#
# Runs the Auth, Firestore and Functions emulators under the throwaway
# project `demo-letrando` — the `demo-` prefix means Firebase tooling can
# never reach a real project from here, so no credentials are involved.
#
# Emulator data is kept in .emulator-data/ between runs, and the curriculum
# is seeded automatically the first time.
#
#   ./dev.sh              start the emulators (Ctrl-C to stop)
#   ./dev.sh --reseed     re-import backend/seed/ into a fresh database
#
# Then run the app against it:
#   flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PROJECT="demo-letrando"
DATA_DIR="$ROOT/.emulator-data"
FIRESTORE_PORT=8080

FIREBASE_BIN="$(command -v firebase || true)"
if [ -z "$FIREBASE_BIN" ]; then
  FIREBASE_BIN="$ROOT/test/rules/node_modules/.bin/firebase"
fi
if [ ! -x "$FIREBASE_BIN" ]; then
  echo "firebase-tools not found. Install it with:" >&2
  echo "  npm install --prefix test/rules" >&2
  exit 1
fi

if [ "${1:-}" = "--reseed" ]; then
  echo "==> Clearing emulator data"
  rm -rf "$DATA_DIR"
fi

# The emulator silently falls back to whatever node is on PATH, so a mismatch
# here means local behaviour can differ from the deployed runtime.
REQUIRED_NODE="$(sed -n 's/.*"node": "\([0-9]*\)".*/\1/p' functions/package.json)"
CURRENT_NODE="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$CURRENT_NODE" != "$REQUIRED_NODE" ]; then
  echo "!! Running Node $CURRENT_NODE, but the functions target Node $REQUIRED_NODE."
  echo "   The emulator will fall back to Node $CURRENT_NODE, so what you see"
  echo "   locally may not match production. Fix with:  nvm use"
  echo
fi

echo "==> Building Cloud Functions"
npm --prefix functions run build

# Refresh committed content versions, including executable story lessons,
# without touching parent, child or progress records in existing exports.
SEED_ARGS=()
if [ -f "$DATA_DIR/firebase-export-metadata.json" ]; then
  SEED_ARGS=(--only books,bookContents,lessons,activities,stories)
fi
(
  for _ in $(seq 1 60); do
    if curl -sf "http://localhost:${FIRESTORE_PORT}/" >/dev/null 2>&1; then
      echo "==> Seeding published demo content into the emulator"
      FIRESTORE_EMULATOR_HOST="localhost:${FIRESTORE_PORT}" \
        npm --prefix functions run seed -- --project "$PROJECT" "${SEED_ARGS[@]}"
      exit 0
    fi
    sleep 1
  done
  echo "!! Firestore emulator never came up; seed skipped." >&2
) &

echo "==> Starting emulators (project: $PROJECT)"
echo "    Emulator UI: http://localhost:4000"
exec "$FIREBASE_BIN" emulators:start \
  --only auth,firestore,functions \
  --project "$PROJECT" \
  --import "$DATA_DIR" \
  --export-on-exit "$DATA_DIR"
