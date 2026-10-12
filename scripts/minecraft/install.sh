#!/usr/bin/env bash
set -euo pipefail

LAUNCHER_URL="${MINECRAFT_LAUNCHER_URL:-https://launcher.mojang.com/download/Minecraft.tar.gz}"
PREFIX="${MINECRAFT_PREFIX:-$HOME/.local}"
INSTALL_DIR="${PREFIX}/opt/minecraft-launcher"
BIN_DIR="${PREFIX}/bin"
WRAPPER="${BIN_DIR}/minecraft"
DESKTOP_DIR="${HOME}/.local/share/applications"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/minecraft-launcher"
TARBALL="${CACHE_DIR}/Minecraft.tar.gz"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/minecraft/install.sh

Downloads the official Minecraft Linux tarball (not the .deb) and
installs a Mesa-friendly wrapper to ~/.local/bin/minecraft.

Environment:
  MINECRAFT_PREFIX         Install prefix (default: ~/.local)
  MINECRAFT_LAUNCHER_URL   Tarball URL
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This installer only supports Linux x86_64." >&2
  exit 1
fi

is_apt_installable() {
  local candidate
  candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

install_runtime_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    echo "WARN: sudo not found; skipping apt runtime packages."
    return 0
  fi

  local candidates=(
    libgtk-3-0t64
    libgtk-3-0
    libnss3
    libxss1
    libgbm1
    libasound2t64
    libasound2
    libatk1.0-0t64
    libatk1.0-0
    libcups2t64
    libcups2
    libdrm2
    libxcomposite1
    libxdamage1
    libxi6
    libxrandr2
    libxtst6
    libgdk-pixbuf-2.0-0
    libopengl0
    libgl1
    xdg-utils
    mesa-utils
    wget
    ca-certificates
  )
  local available=()
  local pkg

  sudo apt-get update -qq
  for pkg in "${candidates[@]}"; do
    if is_apt_installable "$pkg"; then
      available+=("$pkg")
    fi
  done

  if [[ ${#available[@]} -gt 0 ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}"
  fi
}

echo "==> Installing Minecraft launcher runtime packages"
install_runtime_packages

echo "==> Downloading official Minecraft.tar.gz"
mkdir -p "$CACHE_DIR" "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"
curl -fL --retry 4 --retry-delay 4 -o "$TARBALL" "$LAUNCHER_URL"

echo "==> Extracting to $INSTALL_DIR"
rm -rf "${INSTALL_DIR}.tmp"
mkdir -p "${INSTALL_DIR}.tmp"
tar -xzf "$TARBALL" -C "${INSTALL_DIR}.tmp"

if [[ -x "${INSTALL_DIR}.tmp/minecraft-launcher/minecraft-launcher" ]]; then
  rm -rf "$INSTALL_DIR"
  mv "${INSTALL_DIR}.tmp/minecraft-launcher" "$INSTALL_DIR"
  rm -rf "${INSTALL_DIR}.tmp"
elif [[ -x "${INSTALL_DIR}.tmp/minecraft-launcher" ]]; then
  rm -rf "$INSTALL_DIR"
  mv "${INSTALL_DIR}.tmp" "$INSTALL_DIR"
else
  echo "Unexpected tarball layout:" >&2
  find "${INSTALL_DIR}.tmp" -maxdepth 2 -print >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/minecraft-launcher"

echo "==> Writing Mesa/X11 wrapper to $WRAPPER"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "\${DISPLAY:-}" && -z "\${WAYLAND_DISPLAY:-}" ]]; then
  echo "No DISPLAY/WAYLAND_DISPLAY. Minecraft needs a graphical session." >&2
  exit 1
fi

export DISPLAY="\${DISPLAY:-:1}"
export XDG_SESSION_TYPE="\${XDG_SESSION_TYPE:-x11}"
export GDK_BACKEND="\${GDK_BACKEND:-x11}"
export ELECTRON_OZONE_PLATFORM_HINT="\${ELECTRON_OZONE_PLATFORM_HINT:-x11}"
export __GLX_VENDOR_LIBRARY_NAME="\${__GLX_VENDOR_LIBRARY_NAME:-mesa}"
export LIBGL_ALWAYS_SOFTWARE="\${LIBGL_ALWAYS_SOFTWARE:-1}"
export TMPDIR="\${TMPDIR:-/tmp}"
export XDG_RUNTIME_DIR="\${XDG_RUNTIME_DIR:-${HOME}/.cache/xdg-runtime}"
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR" 2>/dev/null || true

if [[ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  for bus_file in "\$HOME/.dbus/session-bus/"*; do
    if [[ -f "\$bus_file" ]]; then
      DBUS_SESSION_BUS_ADDRESS="\$(awk -F= '/^DBUS_SESSION_BUS_ADDRESS=/{print substr(\$0, index(\$0,\$2)); exit}' "\$bus_file" | tr -d \"'\")"
      export DBUS_SESSION_BUS_ADDRESS
      break
    fi
  done
fi

cd "${INSTALL_DIR}"
exec "${INSTALL_DIR}/minecraft-launcher" \\
  --no-sandbox \\
  --disable-setuid-sandbox \\
  --disable-dev-shm-usage \\
  --use-gl=angle \\
  --use-angle=swiftshader-webgl \\
  --ozone-platform=x11 \\
  "\$@"
EOF
chmod +x "$WRAPPER"

cat > "${DESKTOP_DIR}/minecraft-launcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Minecraft Launcher
Comment=Official Minecraft Launcher (tar.gz, Mesa-friendly)
Exec=${WRAPPER}
Icon=minecraft-launcher
Terminal=false
Categories=Game;
StartupNotify=true
EOF

if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo
echo "Installed:"
echo "  launcher: $INSTALL_DIR/minecraft-launcher"
echo "  wrapper:  $WRAPPER"
echo
echo "Run:"
echo "  yarn minecraft"
echo "  $WRAPPER"
