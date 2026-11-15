"""Extract white detail lines from image luminance edges using Blender's bpy + numpy.

Run with Blender 5.2:
  blender -b --factory-startup --disable-autoexec --python-exit-code 1 --python extract_mask.py -- \
    --source input.png --output details_mask.png --threshold 0.08 --width 2

Output is an RGBA PNG: RGB is a black/white edge mask; alpha is copied from source.
The input file is read-only. Existing output files are always refused.
"""
import argparse
import os
import sys

import bpy
import numpy as np


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Input image")
    parser.add_argument("--output", required=True, help="New RGBA PNG mask path")
    parser.add_argument("--gray-output", help="Optional new grayscale RGBA PNG path")
    parser.add_argument("--threshold", type=float, default=0.08,
                        help="Luminance edge threshold, normalized 0..1 (default: 0.08)")
    parser.add_argument("--width", type=int, default=1,
                        help="Approximate line thickness in pixels (default: 1)")
    return parser.parse_args(argv)


def extract(source, output, threshold=0.08, width=1, gray_output=None):
    source = os.path.abspath(source)
    output = os.path.abspath(output)
    if not os.path.isfile(source):
        raise FileNotFoundError("Source image does not exist: " + source)
    if os.path.lexists(output):
        raise FileExistsError("Refusing to overwrite existing output: " + output)
    if gray_output:
        gray_output = os.path.abspath(gray_output)
        if os.path.normcase(gray_output) == os.path.normcase(output):
            raise ValueError("--output and --gray-output must be different paths")
        if os.path.lexists(gray_output):
            raise FileExistsError("Refusing to overwrite existing output: " + gray_output)
    if not 0.0 <= threshold <= 1.0:
        raise ValueError("threshold must be between 0 and 1")
    if width < 1 or width > 64:
        raise ValueError("width must be between 1 and 64 pixels")

    image = bpy.data.images.load(source, check_existing=False)
    try:
        w, h = image.size
        rgba = np.empty(w * h * 4, dtype=np.float32)
        image.pixels.foreach_get(rgba)
        rgba = rgba.reshape((h, w, 4))
        # Blender's Image.pixels exposes normalized stored RGB samples (e.g. an
        # sRGB byte 128 is about 0.502), so explicitly decode sRGB before
        # calculating linear-light luminance.
        rgb = np.clip(rgba[:, :, :3], 0.0, 1.0)
        linear = np.where(rgb <= 0.04045, rgb / 12.92,
                          ((rgb + 0.055) / 1.055) ** 2.4)
        gray = (linear[:, :, 0] * 0.2126 + linear[:, :, 1] * 0.7152 +
                linear[:, :, 2] * 0.0722)
        if gray_output:
            gray_rgba = np.empty((h, w, 4), dtype=np.float32)
            encoded_gray = np.where(gray <= 0.0031308, gray * 12.92,
                                    1.055 * np.power(gray, 1.0 / 2.4) - 0.055)
            gray_rgba[:, :, :3] = encoded_gray[:, :, None]
            gray_rgba[:, :, 3] = rgba[:, :, 3]
            gray_img = bpy.data.images.new("PB Grayscale", width=w, height=h,
                                           alpha=True, float_buffer=False)
            gray_img.pixels.foreach_set(gray_rgba.reshape(-1))
            gray_img.file_format = "PNG"
            gray_img.filepath_raw = gray_output
            os.makedirs(os.path.dirname(gray_output), exist_ok=True)
            gray_img.save()
            bpy.data.images.remove(gray_img)
        dx = np.zeros_like(gray)
        dy = np.zeros_like(gray)
        dx[:, 1:] = np.abs(gray[:, 1:] - gray[:, :-1])
        dx[:, :-1] = np.maximum(dx[:, :-1], np.abs(gray[:, 1:] - gray[:, :-1]))
        dy[1:, :] = np.abs(gray[1:, :] - gray[:-1, :])
        dy[:-1, :] = np.maximum(dy[:-1, :], np.abs(gray[1:, :] - gray[:-1, :]))
        # Strict comparison keeps threshold=0 useful: uniform images have no
        # luminance changes and therefore produce an empty (black) mask.
        edges = (np.maximum(dx, dy) > threshold) & (rgba[:, :, 3] > 0.0)

        # Square dilation is deterministic, dependency-free, and easy to tune for
        # pixel art. width=1 leaves the detected edge untouched.
        for _ in range(width - 1):
            padded = np.pad(edges, 1, mode="constant", constant_values=False)
            expanded = np.zeros_like(edges)
            for oy in range(3):
                for ox in range(3):
                    expanded |= padded[oy:oy + h, ox:ox + w]
            edges = expanded
        # Dilation may expand across transparent neighbors; keep their mask RGB
        # black so a sampler reading luminance cannot reveal hidden color bleed.
        edges &= rgba[:, :, 3] > 0.0

        out_pixels = np.empty((h, w, 4), dtype=np.float32)
        out_pixels[:, :, :3] = edges[:, :, None].astype(np.float32)
        out_pixels[:, :, 3] = rgba[:, :, 3]
        out = bpy.data.images.new("PB Detail Mask", width=w, height=h,
                                  alpha=True, float_buffer=False)
        out.pixels.foreach_set(out_pixels.reshape(-1))
        out.file_format = "PNG"
        out.filepath_raw = output
        os.makedirs(os.path.dirname(output), exist_ok=True)
        out.save()
        return {"source": source, "output": output, "width": w, "height": h,
                "threshold": threshold, "line_width_px": width,
                "edge_pixels": int(edges.sum()), "alpha_preserved": True,
                "grayscale_output": gray_output}
    finally:
        bpy.data.images.remove(image)


def main():
    args = parse_args(sys.argv)
    print("@@JSON@@" + __import__("json").dumps(
        extract(args.source, args.output, args.threshold, args.width,
                args.gray_output), ensure_ascii=False))


if __name__ == "__main__":
    main()
