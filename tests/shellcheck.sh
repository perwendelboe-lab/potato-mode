#!/bin/bash
# Lint every shell file in the repo.
set -euo pipefail
cd "$(dirname "$0")/.."
shellcheck -x -s bash bin/* lib/*.sh hooks/* install.sh tests/*.sh share/potato-mode/packages.sh share/potato-mode/compat
echo "shellcheck: clean"
