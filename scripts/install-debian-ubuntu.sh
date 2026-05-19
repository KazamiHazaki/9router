#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-git@github.com:KazamiHazaki/9router.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/9router}"
BRANCH="${BRANCH:-master}"
PORT="${PORT:-20128}"
HOST="${HOST:-0.0.0.0}"
NODE_MAJOR_MIN="18"

log() { printf '\033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
err() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_debian_like() {
  if ! need_cmd apt-get; then
    err "This installer supports Debian/Ubuntu only (apt-get not found)."
    exit 1
  fi
  if ! need_cmd systemctl; then
    err "systemd not found. This installer needs systemd."
    exit 1
  fi
}

ensure_packages() {
  log "Installing OS packages..."
  sudo apt-get update
  sudo apt-get install -y git curl ca-certificates build-essential python3
}

ensure_node() {
  if need_cmd node; then
    local major
    major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [ "${major}" -ge "${NODE_MAJOR_MIN}" ]; then
      log "Node.js OK: $(node -v)"
      return
    fi
    warn "Node.js too old: $(node -v). Installing Node.js 20..."
  else
    warn "Node.js not found. Installing Node.js 20..."
  fi

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  log "Node.js installed: $(node -v)"
}

sync_repo() {
  if [ -d "${INSTALL_DIR}/.git" ]; then
    log "Updating repo: ${INSTALL_DIR}"
    git -C "${INSTALL_DIR}" fetch origin "${BRANCH}"
    git -C "${INSTALL_DIR}" checkout "${BRANCH}"
    git -C "${INSTALL_DIR}" pull --ff-only origin "${BRANCH}"
  else
    log "Cloning repo: ${REPO_URL} -> ${INSTALL_DIR}"
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone --branch "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

build_app() {
  log "Installing app deps..."
  cd "${INSTALL_DIR}"
  npm install

  log "Building CLI bundle..."
  cd "${INSTALL_DIR}/cli"
  npm install
  npm run build
}

install_cli_global() {
  log "Installing 9router CLI globally..."
  cd "${INSTALL_DIR}/cli"
  local npm_bin
  npm_bin="$(command -v npm)"
  sudo env "PATH=$PATH" "${npm_bin}" install -g .
  log "9router version: $(9router --version)"
}

install_service() {
  log "Installing systemd service..."
  sudo 9router --install-systemd --host "${HOST}" --port "${PORT}"
}

print_done() {
  log "Done."
  cat <<EOF

Commands:
  systemctl status 9router.service
  tail -f /var/log/9router.log
  tail -f /var/log/9router.error.log

Endpoint:
  http://localhost:${PORT}/v1
  http://${HOST}:${PORT}/dashboard

Update later:
  cd ${INSTALL_DIR}
  git pull
  cd cli
  npm run build
  sudo npm install -g .
  sudo systemctl restart 9router.service

EOF
}

main() {
  ensure_debian_like
  ensure_packages
  ensure_node
  sync_repo
  build_app
  install_cli_global
  install_service
  print_done
}

main "$@"
