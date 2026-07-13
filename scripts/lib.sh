#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS_DIR="$ROOT_DIR/alohamini_ops"
CONFIG_ENV="$OPS_DIR/config.env"
TEMPLATE_ENV="$ROOT_DIR/templates/config.env.template"
export PATH="$OPS_DIR/bin:$PATH"

usage_common() {
  cat <<'MSG'
Common options:
  --repo PATH        Local lerobot_alohamini checkout
  --pi USER@HOST     Raspberry Pi SSH target, for example pi5@192.168.x.x
  --pi-repo PATH     Raspberry Pi repo path, default /home/<user>/lerobot_alohamini
  --conda-env NAME   Conda environment name, default lerobot_alohamini
MSG
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "== $* =="
}

ok() {
  echo "[OK] $*"
}

warn() {
  echo "[WARN] $*"
}

fail_line() {
  echo "[FAIL] $*"
}

expand_path() {
  local path="$1"
  if [[ "$path" == "~" ]]; then
    echo "$HOME"
  elif [[ "$path" == "~/"* ]]; then
    echo "$HOME/${path#~/}"
  else
    echo "$path"
  fi
}

find_conda_init() {
  local candidates=(
    "$HOME/miniconda3/etc/profile.d/conda.sh"
    "$HOME/anaconda3/etc/profile.d/conda.sh"
    "/opt/miniconda3/etc/profile.d/conda.sh"
    "/opt/anaconda3/etc/profile.d/conda.sh"
  )
  for path in "${candidates[@]}"; do
    if [ -f "$path" ]; then
      echo "$path"
      return 0
    fi
  done
  echo "$HOME/miniconda3/etc/profile.d/conda.sh"
}

parse_pi_user() {
  local pi="$1"
  echo "${pi%@*}"
}

parse_pi_host() {
  local pi="$1"
  echo "${pi#*@}"
}

validate_pi_target() {
  local pi="$1"
  local user host
  [[ "$pi" == *@* ]] || return 1
  user="$(parse_pi_user "$pi")"
  host="$(parse_pi_host "$pi")"
  [ -n "$user" ] && [ -n "$host" ] || return 1
  [[ "$user" != *"@"* && "$host" != *"@"* ]] || return 1
  [[ "$pi" != *[[:space:]/\<\>]* ]] || return 1
  [[ "$host" != "192.168.x.x" && "$host" != "PI_IP" ]] || return 1
}

default_pi_repo() {
  local pi_user="$1"
  echo "/home/$pi_user/lerobot_alohamini"
}

ensure_repo() {
  local repo="$1"
  [ -d "$repo/src/lerobot" ] || die "--repo must point to a lerobot_alohamini checkout: $repo"
}

repo_is_valid() {
  local repo="${1:-}"
  [ -n "$repo" ] && [ -d "$repo/src/lerobot" ]
}

resolve_local_repo() {
  local preferred="${1:-}"
  local candidates=(
    "$preferred"
    "${ALOHAMINI_REPO:-}"
    "$ROOT_DIR/../lerobot_alohamini"
    "$ROOT_DIR/lerobot_alohamini"
    "$HOME/lerobot_alohamini"
    "$HOME/Desktop/Alohamini/lerobot_alohamini"
    "$HOME/Desktop/lerobot_alohamini"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    [ -n "$candidate" ] || continue
    candidate="$(expand_path "$candidate")"
    if repo_is_valid "$candidate"; then
      (cd "$candidate" && pwd -P)
      return 0
    fi
  done
  return 1
}

ensure_config() {
  if [ ! -f "$CONFIG_ENV" ]; then
    cp "$TEMPLATE_ENV" "$CONFIG_ENV"
  fi
}

set_config_value() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  ensure_config
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^[[:space:]]*" key "=" {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print key "=" value
      }
    }
  ' "$CONFIG_ENV" > "$tmp"
  mv "$tmp" "$CONFIG_ENV"
}

