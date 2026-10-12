#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFIX="${MINECRAFT_PREFIX:-$HOME/.local}"
WRAPPER="${PREFIX}/bin/minecraft"
LAUNCHER="${PREFIX}/opt/prismlauncher/PrismLauncher"

if [[ ! -x "$WRAPPER" || ! -x "$LAUNCHER" ]]; then
  echo "==> Minecraft / Prism Launcher is not installed yet"
  bash "${ROOT}/scripts/minecraft/install.sh"
fi

exec "$WRAPPER" "$@"
