import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "ensure_camera_env_config.py"
SPEC = importlib.util.spec_from_file_location("ensure_camera_env_config", SCRIPT)
adapter = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(adapter)


def source_with_camera_function(body: str) -> str:
    return f'''from dataclasses import dataclass, field


def lekiwi_cameras_config() -> dict[str, CameraConfig]:
{body}


@RobotConfig.register_subclass("alohamini")
@dataclass
class LeKiwiConfig(RobotConfig):
    cameras: dict[str, CameraConfig] = field(default_factory=lekiwi_cameras_config)
'''


OLD_ADAPTER = '''import os
from dataclasses import dataclass, field


def _camera_catalog() -> dict[str, CameraConfig]:
    return {"forward": object()}


def lekiwi_cameras_config() -> dict[str, CameraConfig]:
    requested = os.getenv("ALOHAMINI_CAMERAS")
    if not requested:
        return {}
    return {name: _camera_catalog()[name] for name in requested.split(",")}


@RobotConfig.register_subclass("alohamini")
@dataclass
class LeKiwiConfig(RobotConfig):
    cameras: dict[str, CameraConfig] = field(default_factory=lekiwi_cameras_config)
'''


class CameraAdapterTests(unittest.TestCase):
    def test_lerobot_06_camera_function_name_is_preserved(self):
        original = source_with_camera_function('    return {"forward": configured_camera()}').replace(
            "lekiwi_cameras_config", "alohamini_cameras_config"
        ).replace("LeKiwiConfig", "AlohaMiniConfig")
        updated = adapter.transform(original)

        compile(updated, "config_alohamini.py", "exec")
        self.assertIn("def alohamini_cameras_config()", updated)
        self.assertIn("default_factory=alohamini_cameras_config", updated)
        self.assertNotIn("default_factory=lekiwi_cameras_config", updated)
        self.assertEqual(adapter.transform(updated), updated)

    def test_fresh_install_preserves_custom_upstream_default(self):
        original = source_with_camera_function('    return {"customer_camera": build_customer_camera()}')
        updated = adapter.transform(original)

        compile(updated, "config_lekiwi.py", "exec")
        self.assertIn("def _alohamini_upstream_cameras_config()", updated)
        self.assertIn('return {"customer_camera": build_customer_camera()}', updated)
        self.assertIn("if requested is None:", updated)
        self.assertIn("return _alohamini_upstream_cameras_config()", updated)
        self.assertEqual(adapter.transform(updated), updated)

    def test_existing_upstream_env_logic_is_preserved_as_default(self):
        original = source_with_camera_function(
            '    return {"site_camera": os.getenv("ALOHAMINI_CAMERAS", "site_default")}'
        )
        updated = adapter.transform(original)

        compile(updated, "config_lekiwi.py", "exec")
        self.assertIn('os.getenv("ALOHAMINI_CAMERAS", "site_default")', updated)
        self.assertIn("return _alohamini_upstream_cameras_config()", updated)

    def test_old_adapter_recovers_only_default_function_from_backup(self):
        upstream = source_with_camera_function('    return {"manual_wrist": configured_camera()}')
        updated = adapter.transform(OLD_ADAPTER, upstream)

        compile(updated, "config_lekiwi.py", "exec")
        self.assertIn('return {"manual_wrist": configured_camera()}', updated)
        self.assertIn('index_or_path="/dev/am_camera_forward"', updated)
        self.assertNotIn('return {"forward": object()}', updated)

    def test_old_adapter_without_backup_keeps_disabled_default(self):
        updated = adapter.transform(OLD_ADAPTER)

        compile(updated, "config_lekiwi.py", "exec")
        self.assertIn("No pre-adapter backup was available", updated)
        self.assertIn("return {}", updated)

    def test_backup_discovery_skips_already_adapted_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "config_lekiwi.py"
            target.write_text(OLD_ADAPTER, encoding="utf-8")
            (Path(tmp) / "config_lekiwi.py.bak.20260101_000000").write_text(
                source_with_camera_function('    return {"original": camera()}'),
                encoding="utf-8",
            )
            (Path(tmp) / "config_lekiwi.py.bak.20260102_000000").write_text(
                OLD_ADAPTER,
                encoding="utf-8",
            )

            found = adapter.find_pre_adapter_backup(target)
            self.assertIsNotNone(found)
            self.assertTrue(found.name.endswith("20260101_000000"))


if __name__ == "__main__":
    unittest.main()
