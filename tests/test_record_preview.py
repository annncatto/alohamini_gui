import tempfile
import time
import unittest
from pathlib import Path

from app.record_preview import AsyncPreviewFrameWriter

try:
    import cv2  # noqa: F401
    import numpy as np
    from PIL import Image
except ImportError:
    cv2 = None
    np = None
    Image = None


class AsyncPreviewFrameWriterTest(unittest.TestCase):
    def test_disabled_writer_is_a_noop(self):
        writer = AsyncPreviewFrameWriter(None)
        writer({})
        writer.close()

    def test_zero_fps_disables_writer(self):
        with tempfile.TemporaryDirectory() as directory:
            writer = AsyncPreviewFrameWriter(directory, fps=0)
            self.assertIsNone(writer.preview_dir)
            writer.close()

    @unittest.skipUnless(cv2 is not None and np is not None and Image is not None, "image dependencies unavailable")
    def test_writes_resized_jpeg(self):
        with tempfile.TemporaryDirectory() as directory:
            writer = AsyncPreviewFrameWriter(directory, fps=30, quality=40, max_width=32)
            writer({"forward": np.zeros((48, 64, 3), dtype=np.uint8)})
            target = Path(directory) / "forward.jpg"
            deadline = time.monotonic() + 2
            while not target.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            writer.close()

            self.assertTrue(target.exists())
            with Image.open(target) as image:
                self.assertEqual(image.size, (32, 24))


if __name__ == "__main__":
    unittest.main()
