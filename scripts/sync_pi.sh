#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PI=""
PI_REPO=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pi)
      PI="${2:-}"
      shift 2
      ;;
    --pi-repo)
      PI_REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: scripts/sync_pi.sh --pi USER@HOST [--pi-repo PATH]"
      usage_common
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$PI" ] || die "--pi is required"
if [ -z "$PI_REPO" ]; then
  PI_REPO="$(default_pi_repo "$(parse_pi_user "$PI")")"
fi

export ALOHAMINI_RUNTIME_PI_USER="$(parse_pi_user "$PI")"
export ALOHAMINI_RUNTIME_PI_HOST="$(parse_pi_host "$PI")"

if ! "$OPS_DIR/ssh_session.sh" check >/dev/null 2>&1; then
  info "No reusable SSH authentication found; opening one temporary password session"
  "$OPS_DIR/ssh_session.sh" open || die "Could not establish temporary SSH session with $PI"
fi

if [ -f "$CONFIG_ENV" ]; then
  load_config_env
fi

pi_conda_init="$(ssh "$PI" 'for path in "$HOME/miniforge3/etc/profile.d/conda.sh" "$HOME/miniconda3/etc/profile.d/conda.sh" "$HOME/anaconda3/etc/profile.d/conda.sh"; do if test -f "$path"; then printf "%s\n" "$path"; exit 0; fi; done; exit 1')" \
  || die "No conda/miniforge initialization script found on $PI"
if [ "${CONDA_INIT_PI:-}" != "$pi_conda_init" ]; then
  info "Updating detected Pi conda path: $pi_conda_init"
  set_config_value CONDA_INIT_PI "$pi_conda_init"
  CONDA_INIT_PI="$pi_conda_init"
fi

info "Checking Pi repo"
ssh "$PI" "test -d '$PI_REPO/src/lerobot'" || die "Pi repo not found: $PI:$PI_REPO"

info "Installing Pi camera compatibility adapter"
remote_tool="/tmp/alohamini_ensure_camera_env_config.py"
scp "$ROOT_DIR/scripts/ensure_camera_env_config.py" "$PI:$remote_tool" >/dev/null
ssh "$PI" "(command -v python3 >/dev/null 2>&1 && python3 '$remote_tool' '$PI_REPO') || python '$remote_tool' '$PI_REPO'"
if ssh "$PI" "grep -q _alohamini_upstream_cameras_config '$PI_REPO/src/lerobot/robots/alohamini/config_alohamini.py' 2>/dev/null || grep -q _alohamini_upstream_cameras_config '$PI_REPO/src/lerobot/robots/alohamini/config_lekiwi.py' 2>/dev/null" >/dev/null 2>&1; then
  ok "Pi camera override preserves the upstream CLI default"
else
  die "Pi camera adapter failed. Check the repo version and the output above."
fi
