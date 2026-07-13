#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

REPO=""
PI=""
PI_REPO=""
MODE="gui"
EXIT_CODE=0

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
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: scripts/doctor.sh --repo PATH --pi USER@HOST [--mode cli|gui]"
      usage_common
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [ -z "$REPO" ] && [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  REPO="${LOCAL_REPO:-}"
fi
[ -n "$REPO" ] || die "--repo is required"
REPO="$(expand_path "$REPO")"

if [ -z "$PI" ] && [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  PI="${PI_USER:-}@${PI_HOST:-}"
fi
[ -n "$PI" ] || die "--pi is required"
if [ -z "$PI_REPO" ]; then
  PI_REPO="$(default_pi_repo "$(parse_pi_user "$PI")")"
fi

check_ok() { ok "$1"; }
check_fail() { fail_line "$1"; EXIT_CODE=1; }
check_warn() { warn "$1"; }

info "PC checks"
if [ -d "$REPO/src/lerobot" ]; then
  check_ok "PC repo found: $REPO"
else
  check_fail "PC repo missing src/lerobot: $REPO"
fi

if [ -f "$CONFIG_ENV" ]; then
  check_ok "companion config found: $CONFIG_ENV"
else
  check_warn "companion config missing; run install_cli_env.sh or install_gui.sh"
fi

if [ -f "$(find_conda_init)" ]; then
  check_ok "conda init found: $(find_conda_init)"
else
  check_fail "conda init not found"
fi

if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  if [ -f "${CONDA_INIT_LOCAL:-}" ]; then
    source "$CONDA_INIT_LOCAL"
    if conda activate "${CONDA_ENV:-lerobot_alohamini}" >/dev/null 2>&1; then
      check_ok "conda environment active: ${CONDA_ENV:-lerobot_alohamini}"
      if python -c "import lerobot" >/dev/null 2>&1; then
        check_ok "original lerobot package imports in selected environment"
      else
        check_fail "lerobot import failed; rerun scripts/install_cli_env.sh"
      fi
    else
      check_fail "conda environment missing: ${CONDA_ENV:-lerobot_alohamini}"
    fi
  fi
fi

if [ "$MODE" = "gui" ]; then
  CAMERA_CONFIG="$REPO/src/lerobot/robots/alohamini/config_alohamini.py"
  [ -f "$CAMERA_CONFIG" ] || CAMERA_CONFIG="$REPO/src/lerobot/robots/alohamini/config_lekiwi.py"
  if grep -q "_alohamini_upstream_cameras_config" "$CAMERA_CONFIG" 2>/dev/null; then
    check_ok "camera env override preserves upstream CLI defaults"
  else
    check_fail "commercial camera env override missing; run scripts/patch_repo.sh --repo $REPO --target pc"
  fi

  if PYTHONPATH="$REPO/src:${PYTHONPATH:-}" python -c \
    "from lerobot.robots.alohamini import AlohaMiniClient, AlohaMiniClientConfig" >/dev/null 2>&1; then
    check_ok "LeRobot 0.6 AlohaMini client API imports"
  else
    check_fail "AlohaMini client API import failed; inspect config_alohamini.py and GUI compatibility"
  fi

  RECORD_LOOP="$REPO/src/lerobot/scripts/lerobot_record.py"
  if grep -q "preview_callback" "$RECORD_LOOP" 2>/dev/null && grep -q "frame_callback" "$RECORD_LOOP" 2>/dev/null; then
    check_ok "optional GUI record-loop hooks present"
  else
    check_fail "GUI record-loop hooks missing; run scripts/patch_repo.sh --repo $REPO --target pc"
  fi

  if PYTHONPATH="$REPO/src:${PYTHONPATH:-}" python "$ROOT_DIR/compat/examples/alohamini/record_bi.py" --help \
    >/dev/null 2>&1; then
    check_ok "companion GUI recording entry imports and parses arguments"
  else
    check_fail "companion GUI recording entry is incompatible with the selected repository"
  fi
else
  check_ok "CLI mode uses the original examples/alohamini scripts"
fi

for script in status.sh debug_serial_ports.sh check_local_servos.sh check_pi_servos.sh check_lift_axis.sh; do
  if [ -x "$REPO/alohamini_ops/$script" ]; then
    check_ok "upstream debug script available: $script"
  else
    check_warn "upstream debug script not found: $script"
  fi
done

if [ "$MODE" = "gui" ]; then
  if PYTHONPATH="$OPS_DIR:$REPO/src:${PYTHONPATH:-}" python - <<'PY' >/dev/null 2>&1
from qt_compat import QApplication
PY
  then
    check_ok "Qt binding import works"
  else
    check_fail "Qt binding missing; run scripts/install_gui.sh"
  fi
fi

info "Raspberry Pi checks"
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" "test -d '$PI_REPO/src/lerobot'" >/dev/null 2>&1; then
  check_ok "Pi repo found: $PI:$PI_REPO"
else
  check_fail "Pi repo missing or SSH failed: $PI:$PI_REPO"
fi

LOCAL_COMMIT="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || true)"
PI_COMMIT="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" "git -C '$PI_REPO' rev-parse --short HEAD 2>/dev/null" 2>/dev/null || true)"
if [ -n "$LOCAL_COMMIT" ] && [ "$LOCAL_COMMIT" = "$PI_COMMIT" ]; then
  check_ok "PC/Pi source commits match: $LOCAL_COMMIT"
else
  check_warn "PC/Pi source commits differ: PC=${LOCAL_COMMIT:-unknown}, Pi=${PI_COMMIT:-unknown}"
fi

CLIENT_FILE="$REPO/src/lerobot/robots/alohamini/alohamini_client.py"
if grep -q '_decode_image_from_b64' "$CLIENT_FILE" 2>/dev/null && grep -q 'recv_multipart' "$CLIENT_FILE" 2>/dev/null; then
  check_ok "PC client supports multipart JPEG and legacy base64 observations"
else
  check_warn "PC client is not dual-protocol; an old PC client cannot connect to a multipart Pi host"
fi

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" "grep -q 'send_multipart' '$PI_REPO/src/lerobot/robots/alohamini/alohamini_host.py' 2>/dev/null" >/dev/null 2>&1; then
  check_ok "Pi source uses multipart JPEG observations"
else
  check_warn "Pi source uses legacy base64 observations; update Pi before relying on binary transport"
fi

PI_CONDA_INIT="${CONDA_INIT_PI:-/home/$(parse_pi_user "$PI")/miniconda3/etc/profile.d/conda.sh}"
PI_CONDA_ENV="${CONDA_ENV:-lerobot_alohamini}"
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" \
  "test -f '$PI_CONDA_INIT' && source '$PI_CONDA_INIT' && conda run -n '$PI_CONDA_ENV' python -c 'import lerobot'" \
  >/dev/null 2>&1; then
  check_ok "Pi conda environment imports lerobot: $PI_CONDA_ENV"
else
  check_fail "Pi conda environment is missing or cannot import lerobot: $PI_CONDA_ENV"
fi

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" "grep -q _alohamini_upstream_cameras_config '$PI_REPO/src/lerobot/robots/alohamini/config_alohamini.py' 2>/dev/null || grep -q _alohamini_upstream_cameras_config '$PI_REPO/src/lerobot/robots/alohamini/config_lekiwi.py' 2>/dev/null" >/dev/null 2>&1; then
  check_ok "Pi camera override preserves upstream CLI defaults"
else
  check_warn "Pi commercial camera override missing; run scripts/sync_pi.sh --pi $PI --pi-repo $PI_REPO"
fi

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI" "grep -q 'fourcc=\"MJPG\"' '$PI_REPO/src/lerobot/robots/alohamini/config_alohamini.py' 2>/dev/null || grep -q 'fourcc=\"MJPG\"' '$PI_REPO/src/lerobot/robots/alohamini/config_lekiwi.py' 2>/dev/null" >/dev/null 2>&1; then
  check_ok "Pi multi-camera override uses MJPG"
else
  check_warn "Pi camera override does not force MJPG; simultaneous cameras may exhaust USB bandwidth"
fi

exit "$EXIT_CODE"
