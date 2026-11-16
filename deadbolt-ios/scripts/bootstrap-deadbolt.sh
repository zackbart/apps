#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REV=11a56948b453823c9c9c3de1161254df2c00b105
DEST="$ROOT/vendor/deadbolt"
if [ -d "$DEST/.git" ]; then
  test "$(git -C "$DEST" rev-parse HEAD)" = "$REV"
else
  mkdir -p "$ROOT/vendor"
  git clone https://github.com/anomalyco/deadbolt.git "$DEST"
  git -C "$DEST" checkout --detach "$REV"
fi
