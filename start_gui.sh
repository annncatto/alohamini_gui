#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

REPO_OVERRIDE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_OVERRIDE="$(expand_path "${2:-}")"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./start_gui.sh [--repo /path/to/lerobot_alohamini]"
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [ ! -f "$CONFIG_ENV" ]; then
  echo "ERROR: missing $CONFIG_ENV"
  echo "Run:"
  echo "  $ROOT_DIR/scripts/install_gui.sh --repo ~/lerobot_alohamini --pi pi5@<ip>"
  exit 1
fi

if ! migrate_local_config_paths "$REPO_OVERRIDE"; then
  echo "ERROR: cannot locate lerobot_alohamini on this machine."
  echo "Run one of:"
  echo "  $ROOT_DIR/start_gui.sh --repo /path/to/lerobot_alohamini"
  echo "  $ROOT_DIR/install_gui.sh --repo /path/to/lerobot_alohamini --pi pi5@<ip>"
  exit 1
fi

load_config_env

if [ ! -f "${CONDA_INIT_LOCAL:-}" ]; then
  echo "ERROR: CONDA_INIT_LOCAL is invalid:"
  echo "  CONDA_INIT_LOCAL=${CONDA_INIT_LOCAL:-}"
  exit 1
fi

source "$CONDA_INIT_LOCAL"
conda activate "${CONDA_ENV:-lerobot_alohamini}"

export PYTHONPATH="$OPS_DIR:$LOCAL_REPO/src:${PYTHONPATH:-}"
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-qt.qpa.theme.gnome.warning=false}"
unset QT_PLUGIN_PATH
unset QT_QPA_PLATFORM_PLUGIN_PATH

cd "$OPS_DIR"
exec python main.py
