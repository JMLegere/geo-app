#!/usr/bin/env bash
# Render a Mermaid .mmd file to PNG via kroki.io API
# Usage: ./scripts/render-mmd.sh <input.mmd> [output.png]
#
# If output is omitted, writes to same name with .png extension.
# Strips Mermaid comments (%% ...) before sending.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <input.mmd> [output.png]"
  exit 1
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
  echo "Error: File not found: $INPUT"
  exit 1
fi

OUTPUT="${2:-${INPUT%.mmd}.png}"

# Strip comment lines and send to kroki.io
DIAGRAM=$(grep -v '^%%' "$INPUT")

curl -s -X POST "https://kroki.io/mermaid/png" \
  -H "Content-Type: text/plain" \
  -d "$DIAGRAM" \
  -o "$OUTPUT"

SIZE=$(wc -c < "$OUTPUT")
if [ "$SIZE" -lt 1000 ]; then
  echo "Warning: Output file is small ($SIZE bytes), rendering may have failed."
  cat "$OUTPUT"
  exit 1
fi

echo "Rendered: $OUTPUT ($SIZE bytes)"
