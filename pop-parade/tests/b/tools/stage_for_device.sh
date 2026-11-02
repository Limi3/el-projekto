#!/usr/bin/env bash
# Copy the built place to a UNIQUE outputs path (the device transfer caches by path, so reusing
# one path can deliver a stale copy). Prints the staged path and md5 to verify on the device.
set -e
cd "$(dirname "$0")/../../.."
stamp=$(date +%s)
out=/mnt/user-data/outputs/build/PopParade-PreviewB-$stamp.rbxlx
cp build/PopParade-PreviewB.rbxlx "$out"
echo "$out"
md5sum build/PopParade-PreviewB.rbxlx | cut -d' ' -f1
