#!/usr/bin/env bash
set -euo pipefail

OFFICIAL_URL="${MINECRAFT_LAUNCHER_URL:-https://launcher.mojang.com/download/Minecraft.tar.gz}"
PRISM_VERSION="${PRISM_VERSION:-11.1.1}"
PRISM_URL="${PRISM_LAUNCHER_URL:-https://github.com/PrismLauncher/PrismLauncher/releases/download/${PRISM_VERSION}/PrismLauncher-Linux-Qt6-Portable-${PRISM_VERSION}.tar.gz}"
PREFIX="${MINECRAFT_PREFIX:-$HOME/.local}"
OFFICIAL_DIR="${PREFIX}/opt/minecraft-launcher"
PRISM_DIR="${PREFIX}/opt/prismlauncher"
BIN_DIR="${PREFIX}/bin"
OFFICIAL_WRAPPER="${BIN_DIR}/minecraft-official"
PRISM_WRAPPER="${BIN_DIR}/minecraft"
DESKTOP_DIR="${HOME}/.local/share/applications"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/minecraft-launcher"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/minecraft/install.sh

Installs:
  1. Prism Launcher (Qt, default `yarn minecraft`)
  2. Official Minecraft tar.gz launcher (`yarn minecraft:official`)

Environment:
  MINECRAFT_PREFIX       Install prefix (default: ~/.local)
  PRISM_VERSION          Prism Launcher version
  PRISM_LAUNCHER_URL     Prism portable tarball URL
  MINECRAFT_LAUNCHER_URL Official bootstrap tarball URL
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
    libopenal1
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

write_session_wrapper_prefix() {
  cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  echo "No DISPLAY/WAYLAND_DISPLAY. Minecraft needs a graphical session." >&2
  exit 1
fi

export DISPLAY="${DISPLAY:-:1}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-x11}"
export __GLX_VENDOR_LIBRARY_NAME="${__GLX_VENDOR_LIBRARY_NAME:-mesa}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export TMPDIR="${TMPDIR:-/tmp}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${HOME}/.cache/xdg-runtime}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  for bus_file in "$HOME/.dbus/session-bus/"*; do
    if [[ -f "$bus_file" ]]; then
      # shellcheck disable=SC1090
      . "$bus_file"
      break
    fi
  done
fi
EOF
}

echo "==> Installing Minecraft launcher runtime packages"
install_runtime_packages
mkdir -p "$CACHE_DIR" "$BIN_DIR" "$DESKTOP_DIR"

echo "==> Installing Prism Launcher ${PRISM_VERSION}"
PRISM_TARBALL="${CACHE_DIR}/PrismLauncher-Linux-Qt6-Portable-${PRISM_VERSION}.tar.gz"
curl -fL --retry 4 --retry-delay 4 -o "$PRISM_TARBALL" "$PRISM_URL"
rm -rf "${PRISM_DIR}.tmp" "$PRISM_DIR"
mkdir -p "${PRISM_DIR}.tmp"
tar -xzf "$PRISM_TARBALL" -C "${PRISM_DIR}.tmp"
if [[ -x "${PRISM_DIR}.tmp/PrismLauncher" ]]; then
  mv "${PRISM_DIR}.tmp" "$PRISM_DIR"
else
  echo "Unexpected Prism tarball layout:" >&2
  find "${PRISM_DIR}.tmp" -maxdepth 2 -print >&2
  exit 1
fi
chmod +x "$PRISM_DIR/PrismLauncher" "$PRISM_DIR/bin/prismlauncher"

{
  write_session_wrapper_prefix
  cat <<EOF
cd "${PRISM_DIR}"
exec "${PRISM_DIR}/PrismLauncher" "\$@"
EOF
} > "$PRISM_WRAPPER"
chmod +x "$PRISM_WRAPPER"

cat > "${DESKTOP_DIR}/prismlauncher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Prism Launcher
Comment=Minecraft launcher (local Linux)
Exec=${PRISM_WRAPPER}
Icon=org.prismlauncher.PrismLauncher
Terminal=false
Categories=Game;
StartupNotify=true
EOF

echo "==> Installing official Minecraft.tar.gz bootstrap"
OFFICIAL_TARBALL="${CACHE_DIR}/Minecraft.tar.gz"
curl -fL --retry 4 --retry-delay 4 -o "$OFFICIAL_TARBALL" "$OFFICIAL_URL"
rm -rf "${OFFICIAL_DIR}.tmp"
mkdir -p "${OFFICIAL_DIR}.tmp"
tar -xzf "$OFFICIAL_TARBALL" -C "${OFFICIAL_DIR}.tmp"
if [[ -x "${OFFICIAL_DIR}.tmp/minecraft-launcher/minecraft-launcher" ]]; then
  rm -rf "$OFFICIAL_DIR"
  mv "${OFFICIAL_DIR}.tmp/minecraft-launcher" "$OFFICIAL_DIR"
  rm -rf "${OFFICIAL_DIR}.tmp"
elif [[ -x "${OFFICIAL_DIR}.tmp/minecraft-launcher" ]]; then
  rm -rf "$OFFICIAL_DIR"
  mv "${OFFICIAL_DIR}.tmp" "$OFFICIAL_DIR"
else
  echo "Unexpected official tarball layout:" >&2
  find "${OFFICIAL_DIR}.tmp" -maxdepth 2 -print >&2
  exit 1
fi
chmod +x "$OFFICIAL_DIR/minecraft-launcher"

{
  write_session_wrapper_prefix
  cat <<EOF
cd "${OFFICIAL_DIR}"
exec "${OFFICIAL_DIR}/minecraft-launcher" \\
  --no-sandbox \\
  --disable-setuid-sandbox \\
  --disable-dev-shm-usage \\
  --use-gl=angle \\
  --use-angle=swiftshader-webgl \\
  --ozone-platform=x11 \\
  "\$@"
EOF
} > "$OFFICIAL_WRAPPER"
chmod +x "$OFFICIAL_WRAPPER"

cat > "${DESKTOP_DIR}/minecraft-launcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Minecraft Launcher (official)
Comment=Official Minecraft Launcher (tar.gz)
Exec=${OFFICIAL_WRAPPER}
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
echo "  Prism:    $PRISM_DIR/PrismLauncher"
echo "  Official: $OFFICIAL_DIR/minecraft-launcher"
echo
echo "Run:"
echo "  yarn minecraft              # Prism Launcher (default)"
echo "  yarn minecraft:official     # official Mojang bootstrap"
echo "  $PRISM_WRAPPER"
echo "  $OFFICIAL_WRAPPER"
