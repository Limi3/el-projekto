#!/usr/bin/env bash
# Build the Studio preview place (no Rojo needed) into build/ and copy to outputs for transfer.
set -e
cd "$(dirname "$0")/../../.."
python3 tests/b/tools/build_place.py preview-b.project.json build/PopParade-PreviewB.rbxlx
mkdir -p /mnt/user-data/outputs/build 2>/dev/null && cp build/PopParade-PreviewB.rbxlx /mnt/user-data/outputs/build/ 2>/dev/null || true
