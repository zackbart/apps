#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
export RUNBP_SOURCE_MIRROR=0
exec runbp "$@"
