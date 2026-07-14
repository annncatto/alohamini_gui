import threading
import time
from pathlib import Path


class AsyncPreviewFrameWriter:
    """Write low-rate GUI previews without blocking the recording loop."""

    def __init__(
        self,
        preview_dir: str | None,
        fps: int = 5,
        quality: int = 55,
        max_width: int = 480,
    ):
        preview_fps = int(fps)
        self.preview_dir = Path(preview_dir) if preview_dir and preview_fps > 0 else None
        self.period_s = 1.0 / max(preview_fps, 1)
        self.quality = min(max(int(quality), 1), 100)
        self.max_width = max(int(max_width), 0)
        self._last_submit_t = 0.0
        self._condition = threading.Condition()
        self._latest_observation: dict | None = None
        self._stopping = False
        self._thread: threading.Thread | None = None
        if self.preview_dir is not None:
            self.preview_dir.mkdir(parents=True, exist_ok=True)
            self._thread = threading.Thread(
                target=self._run,
                name="alohamini-record-preview",
                daemon=True,
            )
            self._thread.start()

    def __call__(self, observation: dict) -> None:
        if self.preview_dir is None or self._stopping:
            return
        now = time.monotonic()
        if now - self._last_submit_t < self.period_s:
            return

        images = {
            name: value
            for name, value in observation.items()
            if hasattr(value, "shape") and len(value.shape) == 3
        }
        if not images:
            return

        # Keep only the newest group. Preview latency must never create backpressure
        # in the robot control and dataset recording loop.
        with self._condition:
            self._latest_observation = images
            self._last_submit_t = now
            self._condition.notify()

    def close(self, timeout: float = 2.0) -> None:
        if self._thread is None:
            return
        with self._condition:
            self._stopping = True
            self._latest_observation = None
            self._condition.notify()
        self._thread.join(timeout=timeout)
        self._thread = None

    def _run(self) -> None:
        import cv2

        while True:
            with self._condition:
                while self._latest_observation is None and not self._stopping:
                    self._condition.wait()
                if self._stopping:
                    return
                observation = self._latest_observation
                self._latest_observation = None

            for name, frame in observation.items():
                preview = self._resize(frame, cv2)
                ok, buffer = cv2.imencode(
                    ".jpg",
                    preview,
                    [int(cv2.IMWRITE_JPEG_QUALITY), self.quality],
                )
                if not ok:
                    continue
                target = self.preview_dir / f"{name}.jpg"
                tmp = self.preview_dir / f".{name}.jpg.tmp"
                tmp.write_bytes(buffer.tobytes())
                tmp.replace(target)

    def _resize(self, frame, cv2):
        if self.max_width <= 0 or frame.shape[1] <= self.max_width:
            return frame
        scale = self.max_width / frame.shape[1]
        height = max(round(frame.shape[0] * scale), 1)
        return cv2.resize(frame, (self.max_width, height), interpolation=cv2.INTER_AREA)