migrate_local_config_paths() {
  local repo_override="${1:-}"
  local resolved conda_init
  load_config_env

  if [ -n "$repo_override" ]; then
    if ! repo_is_valid "$repo_override"; then
      return 1
    fi
    resolved="$(cd "$repo_override" && pwd -P)"
    if [ "${LOCAL_REPO:-}" != "$resolved" ]; then
      warn "Updating LOCAL_REPO for this machine: ${LOCAL_REPO:-<empty>} -> $resolved"
      set_config_value LOCAL_REPO "$resolved"
      LOCAL_REPO="$resolved"
    fi
  elif ! repo_is_valid "${LOCAL_REPO:-}"; then
    if ! resolved="$(resolve_local_repo)"; then
      return 1
    fi
    if [ "${LOCAL_REPO:-}" != "$resolved" ]; then
      warn "Updating LOCAL_REPO for this machine: ${LOCAL_REPO:-<empty>} -> $resolved"
      set_config_value LOCAL_REPO "$resolved"
      LOCAL_REPO="$resolved"
    fi
  fi

  if [ ! -f "${CONDA_INIT_LOCAL:-}" ]; then
    conda_init="$(find_conda_init)"
    if [ -f "$conda_init" ]; then
      warn "Updating CONDA_INIT_LOCAL for this machine: $conda_init"
      set_config_value CONDA_INIT_LOCAL "$conda_init"
      CONDA_INIT_LOCAL="$conda_init"
    fi
  fi

  resolved="$ROOT_DIR/compat/examples/alohamini/record_bi.py"
  if [ ! -f "${GUI_RECORD_SCRIPT:-}" ] && [ -f "$resolved" ]; then
    set_config_value GUI_RECORD_SCRIPT "$resolved"
    GUI_RECORD_SCRIPT="$resolved"
  fi

  if [ -z "${ALOHAMINI_DATASET_HOME:-}" ] || \
     { [[ "${ALOHAMINI_DATASET_HOME:-}" == /home/* ]] && [[ "${ALOHAMINI_DATASET_HOME:-}" != "$HOME/"* ]] && [ ! -e "${ALOHAMINI_DATASET_HOME:-}" ]; }; then
    ALOHAMINI_DATASET_HOME="$ROOT_DIR/datasets/lerobot"
    set_config_value ALOHAMINI_DATASET_HOME "$ALOHAMINI_DATASET_HOME"
  fi

  if [ -z "${ALOHAMINI_CALIBRATION_HOME:-}" ] || \
     { [[ "${ALOHAMINI_CALIBRATION_HOME:-}" == /home/* ]] && [[ "${ALOHAMINI_CALIBRATION_HOME:-}" != "$HOME/"* ]] && [ ! -e "${ALOHAMINI_CALIBRATION_HOME:-}" ]; }; then
    ALOHAMINI_CALIBRATION_HOME="$HOME/.cache/huggingface/lerobot/calibration"
    set_config_value ALOHAMINI_CALIBRATION_HOME "$ALOHAMINI_CALIBRATION_HOME"
  fi

  if [[ "${PI_HOST_LOG:-}" == */lekiwi_host.log ]]; then
    PI_HOST_LOG="${PI_HOST_LOG%/lekiwi_host.log}/alohamini_host.log"
    set_config_value PI_HOST_LOG "$PI_HOST_LOG"
  fi
}

write_config() {
  local repo="$1"
  local pi="$2"
  local pi_repo="$3"
  local conda_env="$4"
  local pi_user pi_host conda_init
  pi_user="$(parse_pi_user "$pi")"
  pi_host="$(parse_pi_host "$pi")"
  conda_init="$(find_conda_init)"

  ensure_config
  set_config_value PI_USER "$pi_user"
  set_config_value PI_HOST "$pi_host"
  set_config_value LOCAL_REPO "$repo"
  set_config_value PI_REPO "$pi_repo"
  set_config_value CONDA_INIT_LOCAL "$conda_init"
  set_config_value CONDA_INIT_PI "/home/$pi_user/miniconda3/etc/profile.d/conda.sh"
  set_config_value CONDA_ENV "$conda_env"
  set_config_value PI_LOG_DIR "/home/$pi_user/alohamini_logs"
  set_config_value PI_HOST_LOG "/home/$pi_user/alohamini_logs/alohamini_host.log"
  set_config_value ALOHAMINI_DATASET_HOME "$ROOT_DIR/datasets/lerobot"
  set_config_value ALOHAMINI_CALIBRATION_HOME "$HOME/.cache/huggingface/lerobot/calibration"
  set_config_value GUI_RECORD_SCRIPT "$ROOT_DIR/compat/examples/alohamini/record_bi.py"
}

load_config_env() {
  [ -f "$CONFIG_ENV" ] || die "missing $CONFIG_ENV; run install_cli_env.sh or install_gui.sh first"
  source "$CONFIG_ENV"
}

activate_conda() {
  load_config_env
  [ -f "${CONDA_INIT_LOCAL:-}" ] || die "CONDA_INIT_LOCAL is invalid: ${CONDA_INIT_LOCAL:-}"
  source "$CONDA_INIT_LOCAL"
  conda activate "${CONDA_ENV:-lerobot_alohamini}"
}

ensure_conda_env() {
  load_config_env
  [ -f "${CONDA_INIT_LOCAL:-}" ] || die "CONDA_INIT_LOCAL is invalid: ${CONDA_INIT_LOCAL:-}"
  source "$CONDA_INIT_LOCAL"
  local env_name="${CONDA_ENV:-lerobot_alohamini}"
  if conda env list | awk 'NF && $1 !~ /^#/ {print $1}' | grep -Fxq "$env_name"; then
    ok "reusing conda environment: $env_name"
  else
    info "Creating conda environment: $env_name"
    conda create -y -n "$env_name" python=3.12
  fi
  conda activate "$env_name"
}
