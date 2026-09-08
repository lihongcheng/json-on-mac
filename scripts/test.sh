#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/.build/core-checks"

mkdir -p "$ROOT/.build"

xcrun swiftc \
  "$ROOT/Sources/JSONLens/Models/JSONTypes.swift" \
  "$ROOT/Sources/JSONLens/Core/JSONEngine.swift" \
  "$ROOT/Tests/CoreChecks.swift" \
  -o "$OUTPUT"

"$OUTPUT"
swift build --package-path "$ROOT"
