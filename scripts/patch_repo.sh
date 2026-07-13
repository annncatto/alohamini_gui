#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

REPO=""
TARGET="pc"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="$(expand_path "${2:-}")"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: scripts/patch_repo.sh --repo PATH --target pc|pi"
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$REPO" ] || die "--repo is required"
ensure_repo "$REPO"

if [ "$TARGET" = "pc" ]; then
  info "Ensuring environment-selectable cameras"
  python "$ROOT_DIR/scripts/ensure_camera_env_config.py" "$REPO"
  info "Ensuring optional record-loop hooks used by the companion GUI"
  python "$ROOT_DIR/scripts/ensure_record_loop_hooks.py" "$REPO"
  ok "upstream examples/alohamini/record_bi.py left unchanged for CLI use"
elif [ "$TARGET" = "pi" ]; then
  info "Ensuring environment-selectable cameras"
  python "$ROOT_DIR/scripts/ensure_camera_env_config.py" "$REPO"
else
  die "--target must be pc or pi"
fi
