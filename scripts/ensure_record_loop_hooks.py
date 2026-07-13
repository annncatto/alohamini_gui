#!/usr/bin/env python3
import py_compile
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path


PREVIEW_BLOCK = '''
        if preview_callback is not None:
            try:
                preview_callback(obs_processed)
            except Exception as exc:
                logging.warning("Preview callback failed: %s", exc)
'''

FRAME_BLOCK = '''
            if frame_callback is not None:
                try:
                    episode_buffer = dataset.writer.episode_buffer if dataset.writer is not None else None
                    if episode_buffer is not None:
                        frame_index = int(episode_buffer["size"]) - 1
                        episode_index = int(episode_buffer["episode_index"])
                        frame_callback(episode_index, frame_index, frame_index / fps)
                except Exception as exc:
                    logging.warning("Frame callback failed: %s", exc)
'''


def add_callable_import(text: str) -> str:
    if re.search(r"^from typing import .*\bCallable\b", text, re.MULTILINE):
        return text
    match = re.search(r"^from typing import ([^\n]+)$", text, re.MULTILINE)
    if match and not match.group(1).lstrip().startswith("("):
        names = match.group(1).strip()
        return text[: match.start()] + f"from typing import Callable, {names}" + text[match.end() :]
    anchor = "from pprint import pformat\n"
    if anchor not in text:
        raise ValueError("cannot find import anchor 'from pprint import pformat'")
    return text.replace(anchor, anchor + "from typing import Callable\n", 1)


def transform(text: str) -> str:
    has_preview = "preview_callback:" in text and "preview_callback(obs_processed)" in text
    has_frame = "frame_callback:" in text and "frame_callback(episode_index" in text
    if has_preview and has_frame:
        return text
    if any(marker in text for marker in ("preview_callback:", "frame_callback:")):
        raise ValueError("record_loop contains a partial GUI hook implementation; manual review is required")

    text = add_callable_import(text)
    signature_anchor = "    display_compressed_images: bool = False,\n):"
    if signature_anchor not in text:
        raise ValueError("cannot find record_loop signature anchor")
    text = text.replace(
        signature_anchor,
        "    display_compressed_images: bool = False,\n"
        "    preview_callback: Callable[[RobotObservation], None] | None = None,\n"
        "    frame_callback: Callable[[int, int, float], None] | None = None,\n"
        "):",
        1,
    )

    observation_anchor = "        obs_processed = robot_observation_processor(obs)\n"
    if observation_anchor not in text:
        raise ValueError("cannot find processed observation anchor")
    text = text.replace(observation_anchor, observation_anchor + PREVIEW_BLOCK, 1)

    frame_anchor = "            dataset.add_frame(frame)\n"
    if frame_anchor not in text:
        raise ValueError("cannot find dataset frame anchor")
    text = text.replace(frame_anchor, frame_anchor + FRAME_BLOCK, 1)
    return text


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: ensure_record_loop_hooks.py /path/to/lerobot_alohamini", file=sys.stderr)
        return 2

    repo = Path(sys.argv[1]).expanduser().resolve()
    target = repo / "src" / "lerobot" / "scripts" / "lerobot_record.py"
    if not target.exists():
        print(f"ERROR: missing {target}", file=sys.stderr)
        return 1

    original = target.read_text(encoding="utf-8")
    try:
        updated = transform(original)
    except ValueError as exc:
        print(f"ERROR: {exc}: {target}", file=sys.stderr)
        return 1
    if updated == original:
        print("record-loop GUI hooks already present")
        return 0

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = target.with_suffix(target.suffix + f".bak.{timestamp}")
    shutil.copy2(target, backup)
    target.write_text(updated, encoding="utf-8")
    try:
        py_compile.compile(str(target), doraise=True)
    except py_compile.PyCompileError as exc:
        shutil.copy2(backup, target)
        print(f"ERROR: syntax check failed; restored {backup}: {exc}", file=sys.stderr)
        return 1
    print(f"record-loop GUI hooks written; backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
