#!/bin/sh
set -eu
export ASC_BYPASS_KEYCHAIN=1
export ASC_CONFIG_PATH="${ASC_CONFIG_PATH:-$HOME/Dev/apps/read-the-bible/.asc/config.json}"
exec asc --profile cursor-kittens "$@"
