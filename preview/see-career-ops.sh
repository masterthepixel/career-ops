#!/usr/bin/env bash
# Preview the career-ops web UI on this machine with SAMPLE data only.
# Loopback only, telemetry off, no Chromium download, nothing of yours is read.
# Usage: bash see-career-ops.sh [dir]     (PORT=3000 by default; Ctrl-C stops it)
set -euo pipefail
DIR="${1:-$HOME/career-ops-preview}"
PORT="${PORT:-3000}"
REPO="https://github.com/masterthepixel/career-ops.git"

command -v node >/dev/null || { echo "node not found (need >= 22.6)"; exit 1; }
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=6)?0:1)' \
  || { echo "need node >= 22.6, have $(node -v)"; exit 1; }

mkdir -p "$DIR"; cd "$DIR"
[ -d app/.git ] || git clone --depth 1 "$REPO" app
cd app
# --ignore-scripts: skips the postinstall that downloads a ~150 MB Chromium
[ -d node_modules ]     || npm install --no-audit --no-fund --ignore-scripts
[ -d web/node_modules ] || (cd web && npm ci --no-audit --no-fund --ignore-scripts)

R="$DIR/sample-root"
if [ ! -f "$R/data/applications.md" ]; then
  mkdir -p "$R/config" "$R/data" "$R/reports" "$R/output" "$R/modes"
  cp examples/dual-track-engineer-instructor/cv.md "$R/cv.md"
  cp examples/dual-track-engineer-instructor/profile.yml "$R/config/profile.yml"
  cp examples/sample-report.md "$R/reports/001-acme-ai-2026-04-01.md"
  cat > "$R/data/applications.md" <<'T'
# Applications Tracker

| # | Date | Company | Role | Score | Status | PDF | Report | Notes |
|---|------|---------|------|-------|--------|-----|--------|-------|
| 1 | 2026-04-01 | Acme AI | Senior AI Engineer | 4.2/5 | Evaluated | ❌ | [001](../reports/001-acme-ai-2026-04-01.md) | sample row |
| 2 | 2026-04-02 | Northwind | Platform Engineer | 3.8/5 | Applied | ❌ | - | sample row |
| 3 | 2026-04-03 | Globex | DevOps Lead | 4.6/5 | Interview | ❌ | - | sample row |
T
  cat > "$R/data/pipeline.md" <<'T'
# Pipeline

- [ ] https://jobs.example.com/initech-sre | Initech | SRE
- [ ] https://jobs.example.com/umbrella-platform | Umbrella | Platform Engineer
T
fi

cd web
export NEXT_TELEMETRY_DISABLED=1 CAREER_OPS_ROOT="$R" CAREER_OPS_CODE_ROOT="$DIR/app"
npx next dev -H 127.0.0.1 -p "$PORT" &
SRV=$!
trap 'kill $SRV 2>/dev/null; wait $SRV 2>/dev/null; echo; echo "stopped"' EXIT INT TERM
for _ in $(seq 1 60); do curl -s -o /dev/null "http://localhost:$PORT/" && break; sleep 1; done
echo; echo ">>> career-ops UI: http://localhost:$PORT   (sample data in $R)   Ctrl-C to stop"
echo ">>> Look, don't run: 'Evaluate'/'Explore'/'Ask' would call an AI CLI installed on this machine."
command -v open >/dev/null && open "http://localhost:$PORT" || true
wait $SRV
