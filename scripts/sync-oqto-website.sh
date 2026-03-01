#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBSITE_DIR="${ROOT}/../oqto-website"
SCHEMA_SRC="${ROOT}/scripts/setup/oqto.setup.schema.json"
SCHEMA_DEST="${WEBSITE_DIR}/public/schema/oqto.setup.schema.json"

if [[ ! -d "$WEBSITE_DIR" ]]; then
  echo "oqto-website repo not found at $WEBSITE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$SCHEMA_DEST")"
cp "$SCHEMA_SRC" "$SCHEMA_DEST"

echo "Synced setup schema to $SCHEMA_DEST"
