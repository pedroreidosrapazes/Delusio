"""Build an inspectable Blender scene for the PB texture/mask workflow.

Example:
  blender -b --factory-startup --disable-autoexec --python-exit-code 1 --python build_preview.py -- \
    --source ../../assets/estilo_pb/radio_atlas_demo_input.png \
    --mask ../../assets/estilo_pb/minha_mascara.png \
    --blend ../../assets/estilo_pb/meu_preview.blend \
    --preview ../../assets/estilo_pb/meu_preview.png

Both images are packed into the .blend. Existing output files are refused.
"""
import argparse
import json
import os
import sys

import bpy
import numpy as np


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--mask", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--preview", required=True)
    return parser.parse_args(argv)


def image_node(nodes, image, label, location):
    node = nodes.new("ShaderNodeTexImage")
    node.image = image
    node.label = label
    node.location = location
    node.interpolation = "Closest"
    return node


def make_pb_material(source, mask):
    mat = bpy.data.materials.new("PB | Black + painted white details + rim")
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    nodes, links = tree.nodes, tree.links
    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (720, 80)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (480, 80)
    bsdf.inputs["Roughness"].default_value = 1.0
    mask_tex = image_node(nodes, mask, "White pixels = hand-painted / extracted details", (-620, 100))
    mask_tex.image.colorspace_settings.name = "Non-Color"
    nodes.active = mask_tex
    for node in nodes:
        node.select = (node == mask_tex)
    mask_bw = nodes.new("ShaderNodeRGBToBW")
    mask_bw.location = (-390, 100)
    base = nodes.new("ShaderNodeRGB")
    base.location = (-390, -170)
    base.outputs["Color"].default_value = (0.002, 0.002, 0.002, 1.0)
    white = nodes.new("ShaderNodeRGB")
    white.location = (-170, -240)
    white.outputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    detail_mix = nodes.new("ShaderNodeMixRGB")
    detail_mix.blend_type = "MIX"
    detail_mix.location = (40, 120)
    links.new(mask_tex.outputs["Color"], mask_bw.inputs["Color"])
    links.new(mask_bw.outputs["Val"], detail_mix.inputs["Fac"])
    links.new(base.outputs["Color"], detail_mix.inputs[1])
    links.new(white.outputs["Color"], detail_mix.inputs[2])

    # Source is retained as an easy-to-find reference node for grayscale/threshold
    # tuning; it does not override the intentionally black base + explicit mask.
    src = image_node(nodes, source, "Original source atlas (reference)", (-620, 420))
    src.label = "Original texture — source/reference; not modified"
    src.hide = True

    fresnel = nodes.new("ShaderNodeFresnel")
    fresnel.location = (-170, 390)
    fresnel.inputs["IOR"].default_value = 1.25
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (40, 400)
    ramp.label = "Approximate white rim; bake/recreate in Godot as needed"
    ramp.color_ramp.elements[0].position = 0.08
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.42
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    final_mix = nodes.new("ShaderNodeMixRGB")
    final_mix.location = (260, 120)
    final_mix.label = "Mask details plus view-dependent rim"
    links.new(fresnel.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], final_mix.inputs["Fac"])
    links.new(detail_mix.outputs["Color"], final_mix.inputs[1])
    links.new(white.outputs["Color"], final_mix.inputs[2])
    links.new(final_mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat["source_texture"] = source.name
    mat["detail_mask"] = mask.name
    mat["godot_note"] = "Blender node rim is a preview approximation. Recreate animated rim in Godot."
    return mat


def new_card(name, x, image, material=None, size=2.0):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata([(x-size/2, -size/2, 0), (x+size/2, -size/2, 0),
                      (x+size/2, size/2, 0), (x-size/2, size/2, 0)], [], [(0, 1, 2, 3)])
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li, coord in zip(poly.loop_indices, ((0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[li].uv = coord
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    if material is None:
        material = bpy.data.materials.new(name + " | Unlit display")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        emission = nodes.new("ShaderNodeEmission")
        tex = image_node(nodes, image, name, (-300, 0))
        material.node_tree.links.new(tex.outputs["Color"], emission.inputs["Color"])
        material.node_tree.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    ob.data.materials.append(material)
    return ob


def create(source_path, mask_path, blend_path, preview_path):
    if not bpy.app.background:
        raise RuntimeError("Preview generation is headless-only. Run with Blender -b --factory-startup --disable-autoexec; this script will not alter an interactive scene.")
    if bpy.data.filepath:
        raise RuntimeError("A .blend is already loaded. Start a fresh Blender process with -b --factory-startup --disable-autoexec before generating the preview; the loaded scene was left untouched.")
    paths = [os.path.abspath(p) for p in (source_path, mask_path,
                                          blend_path, preview_path)]
    canonical = [os.path.normcase(os.path.realpath(path)) for path in paths]
    if len(set(canonical)) != len(canonical):
        raise ValueError("Source, mask, .blend and preview paths must all resolve to different files.")
    source_path, mask_path, blend_path, preview_path = paths
    paths = [blend_path, preview_path]
    for path in paths:
        if os.path.lexists(path):
            raise FileExistsError("Refusing to overwrite existing output: " + path)
    source_path, mask_path = os.path.abspath(source_path), os.path.abspath(mask_path)
    if not os.path.isfile(source_path) or not os.path.isfile(mask_path):
        raise FileNotFoundError("Both --source and --mask must exist")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.meshes, bpy.data.cameras,
                       bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)
    source = bpy.data.images.load(source_path, check_existing=False)
    mask = bpy.data.images.load(mask_path, check_existing=False)
    source.pack()
    mask.pack()
    w, h = source.size
    source_pixels = np.empty(w * h * 4, dtype=np.float32)
    source.pixels.foreach_get(source_pixels)
    source_pixels = source_pixels.reshape((h, w, 4))
    gray_values = (source_pixels[:, :, 0] * 0.2126 + source_pixels[:, :, 1] * 0.7152 +
                   source_pixels[:, :, 2] * 0.0722)
    gray_pixels = np.empty_like(source_pixels)
    gray_pixels[:, :, :3] = gray_values[:, :, None]
    gray_pixels[:, :, 3] = source_pixels[:, :, 3]
    gray = bpy.data.images.new("PB Grayscale (preview)", width=w, height=h,
                               alpha=True, float_buffer=False)
    gray.pixels.foreach_set(gray_pixels.reshape(-1))
    gray.pack()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1200, 500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.035, 0.035, 0.035)
    scene.view_settings.view_transform = "Standard"
    scene.camera = bpy.data.objects.new("Preview Camera", bpy.data.cameras.new("Preview Camera"))
    scene.collection.objects.link(scene.camera)
    scene.camera.location = (0, 0, 9)
    scene.camera.data.type = "ORTHO"
    scene.camera.data.ortho_scale = 9.0
    scene.camera.rotation_euler = (0, 0, 0)
    scene.render.resolution_percentage = 100

    new_card("01 Original atlas", -3.3, source)
    new_card("02 Extracted white lines on black", -1.1, mask)
    pb_mat = make_pb_material(source, mask)
    new_card("03 Grayscale luminance", 1.1, gray)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.9,
                                         location=(3.35, 0, 0))
    sphere = bpy.context.object
    sphere.name = "04 Rim preview (view dependent)"
    sphere.data.materials.append(pb_mat)
    for poly in sphere.data.polygons:
        poly.use_smooth = True

    # Small area light gives the sphere a readable volume while the card materials
    # stay emission based for dependable CPU-only preview rendering.
    light_data = bpy.data.lights.new("Preview Area", "AREA")
    light = bpy.data.objects.new("Preview Area", light_data)
    scene.collection.objects.link(light)
    light.location = (-3, 3, 5)
    light.data.energy = 450
    light.data.shape = "DISK"
    light.data.size = 5
    # Base color display on the material sphere is independent of lights only for
    # the card; the Principled sphere demonstrates Fresnel/rim under EEVEE.

    scene.render.filepath = paths[1]
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=paths[0])
    return {"blend": paths[0], "preview": paths[1], "source_packed": True,
            "mask_packed": True, "grayscale_packed": True, "material": pb_mat.name,
            "objects": len(scene.objects), "materials": len(bpy.data.materials)}


def main():
    args = parse_args(sys.argv)
    print("@@JSON@@" + json.dumps(create(args.source, args.mask, args.blend,
                                      args.preview), ensure_ascii=False))


if __name__ == "__main__":
    main()
