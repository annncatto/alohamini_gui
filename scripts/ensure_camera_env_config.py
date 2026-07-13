#!/usr/bin/env python3
import shutil
import sys
from datetime import datetime
from pathlib import Path


CLASS_MARKER = '@RobotConfig.register_subclass("alohamini")'
UPSTREAM_FUNCTION = "_alohamini_upstream_cameras_config"

CAMERA_OVERRIDE_BLOCK = '''def _camera_catalog() -> dict[str, CameraConfig]:
    return {
        "forward": OpenCVCameraConfig(
            index_or_path="/dev/am_camera_forward", fps=30, width=640, height=480, rotation=Cv2Rotation.NO_ROTATION, fourcc="MJPG"
        ),
        "backward": OpenCVCameraConfig(
            index_or_path="/dev/am_camera_backward", fps=30, width=640, height=480, rotation=Cv2Rotation.NO_ROTATION, fourcc="MJPG"
        ),
        "chest": OpenCVCameraConfig(
            index_or_path="/dev/am_camera_chest", fps=30, width=640, height=480, rotation=Cv2Rotation.NO_ROTATION, fourcc="MJPG"
        ),
        "wrist_left": OpenCVCameraConfig(
            index_or_path="/dev/am_camera_wrist_left", fps=30, width=640, height=480, rotation=Cv2Rotation.NO_ROTATION, fourcc="MJPG"
        ),
        "wrist_right": OpenCVCameraConfig(
            index_or_path="/dev/am_camera_wrist_right", fps=30, width=640, height=480, rotation=Cv2Rotation.NO_ROTATION, fourcc="MJPG"
        ),
    }


def lekiwi_cameras_config() -> dict[str, CameraConfig]:
    requested = os.getenv("ALOHAMINI_CAMERAS")
    if requested is None:
        return _alohamini_upstream_cameras_config()

    requested = requested.strip()
    if not requested:
        return {}

    catalog = _camera_catalog()
    names = [name.strip() for name in requested.split(",") if name.strip()]
    unknown = [name for name in names if name not in catalog]
    if unknown:
        raise ValueError(
            f"Unknown ALOHAMINI_CAMERAS entries: {unknown}. Available cameras: {list(catalog)}"
        )
    return {name: catalog[name] for name in names}


'''


def _camera_function_name(text: str) -> str:
    for name in ("alohamini_cameras_config", "lekiwi_cameras_config"):
        if f"def {name}()" in text:
            return name
    raise ValueError("cannot find an AlohaMini camera config function")


def _render_camera_override(function_name: str) -> str:
    return CAMERA_OVERRIDE_BLOCK.replace(
        "def lekiwi_cameras_config()",
        f"def {function_name}()",
        1,
    )


def _function_region(text: str) -> tuple[int, int]:
    function_name = _camera_function_name(text)
    function_pos = text.find(f"def {function_name}()")
    class_pos = text.find(CLASS_MARKER)
    if class_pos < 0:
        raise ValueError(f"cannot find {CLASS_MARKER}")
    if function_pos < 0 or function_pos > class_pos:
        raise ValueError("cannot find the camera config function before AlohaMiniConfig")
    return function_pos, class_pos


def _extract_upstream_function(text: str) -> str:
    function_name = _camera_function_name(text)
    function_pos, class_pos = _function_region(text)
    function = text[function_pos:class_pos].rstrip()
    if "_camera_catalog" in function or UPSTREAM_FUNCTION in function:
        raise ValueError("candidate backup already contains a GUI camera adapter")
    return function.replace(
        f"def {function_name}()",
        f"def {UPSTREAM_FUNCTION}()",
        1,
    )


def _empty_upstream_function() -> str:
    return (
        f"def {UPSTREAM_FUNCTION}() -> dict[str, CameraConfig]:\n"
        "    # No pre-adapter backup was available; retain the old adapter's disabled default.\n"
        "    return {}"
    )


def transform(text: str, upstream_source: str | None = None) -> str:
    function_name = _camera_function_name(text)
    if UPSTREAM_FUNCTION in text and "ALOHAMINI_CAMERAS" in text:
        return text

    _, class_pos = _function_region(text)
    adapter_pos = text.find("def _camera_catalog()")
    function_pos = text.find(f"def {function_name}()")
    replace_pos = adapter_pos if 0 <= adapter_pos < function_pos else function_pos

    if adapter_pos >= 0:
        upstream_function = (
            _extract_upstream_function(upstream_source)
            if upstream_source is not None
            else _empty_upstream_function()
        )
    else:
        upstream_function = _extract_upstream_function(text)

    prefix = text[:replace_pos]
    suffix = text[class_pos:]
    if "import os\n" not in prefix:
        dataclass_import = "from dataclasses import dataclass, field\n"
        if dataclass_import in prefix:
            prefix = prefix.replace(dataclass_import, "import os\n" + dataclass_import, 1)
        else:
            prefix += "import os\n"

    return prefix + upstream_function + "\n\n\n" + _render_camera_override(function_name) + suffix


def find_pre_adapter_backup(target: Path) -> Path | None:
    candidates = sorted(target.parent.glob(target.name + ".bak.*"), reverse=True)
    for candidate in candidates:
        try:
            text = candidate.read_text(encoding="utf-8")
            _extract_upstream_function(text)
        except (OSError, UnicodeDecodeError, ValueError):
            continue
        return candidate
    return None


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: ensure_camera_env_config.py /path/to/lerobot_alohamini", file=sys.stderr)
        return 2

    repo = Path(sys.argv[1]).expanduser().resolve()
    config_dir = repo / "src" / "lerobot" / "robots" / "alohamini"
    candidates = [config_dir / "config_alohamini.py", config_dir / "config_lekiwi.py"]
    target = next((path for path in candidates if path.exists()), None)
    if target is None:
        print(f"ERROR: missing AlohaMini config in {config_dir}", file=sys.stderr)
        return 1

    original = target.read_text(encoding="utf-8")
    upstream_backup = None
    if "def _camera_catalog()" in original and UPSTREAM_FUNCTION not in original:
        upstream_backup = find_pre_adapter_backup(target)

    try:
        upstream_source = upstream_backup.read_text(encoding="utf-8") if upstream_backup else None
        updated = transform(original, upstream_source)
        compile(updated, str(target), "exec")
    except (OSError, SyntaxError, ValueError) as exc:
        print(f"ERROR: {exc}: {target}", file=sys.stderr)
        return 1
    if updated == original:
        print("camera env override already preserves the upstream CLI default")
        return 0

    backup = target.with_suffix(target.suffix + f".bak.{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}")
    shutil.copy2(target, backup)
    target.write_text(updated, encoding="utf-8")
    if upstream_backup is not None:
        print(f"upstream camera default recovered from: {upstream_backup}")
    elif "def _camera_catalog()" in original:
        print("WARNING: no pre-adapter backup found; preserving the old adapter's disabled CLI default")
    print(f"commercial camera env override written; backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
