#!/usr/bin/env bash
# Run the PackWrite test suite (unit harness + CLI integration).
#
#   ./tests/run.sh
#   KUJO=/path/to/kujo/target/release/kujo ./tests/run.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUJO="${KUJO:-kujo}"

"$KUJO" run "$PROJECT_DIR/tests/packwrite_test.kujo"
KUJO="$KUJO" bash "$PROJECT_DIR/tests/cli_integration.sh"
