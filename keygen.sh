#!/bin/bash
# Wrapper script to run keygen commands from the host
# Usage: ./keygen.sh [command] [args...]
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

if [ -z "${DMD_DB_API_PASS:-}" ]; then
    echo "DMD_DB_API_PASS is not set, add it to $SCRIPT_DIR/.env" >&2
    exit 1
fi

# Run keygen with all arguments
cd "$SCRIPT_DIR"
npm run --silent keygen:dev -- "$@"
