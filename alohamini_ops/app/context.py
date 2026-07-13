import os
import shlex
from dataclasses import dataclass, replace
from pathlib import Path


OPS_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = OPS_DIR.parent
CONFIG_ENV = OPS_DIR / "config.env"
TEMPLATE_ENV = ROOT_DIR / "templates" / "config.env.template"


def load_env(path: Path) -> dict[str, str]:
    env = os.environ.copy()
    if not path.exists() and TEMPLATE_ENV.exists():
        path = TEMPLATE_ENV
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip()
    return env


@dataclass(frozen=True)
class RobotConfig:
    ops_dir: Path
    env: dict[str, str]
    pi_user: str
    pi_host: str
    robot_model: str
    leader_id: str
    arm_profile: str
    local_repo: Path
    dataset_home: Path
    calibration_home: Path
    pi_host_log: str
    local_teleop_log: Path
    local_record_log: Path


class ScriptController:
    def __init__(self, config: RobotConfig):
        self.config = config

    def script_path(self, name: str) -> Path | None:
        local = self.config.ops_dir / name
        if local.exists():
            return local
        upstream = self.config.local_repo / "alohamini_ops" / name
        if upstream.exists():
            return upstream
        return None

    def script(self, name: str) -> list[str]:
        path = self.script_path(name)
        if path is not None:
            return [str(path)]
        return [
            "bash",
            "-lc",
            (
                "echo 'Missing operation script: "
                + shlex.quote(name)
                + ". Install a compatible lerobot_alohamini checkout or run scripts/doctor.sh.'; exit 2"
            ),
        ]

    def ssh_tail_host_log(self, lines: int = 120) -> list[str]:
        target = f"{self.config.pi_user}@{self.config.pi_host}"
        return ["ssh", target, f"tail -{lines} '{self.config.pi_host_log}' 2>/dev/null || true"]

    def open_terminal_command(self, script_name: str, extra_args: list[str] | None = None) -> list[str]:
        script_path = self.script_path(script_name)
        if script_path is None:
            command = (
                "echo 'Missing operation script: "
                + shlex.quote(script_name)
                + ". Run scripts/doctor.sh for compatibility details.'; "
                "echo; echo 'Press Enter to close.'; read"
            )
            return ["gnome-terminal", "--", "bash", "-lc", command]
        extra = " ".join(shlex.quote(arg) for arg in (extra_args or []))
        command = (
            f"cd '{script_path.parent}' && ./{script_path.name} {extra}; "
            "echo; echo 'Process exited. Press Enter to close.'; read"
        )
        return ["gnome-terminal", "--", "bash", "-lc", command]


class AppContext:
    def __init__(self, config: RobotConfig):
        self.config = config
        self.scripts = ScriptController(config)

    def set_pi_target(self, pi_user: str, pi_host: str) -> None:
        env = dict(self.config.env)
        env["PI_USER"] = pi_user
        env["PI_HOST"] = pi_host
        env["ALOHAMINI_RUNTIME_PI_USER"] = pi_user
        env["ALOHAMINI_RUNTIME_PI_HOST"] = pi_host
        self.config = replace(self.config, env=env, pi_user=pi_user, pi_host=pi_host)
        self.scripts = ScriptController(self.config)

    def save_pi_target(self, pi_user: str, pi_host: str) -> None:
        self.save_env_values({"PI_USER": pi_user, "PI_HOST": pi_host})

    def save_env_values(self, values: dict[str, str]) -> None:
        path = self.config.ops_dir / "config.env"
        lines = path.read_text(encoding="utf-8").splitlines()
        seen = set()
        new_lines = []
        for line in lines:
            stripped = line.strip()
            key = stripped.split("=", 1)[0] if "=" in stripped else ""
            if key in values:
                new_lines.append(f"{key}={values[key]}")
                seen.add(key)
            else:
                new_lines.append(line)
        for key, value in values.items():
            if key not in seen:
                new_lines.append(f"{key}={value}")
        path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")


def build_context() -> AppContext:
    env = load_env(CONFIG_ENV)
    helper_bin = str(OPS_DIR / "bin")
    env["PATH"] = helper_bin + os.pathsep + env.get("PATH", "")
    env["ALOHAMINI_RUNTIME_PI_USER"] = env.get("PI_USER", "pi5")
    env["ALOHAMINI_RUNTIME_PI_HOST"] = env.get("PI_HOST", "")
    for key, value in env.items():
        if key.startswith("ALOHAMINI_") or key in {"VOICE_DEVICE_INDEX"}:
            os.environ[key] = value
    config = RobotConfig(
        ops_dir=OPS_DIR,
        env=env,
        pi_user=env.get("PI_USER", "pi5"),
        pi_host=env.get("PI_HOST", ""),
        robot_model=env.get("ROBOT_MODEL", "alohamini2pro"),
        leader_id=env.get("LEADER_ID", "so101_leader_bi"),
        arm_profile=env.get("ARM_PROFILE", "am-leader-6dof"),
        local_repo=Path(env.get("LOCAL_REPO", str(OPS_DIR.parent))),
        dataset_home=Path(
            env.get("ALOHAMINI_DATASET_HOME", str(OPS_DIR.parent / "datasets" / "lerobot"))
        ),
        calibration_home=Path(
            env.get(
                "ALOHAMINI_CALIBRATION_HOME",
                str(Path.home() / ".cache" / "huggingface" / "lerobot" / "calibration"),
            )
        ),
        pi_host_log=env.get("PI_HOST_LOG", "/home/pi5/alohamini_logs/alohamini_host.log"),
        local_teleop_log=Path(env.get("LOCAL_TELEOP_LOG", "/tmp/alohamini_teleop.log")),
        local_record_log=Path(env.get("LOCAL_RECORD_LOG", "/tmp/alohamini_record.log")),
    )
    return AppContext(config)
