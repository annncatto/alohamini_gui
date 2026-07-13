#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$OPS_DIR/bin:$PATH"
source "$OPS_DIR/config.env"

PI_USER="${ALOHAMINI_RUNTIME_PI_USER:-$PI_USER}"
PI_HOST="${ALOHAMINI_RUNTIME_PI_HOST:-$PI_HOST}"

side="${1:-}"
case "$side" in
  left)
    port="/dev/am_arm_follower_left"
    default_id="${FOLLOWER_LEFT_ID:-follower_arm_left}"
    side_label="left"
    ;;
  right)
    port="/dev/am_arm_follower_right"
    default_id="${FOLLOWER_RIGHT_ID:-follower_arm_right}"
    side_label="right"
    ;;
  *)
    echo "Usage: $0 {left|right} [follower_id] [arm_profile]"
    exit 2
    ;;
esac

follower_id="${2:-$default_id}"
arm_profile="${3:-${FOLLOWER_ARM_PROFILE:-am-follower-6dof-hd}}"
target="$PI_USER@$PI_HOST"

if [[ -z "$follower_id" || -z "$arm_profile" ]]; then
  echo "Follower ID and arm_profile must not be empty."
  exit 2
fi

printf -v remote_port "%q" "$port"
printf -v remote_id "%q" "$follower_id"
printf -v remote_profile "%q" "$arm_profile"
printf -v remote_repo "%q" "$PI_REPO"
printf -v remote_conda_init "%q" "$CONDA_INIT_PI"
printf -v remote_conda_env "%q" "$CONDA_ENV"

remote_cmd="
set -euo pipefail
PORT=$remote_port
FOLLOWER_ID=$remote_id
ARM_PROFILE=$remote_profile
PI_REPO=$remote_repo
CONDA_INIT_PI=$remote_conda_init
CONDA_ENV=$remote_conda_env

echo '== AlohaMini follower calibration on Raspberry Pi =='
echo 'Side: $side_label'
echo \"Port: \$PORT\"
echo \"ID: \$FOLLOWER_ID\"
echo \"arm_profile: \$ARM_PROFILE\"
echo

echo '-- mapped follower links --'
ls -l /dev/am_arm_follower_left /dev/am_arm_follower_right /dev/ttyACM* 2>/dev/null || true
echo

if [[ ! -e \"\$PORT\" ]]; then
  echo \"Missing \$PORT. Build follower udev mapping on the Pi first, then retry.\"
  exit 1
fi

if [[ ! -r \"\$PORT\" || ! -w \"\$PORT\" ]]; then
  echo \"\$PORT exists but is not readable/writable by this SSH shell.\"
  echo \"Current groups: \$(id -nG)\"
  echo 'Expected group: dialout. Log out/in on the Pi if dialout was added recently.'
  exit 1
fi

if pgrep -f '[p]ython -m lerobot.robots.alohamini.alohamini_host' >/dev/null; then
  echo '-- stopping Pi host to release follower serial ports --'
  pkill -f '[p]ython -m lerobot.robots.alohamini.alohamini_host' || true
  sleep 1
fi

source \"\$CONDA_INIT_PI\"
conda activate \"\$CONDA_ENV\"
cd \"\$PI_REPO\"

echo
echo 'Calibration starts now. Follow the lerobot-calibrate prompts.'
echo 'Move only the prompted follower arm through its range.'
echo

lerobot-calibrate \\
  --robot.type=so101_follower \\
  --robot.port=\"\$PORT\" \\
  --robot.id=\"\$FOLLOWER_ID\" \\
  --robot.arm_profile=\"\$ARM_PROFILE\"
"

echo "Opening SSH calibration session on $target"
ssh -t "$target" "bash -lc $(printf "%q" "$remote_cmd")"
