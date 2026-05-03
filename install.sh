#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIND="${PREFIX:-/usr/local/bin}"
chmod 0755 "$ROOT/uasf.sh"
ln -sf "$ROOT/uasf.sh" "${BIND%/}/uasf360-cli"
echo "Symlink: ${BIND%/}/uasf360-cli -> $ROOT/uasf.sh"
