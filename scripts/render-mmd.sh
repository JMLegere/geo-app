#!/usr/bin/env bash
# Render a Mermaid .mmd file to PNG via local Mermaid CLI or kroki.io.
# Usage: ./scripts/render-mmd.sh <input.mmd> [output.png]
#
# If output is omitted, writes to same name with .png extension.
# Strips generated comment lines while preserving Mermaid directives.

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

if command -v mmdc >/dev/null 2>&1; then
  mmdc -i "$INPUT" -o "$OUTPUT" -b white >/dev/null
else
  # Strip generated comments, but keep %%{init: ...}%% directives.
  DIAGRAM=$(grep -v '^%% ' "$INPUT")
  curl --fail --silent --show-error --max-time 60 \
    -X POST "https://kroki.io/mermaid/png" \
    -H "Content-Type: text/plain" \
    --data-binary "$DIAGRAM" \
    -o "$OUTPUT"
fi

SIZE=$(wc -c < "$OUTPUT")
if [ "$SIZE" -lt 1000 ]; then
  echo "Warning: Output file is small ($SIZE bytes), rendering may have failed."
  cat "$OUTPUT"
  exit 1
fi

echo "Rendered: $OUTPUT ($SIZE bytes)"
