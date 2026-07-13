#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

REPO=""
PI=""
PI_REPO=""
CONDA_ENV_NAME="lerobot_alohamini"
APPLY_GUI_COMPAT=0

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
      APPLY_GUI_COMPAT=0
      shift
      ;;
    --with-gui-compat)
      APPLY_GUI_COMPAT=1
      shift
      ;;
    -h|--help)
      echo "Usage: scripts/install_cli_env.sh --repo PATH --pi USER@HOST [--pi-repo PATH] [--with-gui-compat]"
      usage_common
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$REPO" ] || die "--repo is required"
[ -n "$PI" ] || die "--pi is required, for example pi5@192.168.0.24"
ensure_repo "$REPO"
if [ -z "$PI_REPO" ]; then
  PI_REPO="$(default_pi_repo "$(parse_pi_user "$PI")")"
fi

info "Writing companion config"
write_config "$REPO" "$PI" "$PI_REPO" "$CONDA_ENV_NAME"
ok "config: $CONFIG_ENV"

info "Checking conda"
ensure_conda_env
python -V
python -m pip --version

info "Installing AlohaMini CLI and hardware dependencies in the selected conda env"
python -m pip install -e "$REPO[core_scripts,lekiwi]"

if [ "$APPLY_GUI_COMPAT" = "1" ]; then
  info "Checking/applying GUI-required local patches"
  "$ROOT_DIR/scripts/patch_repo.sh" --repo "$REPO" --target pc
  info "Checking/applying Raspberry Pi compatibility patches"
  if ! "$ROOT_DIR/scripts/sync_pi.sh" --pi "$PI" --pi-repo "$PI_REPO"; then
    warn "Pi compatibility was not installed. Check SSH and rerun scripts/sync_pi.sh later."
  fi
else
  ok "CLI-only install: original source files were not modified"
fi

info "Checking Raspberry Pi target"
if ! "$ROOT_DIR/scripts/doctor.sh" --repo "$REPO" --pi "$PI" --pi-repo "$PI_REPO" --mode cli; then
  warn "Environment installation completed, but doctor found connection or configuration issues above."
fi

ok "CLI environment is ready"
