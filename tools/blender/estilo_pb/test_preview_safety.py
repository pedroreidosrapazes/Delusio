"""Verify path-collision refusal and that a loaded scene is left untouched."""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_preview


def run():
    before = set(bpy.data.objects.keys())
    if bpy.data.filepath:
        try:
            build_preview.create("missing-source.png", "missing-mask.png",
                                 "collision.blend", "collision.png")
            raise AssertionError("loaded .blend was unexpectedly accepted")
        except RuntimeError as exc:
            assert "already loaded" in str(exc), str(exc)
        assert set(bpy.data.objects.keys()) == before
        print("@@JSON@@{\"loaded_scene_refused_untouched\": true, "
              "\"objects\": %d}" % len(before))
        return

    collisions = [
        ("same.png", "missing-mask.png", "same.png", "preview.png"),
        ("missing-source.png", "same.png", "same.png", "preview.png"),
        ("missing-source.png", "missing-mask.png", "same.png", "same.png"),
    ]
    for args in collisions:
        try:
            build_preview.create(*args)
            raise AssertionError("duplicate paths were unexpectedly accepted")
        except ValueError as exc:
            assert "different files" in str(exc), str(exc)
    assert set(bpy.data.objects.keys()) == before
    print("@@JSON@@{\"source_mask_output_path_collisions_refused\": true, "
          "\"objects\": %d}" % len(before))


if __name__ == "__main__":
    run()
