#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$OPS_DIR/ssh_common.sh"

action="${1:-check}"
if [[ -z "$PI_HOST" ]]; then
  echo "PI_HOST is empty. Set the Raspberry Pi address in the GUI first."
  exit 2
fi

master_active() {
  [[ -S "$SSH_CONTROL_PATH" ]] && \
    "$REAL_SSH" -S "$SSH_CONTROL_PATH" -O check "$SSH_TARGET" >/dev/null 2>&1
}

case "$action" in
  open)
    umask 077
    if master_active; then
      echo "Temporary SSH session is already active: $SSH_TARGET"
      exit 0
    fi
    if [[ -e "$SSH_CONTROL_PATH" ]]; then
      rm -f "$SSH_CONTROL_PATH"
    fi
    echo "Opening temporary SSH session: $SSH_TARGET"
    echo "Enter the Raspberry Pi password in this terminal. The password is not saved."
    "$REAL_SSH" \
      -f -N -M \
      -o ControlMaster=yes \
      -o ControlPath="$SSH_CONTROL_PATH" \
      -o ControlPersist="$SSH_CONTROL_PERSIST" \
      -o ConnectTimeout=8 \
      -o ServerAliveInterval=15 \
      -o ServerAliveCountMax=3 \
      "$SSH_TARGET"
    if master_active; then
      echo "Temporary SSH session established. This terminal may now be closed."
    else
      echo "SSH authentication finished, but the reusable session was not created."
      exit 1
    fi
    ;;
  check)
    if master_active; then
      echo "Temporary SSH session active: $SSH_TARGET"
      exit 0
    fi
    if "$REAL_SSH" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" true >/dev/null 2>&1; then
      echo "SSH key or agent authentication available: $SSH_TARGET"
      exit 0
    fi
    echo "No reusable SSH authentication is available for $SSH_TARGET."
    echo "Click '建立临时 SSH 会话' and enter the Raspberry Pi password once."
    exit 1
    ;;
  close)
    if master_active; then
      "$REAL_SSH" -S "$SSH_CONTROL_PATH" -O exit "$SSH_TARGET" >/dev/null
      echo "Temporary SSH session closed: $SSH_TARGET"
    else
      echo "No active temporary SSH session: $SSH_TARGET"
    fi
    [[ ! -e "$SSH_CONTROL_PATH" ]] || rm -f "$SSH_CONTROL_PATH"
    ;;
  path)
    echo "$SSH_CONTROL_PATH"
    ;;
  *)
    echo "Usage: $0 {open|check|close|path}" >&2
    exit 2
    ;;
esac
