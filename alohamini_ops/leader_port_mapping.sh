#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'MSG'
Usage:
  leader_port_mapping.sh scan
  leader_port_mapping.sh apply LEFT_SERIAL RIGHT_SERIAL
  leader_port_mapping.sh verify

scan is read-only. apply writes /etc/udev/rules.d/90-alohamini-leader.rules.
MSG
}

serial_for_port() {
  local port="$1"
  udevadm info --attribute-walk --name="$port" 2>/dev/null \
    | awk -F'"' '/ATTRS\{serial\}/{print $2; exit}'
}

by_id_for_port() {
  local port="$1"
  local resolved
  resolved="$(readlink -f "$port" 2>/dev/null || true)"
  for by_id in /dev/serial/by-id/*; do
    [[ -e "$by_id" ]] || continue
    if [[ "$(readlink -f "$by_id" 2>/dev/null || true)" == "$resolved" ]]; then
      printf "%s" "$by_id"
      return 0
    fi
  done
}

scan_ports() {
  echo "== Current serial devices =="
  local found=0
  local port serial by_id
  for port in /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$port" ]] || continue
    found=1
    serial="$(serial_for_port "$port" || true)"
    by_id="$(by_id_for_port "$port" || true)"
    echo "PORT_SERIAL port=$port serial=${serial:-UNKNOWN} by_id=${by_id:-NONE}"
  done
  if [[ "$found" == "0" ]]; then
    echo "NO_PORTS: no /dev/ttyACM* or /dev/ttyUSB* devices found"
  fi
  echo
  echo "== Existing AlohaMini links =="
  ls -l /dev/am_arm_leader_left /dev/am_arm_leader_right 2>/dev/null || true
}

apply_mapping() {
  local left_serial="${1:-}"
  local right_serial="${2:-}"
  if [[ -z "$left_serial" || -z "$right_serial" ]]; then
    echo "ERROR: LEFT_SERIAL and RIGHT_SERIAL are required."
    usage
    exit 2
  fi
  if [[ "$left_serial" == "$right_serial" ]]; then
    echo "ERROR: left and right serials must be different."
    exit 2
  fi

  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
SUBSYSTEM=="tty", ATTRS{serial}=="$left_serial", SYMLINK+="am_arm_leader_left"
SUBSYSTEM=="tty", ATTRS{serial}=="$right_serial", SYMLINK+="am_arm_leader_right"
EOF

  echo "About to install Leader udev mapping:"
  cat "$tmp"
  echo
  echo "This requires sudo."
  sudo cp "$tmp" /etc/udev/rules.d/90-alohamini-leader.rules
  rm -f "$tmp"
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  echo
  echo "Leader udev mapping installed."
  scan_ports
}

case "${1:-}" in
  scan)
    scan_ports
    ;;
  apply)
    shift
    apply_mapping "$@"
    ;;
  verify)
    scan_ports
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Unknown command: $1"
    usage
    exit 2
    ;;
esac
