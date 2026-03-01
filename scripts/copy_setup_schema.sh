#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_SCHEMA="$SRC_DIR/scripts/setup/oqto.setup.schema.json"
DEST_DIR="$SRC_DIR/../schemas/oqto"
DEST_SCHEMA="$DEST_DIR/oqto.setup.schema.json"

if [ ! -f "$SRC_SCHEMA" ]; then
  echo "Source schema not found: $SRC_SCHEMA" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SRC_SCHEMA" "$DEST_SCHEMA"
echo "Copied schema to $DEST_SCHEMA"

cd "$DEST_DIR"
git pull
git add .
git commit -m "feat: updated oqto setup schema"
git push
echo "Committed and pushed schema changes"
