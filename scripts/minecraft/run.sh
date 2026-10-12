#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFIX="${MINECRAFT_PREFIX:-$HOME/.local}"
WRAPPER="${PREFIX}/bin/minecraft"
LAUNCHER="${PREFIX}/opt/minecraft-launcher/minecraft-launcher"

if [[ ! -x "$WRAPPER" || ! -x "$LAUNCHER" ]]; then
  echo "==> Minecraft launcher is not installed yet"
  bash "${ROOT}/scripts/minecraft/install.sh"
fi

exec "$WRAPPER" "$@"
