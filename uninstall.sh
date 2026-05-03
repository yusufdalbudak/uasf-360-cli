#!/usr/bin/env bash
set -euo pipefail
BIND="${PREFIX:-/usr/local/bin}"
rm -f "${BIND%/}/uasf360-cli"
echo "Removed ${BIND%/}/uasf360-cli if present."
