#!/usr/bin/env bash
# B-side checks: type analysis (luau-lsp + Roblox definitions) and pure-logic unit tests (luau CLI).
# Requires: luau-lsp, luau on PATH; ROBLOX_DEFS pointing at luau-lsp's globalTypes.d.luau
# (from https://github.com/JohnnyMorganz/luau-lsp/tree/main/scripts). Studio playtests are separate.
set -uo pipefail
cd "$(dirname "$0")/../../.."
status=0
python3 tests/b/tools/sourcemap.py preview-b.project.json >/dev/null
echo "== luau-lsp analyze =="
if command -v luau-lsp >/dev/null && [ -n "${ROBLOX_DEFS:-}" ]; then
  luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions="$ROBLOX_DEFS" \
    --flag:LuauSolverV2=false \
    src/client src/server/world src/shared/content tests/b/mock tests/b/preview || status=1
else
  echo "SKIPPED: luau-lsp or ROBLOX_DEFS not available"
fi
echo "== lint =="
python3 tests/b/tools/lint.py || status=1
echo "== unit tests =="
if command -v luau >/dev/null; then
  tmp=$(mktemp -d)
  python3 tests/b/tools/bundle.py > "$tmp/bundle.luau" && luau "$tmp/bundle.luau" || status=1
  rm -rf "$tmp"
else
  echo "SKIPPED: luau CLI not available"
fi
exit $status
