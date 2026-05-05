#!/usr/bin/env bash
set -euo pipefail

if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

flutter test --no-pub --reporter=expanded \
  test/autoresearch/map_render_telemetry_benchmark_test.dart
