"""Open an existing demo .blend and assert its portable resources are present."""
import json
import bpy


def run():
    images = {image.name: image for image in bpy.data.images}
    # Names can include Blender's internal source basename, assert semantic images
    # via packed status and material references instead of relying on naming.
    packed = [im for im in bpy.data.images if im.packed_file]
    mat = bpy.data.materials.get("PB | Black + painted white details + rim")
    assert mat is not None and mat.node_tree is not None
    assert any(n.type == "TEX_IMAGE" and n.image is not None for n in mat.node_tree.nodes)
    active = mat.node_tree.nodes.active
    assert active is not None and active.type == "TEX_IMAGE"
    assert "mask" in active.image.name.lower()
    assert len(packed) >= 3, [im.name for im in packed]
    assert bpy.data.objects.get("04 Rim preview (view dependent)") is not None
    print("@@JSON@@" + json.dumps({"blend_reopened": True,
          "packed_images": sorted(im.name for im in packed),
          "material_nodes": len(mat.node_tree.nodes),
          "objects": len(bpy.context.scene.objects)}))


if __name__ == "__main__":
    run()
