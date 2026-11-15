"""Blender-side acceptance checks for extract_mask.py (Blender 5.2.2)."""
import hashlib
import os
import sys
import tempfile

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import extract_mask


def sha256(path):
    with open(path, "rb") as stream:
        return hashlib.sha256(stream.read()).hexdigest()


def run():
    with tempfile.TemporaryDirectory(prefix="pb_mask_test_") as temp:
        src = os.path.join(temp, "synthetic.png")
        mask_path = os.path.join(temp, "mask.png")
        gray_path = os.path.join(temp, "gray.png")
        protected = os.path.join(temp, "must_not_overwrite.png")
        im = bpy.data.images.new("synthetic boundary", width=8, height=8,
                                 alpha=True, float_buffer=False)
        px = np.zeros((8, 8, 4), dtype=np.float32)
        px[:, :, 3] = 0.37
        px[:, 4:, :3] = 1.0
        im.pixels.foreach_set(px.reshape(-1))
        im.file_format = "PNG"
        im.filepath_raw = src
        im.save()
        bpy.data.images.remove(im)
        before = sha256(src)

        result = extract_mask.extract(src, mask_path, threshold=0.5, width=1,
                                      gray_output=gray_path)
        assert result["edge_pixels"] == 16, result
        assert sha256(src) == before, "source bytes changed"
        mask = bpy.data.images.load(mask_path, check_existing=False)
        values = np.empty(8 * 8 * 4, dtype=np.float32)
        mask.pixels.foreach_get(values)
        values = values.reshape((8, 8, 4))
        assert np.count_nonzero(values[:, :, 0] > 0.5) == 16
        assert np.allclose(values[:, :, 0], values[:, :, 1])
        assert np.allclose(values[:, :, 1], values[:, :, 2])
        assert np.allclose(values[:, :, 3], 0.37, atol=1.0 / 255.0)
        bpy.data.images.remove(mask)
        assert os.path.isfile(gray_path)

        with open(protected, "wb") as stream:
            stream.write(b"keep-existing-output")
        try:
            extract_mask.extract(src, protected, threshold=0.5)
            raise AssertionError("existing output unexpectedly accepted")
        except FileExistsError:
            pass
        with open(protected, "rb") as stream:
            assert stream.read() == b"keep-existing-output"
        assert sha256(src) == before, "source bytes changed after refusal"

        flat_src = os.path.join(temp, "uniform.png")
        flat_mask = os.path.join(temp, "uniform_mask.png")
        flat_gray = os.path.join(temp, "uniform_gray.png")
        flat = bpy.data.images.new("uniform image", width=8, height=8,
                                   alpha=True, float_buffer=False)
        flat_pixels = np.zeros((8, 8, 4), dtype=np.float32)
        flat_pixels[:, :, :3] = 0.4
        flat_pixels[:, :, 3] = 1.0
        flat.pixels.foreach_set(flat_pixels.reshape(-1))
        flat.file_format = "PNG"
        flat.filepath_raw = flat_src
        flat.save()
        bpy.data.images.remove(flat)
        flat_result = extract_mask.extract(flat_src, flat_mask, threshold=0.0,
                                           gray_output=flat_gray)
        assert flat_result["edge_pixels"] == 0, flat_result
        gray_image = bpy.data.images.load(flat_gray, check_existing=False)
        gray_values = np.empty(8 * 8 * 4, dtype=np.float32)
        gray_image.pixels.foreach_get(gray_values)
        gray_pixel = gray_values[:4]
        assert np.allclose(gray_pixel[:3], 0.4, atol=2.0 / 255.0), gray_pixel
        bpy.data.images.remove(gray_image)

        transparent_src = os.path.join(temp, "transparent_boundary.png")
        transparent_mask = os.path.join(temp, "transparent_boundary_mask.png")
        trans = bpy.data.images.new("transparent boundary", width=8, height=8,
                                    alpha=True, float_buffer=False)
        trans_pixels = px.copy()
        trans_pixels[:, 3:5, 3] = 0.0
        trans.pixels.foreach_set(trans_pixels.reshape(-1))
        trans.file_format = "PNG"
        trans.filepath_raw = transparent_src
        trans.save()
        bpy.data.images.remove(trans)
        trans_result = extract_mask.extract(transparent_src, transparent_mask,
                                            threshold=0.5)
        trans_mask = bpy.data.images.load(transparent_mask, check_existing=False)
        trans_values = np.empty(8 * 8 * 4, dtype=np.float32)
        trans_mask.pixels.foreach_get(trans_values)
        trans_values = trans_values.reshape((8, 8, 4))
        assert np.count_nonzero(trans_values[:, 3:5, :3]) == 0
        bpy.data.images.remove(trans_mask)

        print("@@JSON@@{\"blender\": \"%s\", \"synthetic_boundary_edge_pixels\": 16, "
              "\"alpha_preserved\": true, \"source_unchanged\": true, "
              "\"existing_output_preserved\": true, \"uniform_zero_threshold_empty\": true, "
              "\"fully_transparent_edges_black\": true, \"srgb_gray_roundtrip\": true}" % bpy.app.version_string)


if __name__ == "__main__":
    run()
