#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

REPO=""
PI=""
PI_REPO=""
CONDA_ENV_NAME="lerobot_alohamini"
SKIP_PATCHES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="$(expand_path "${2:-}")"
      shift 2
      ;;
    --pi)
      PI="${2:-}"
      shift 2
      ;;
    --pi-repo)
      PI_REPO="${2:-}"
      shift 2
      ;;
    --conda-env)
      CONDA_ENV_NAME="${2:-}"
      shift 2
      ;;
    --skip-patches)
      SKIP_PATCHES=1
      shift
      ;;
    -h|--help)
      echo "Usage: scripts/install_gui.sh --repo PATH --pi USER@HOST [--pi-repo PATH]"
      usage_common
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$REPO" ] || die "--repo is required"
[ -n "$PI" ] || die "--pi is required, for example pi5@192.168.x.x"
validate_pi_target "$PI" || die "--pi must be USER@HOST with the robot's real IP or hostname"
ensure_repo "$REPO"
if [ -z "$PI_REPO" ]; then
  PI_REPO="$(default_pi_repo "$(parse_pi_user "$PI")")"
fi

CLI_ARGS=(--repo "$REPO" --pi "$PI" --pi-repo "$PI_REPO" --conda-env "$CONDA_ENV_NAME")
CLI_ARGS+=(--skip-patches)
"$ROOT_DIR/scripts/install_cli_env.sh" "${CLI_ARGS[@]}"

if [ "$SKIP_PATCHES" = "0" ]; then
  info "Installing GUI compatibility without replacing upstream CLI scripts"
  "$ROOT_DIR/scripts/patch_repo.sh" --repo "$REPO" --target pc
  if ! "$ROOT_DIR/scripts/sync_pi.sh" --pi "$PI" --pi-repo "$PI_REPO"; then
    warn "Pi compatibility was not installed. The PC GUI can still be installed; rerun scripts/sync_pi.sh when SSH is available."
  fi
else
  warn "Skipping GUI compatibility changes; camera selection and GUI recording may be unavailable"
fi

info "Installing GUI dependencies"
activate_conda
python -m pip install -r "$OPS_DIR/requirements-gui.txt"

info "Qt smoke test"
QT_QPA_PLATFORM=offscreen PYTHONPATH="$OPS_DIR:$REPO/src:${PYTHONPATH:-}" python - <<'PY'
from app.context import build_context
from qt_compat import QApplication
from ui.main_window import MainWindow

app = QApplication([])
window = MainWindow(build_context())
window.close()
print("Qt GUI smoke: OK")
PY

info "Final GUI compatibility check"
if ! "$ROOT_DIR/scripts/doctor.sh" --repo "$REPO" --pi "$PI" --pi-repo "$PI_REPO" --mode gui; then
  warn "GUI installation completed, but doctor found connection or configuration issues above."
fi

ok "GUI environment is ready"
echo "Start GUI with:"
echo "  $ROOT_DIR/start_gui.sh"
