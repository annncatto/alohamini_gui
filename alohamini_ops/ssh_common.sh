#!/usr/bin/env bash

SSH_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SSH_COMMON_DIR/config.env" ]]; then
  source "$SSH_COMMON_DIR/config.env"
fi

PI_USER="${ALOHAMINI_RUNTIME_PI_USER:-${PI_USER:-pi5}}"
PI_HOST="${ALOHAMINI_RUNTIME_PI_HOST:-${PI_HOST:-}}"
SSH_TARGET="$PI_USER@$PI_HOST"
SSH_CONTROL_PERSIST="${SSH_CONTROL_PERSIST:-8h}"

safe_target="$(printf '%s' "$SSH_TARGET" | tr -c '[:alnum:]_.-' '_')"
SSH_CONTROL_PATH="${SSH_CONTROL_PATH:-/tmp/alohamini_gui_${UID}_${safe_target}.sock}"
REAL_SSH="${ALOHAMINI_REAL_SSH:-/usr/bin/ssh}"
if [[ ! -x "$REAL_SSH" && -x /bin/ssh ]]; then
  REAL_SSH="/bin/ssh"
fi
if [[ ! -x "$REAL_SSH" ]]; then
  echo "OpenSSH client is not installed." >&2
  return 127 2>/dev/null || exit 127
fi
