import math
import os
import random
import bpy
import bmesh
import mathutils

OUTPUT_DIR = "/home/pedro/Documentos/plantação"
BLEND_PATH = os.path.join(OUTPUT_DIR, "plantacao_aboboras.blend")
GLB_PATH = os.path.join(OUTPUT_DIR, "plantacao_aboboras.glb")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def set_flat_shading(obj):
    if obj.type != "MESH":
        return
    for poly in obj.data.polygons:
        poly.use_smooth = False


def make_horror_material(
    name,
    base_color,
    dark_color,
    roughness=0.88,
    metallic=0.0,
    noise_scale=12.0,
    bump_strength=0.25,
    emission_color=None,
    emission_strength=0.0,
):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (250, 0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25

    if emission_color is not None and emission_strength > 0.0:
        bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission_color, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return mat

    tex_coord = nodes.new("ShaderNodeTexCoord")
    tex_coord.location = (-550, 0)

    noise = nodes.new("ShaderNodeTexNoise")
    noise.location = (-320, 80)
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.72

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-60, 120)
    ramp.color_ramp.elements[0].position = 0.28
    ramp.color_ramp.elements[0].color = (*dark_color, 1.0)
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = (*base_color, 1.0)

    bump = nodes.new("ShaderNodeBump")
    bump.location = (0, -140)
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.03

    links.new(tex_coord.outputs["Object"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def create_materials():
    return {
        "soil": make_horror_material(
            "M_Terra_Umida",
            base_color=(0.075, 0.055, 0.040),
            dark_color=(0.025, 0.018, 0.014),
            roughness=0.65,
            noise_scale=9.0,
            bump_strength=0.45,
        ),
        "wood": make_horror_material(
            "M_Madeira_Podre",
            base_color=(0.13, 0.095, 0.068),
            dark_color=(0.04, 0.032, 0.025),
            roughness=0.92,
            noise_scale=16.0,
            bump_strength=0.35,
        ),
        "rust": make_horror_material(
            "M_Ferro_Enferrujado",
            base_color=(0.18, 0.085, 0.045),
            dark_color=(0.05, 0.045, 0.048),
            roughness=0.82,
            metallic=0.65,
            noise_scale=14.0,
            bump_strength=0.35,
        ),
        "galvanized": make_horror_material(
            "M_Metal_Regador",
            base_color=(0.24, 0.25, 0.24),
            dark_color=(0.11, 0.075, 0.050),
            roughness=0.62,
            metallic=0.78,
            noise_scale=11.0,
            bump_strength=0.25,
        ),
        "pumpkin": make_horror_material(
            "M_Abobora_Terror",
            base_color=(0.42, 0.165, 0.042),
            dark_color=(0.14, 0.065, 0.025),
            roughness=0.72,
            noise_scale=8.0,
            bump_strength=0.28,
        ),
        "pumpkin_pale": make_horror_material(
            "M_Abobora_Podre",
            base_color=(0.32, 0.19, 0.065),
            dark_color=(0.09, 0.06, 0.03),
            roughness=0.80,
            noise_scale=10.0,
            bump_strength=0.32,
        ),
        "stem": make_horror_material(
            "M_Cabo_Seco",
            base_color=(0.12, 0.13, 0.06),
            dark_color=(0.04, 0.045, 0.025),
            roughness=0.94,
            noise_scale=15.0,
            bump_strength=0.3,
        ),
        "leaf": make_horror_material(
            "M_Folha_Murcha",
            base_color=(0.09, 0.13, 0.055),
            dark_color=(0.035, 0.045, 0.022),
            roughness=0.86,
            noise_scale=12.0,
            bump_strength=0.2,
        ),
        "sparks": make_horror_material(
            "M_Faiscas_Agua",
            base_color=(0.78, 0.92, 1.0),
            dark_color=(0.78, 0.92, 1.0),
            roughness=0.05,
            emission_color=(0.78, 0.92, 1.0),
            emission_strength=6.5,
        ),
    }


def create_soil_bed(col, mats):
    # Low-poly bumpy mud bed
    mesh = bpy.data.meshes.new("Canteiro_Terra_Mesh")
    obj = bpy.data.objects.new("Canteiro_Terra", mesh)
    col.objects.link(obj)
    obj.data.materials.append(mats["soil"])

    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=12, y_segments=8, size=1.0)
    rng = random.Random(42)
    for v in bm.verts:
        v.co.x *= 1.50
        v.co.y *= 1.00
        edge_x = max(0.0, 1.0 - (abs(v.co.x) / 1.50) ** 3)
        edge_y = max(0.0, 1.0 - (abs(v.co.y) / 1.00) ** 3)
        mound = 0.09 * edge_x * edge_y
        jitter = rng.uniform(-0.022, 0.028)
        v.co.z = 0.05 + mound + jitter

    # Extrude skirt down to Z = -0.05
    boundary_edges = [e for e in bm.edges if e.is_boundary]
    res = bmesh.ops.extrude_edge_only(bm, edges=boundary_edges)
    skirt_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in skirt_verts:
        v.co.z = -0.04

    bm.to_mesh(mesh)
    bm.free()
    set_flat_shading(obj)

    # Wooden border planks around the bed
    planks = [
        ("Borda_Madeira_Norte", (0.0, 1.04, 0.08), (3.24, 0.10, 0.18), (0.02, -0.01, 0.01)),
        ("Borda_Madeira_Sul", (0.0, -1.04, 0.08), (3.24, 0.10, 0.18), (-0.02, 0.01, -0.01)),
        ("Borda_Madeira_Leste", (1.56, 0.0, 0.08), (0.10, 2.02, 0.18), (0.01, 0.02, 0.0)),
        ("Borda_Madeira_Oeste", (-1.56, 0.0, 0.08), (0.10, 2.02, 0.18), (-0.01, -0.02, 0.0)),
    ]
    for name, loc, dim, rot in planks:
        pmesh = bpy.data.meshes.new(name + "_Mesh")
        pobj = bpy.data.objects.new(name, pmesh)
        col.objects.link(pobj)
        pobj.data.materials.append(mats["wood"])
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= dim[0]
            v.co.y *= dim[1]
            v.co.z *= dim[2]
            v.co.x += rng.uniform(-0.008, 0.008)
            v.co.z += rng.uniform(-0.008, 0.008)
        bm.to_mesh(pmesh)
        bm.free()
        pobj.location = loc
        pobj.rotation_euler = rot
        set_flat_shading(pobj)

    return obj


def create_pumpkin(col, name, location, radius, squash_z, rot_euler, mat_body, mat_stem, seed):
    rng = random.Random(seed)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    obj.data.materials.append(mat_body)
    obj.data.materials.append(mat_stem)

    bm = bmesh.new()
    segs = 12
    rings = 7
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)

    for v in bm.verts:
        ang = math.atan2(v.co.y, v.co.x)
        r_xy = math.hypot(v.co.x, v.co.y)
        # Classic pumpkin ribs
        rib = 1.0 - 0.14 * abs(math.cos(ang * (segs / 2.0)))
        # Indent top & bottom slightly
        norm_z = v.co.z / max(radius, 1e-4)
        pole_indent = 1.0 - 0.16 * (norm_z ** 4)
        v.co.x *= rib * rng.uniform(0.97, 1.03)
        v.co.y *= rib * rng.uniform(0.97, 1.03)
        v.co.z *= squash_z * pole_indent

    for f in bm.faces:
        f.material_index = 0

    # Twisted low-poly stem on top
    stem_base_z = radius * squash_z * 0.78
    stem_segs = 5
    stem_rings = 3
    stem_r_base = radius * 0.17
    ring_verts = []
    for r_i in range(stem_rings + 1):
        t = r_i / float(stem_rings)
        z = stem_base_z + t * (radius * 0.48)
        cur_r = stem_r_base * (1.0 - 0.45 * t)
        bend_x = (t ** 1.6) * radius * 0.18
        bend_y = (t ** 1.6) * radius * 0.10
        row = []
        for s_i in range(stem_segs):
            a = s_i * (2.0 * math.pi / stem_segs) + t * 0.5
            vx = bend_x + cur_r * math.cos(a)
            vy = bend_y + cur_r * math.sin(a)
            row.append(bm.verts.new((vx, vy, z)))
        ring_verts.append(row)

    for r_i in range(stem_rings):
        for s_i in range(stem_segs):
            s_next = (s_i + 1) % stem_segs
            f = bm.faces.new([
                ring_verts[r_i][s_i],
                ring_verts[r_i][s_next],
                ring_verts[r_i + 1][s_next],
                ring_verts[r_i + 1][s_i],
            ])
            f.material_index = 1

    cap = bm.faces.new(ring_verts[-1])
    cap.material_index = 1

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    obj.location = location
    obj.rotation_euler = rot_euler
    set_flat_shading(obj)
    return obj


def create_vines_and_leaves(col, mats, pumpkin_specs):
    mesh = bpy.data.meshes.new("Rama_Abobora_Mesh")
    obj = bpy.data.objects.new("Rama_Abobora", mesh)
    col.objects.link(obj)
    obj.data.materials.append(mats["stem"])
    obj.data.materials.append(mats["leaf"])

    bm = bmesh.new()
    rng = random.Random(99)

    # Low-poly jagged leaves near each pumpkin
    for idx, (px, py, pz, pr, _, _) in enumerate(pumpkin_specs):
        for l_i in range(2):
            ang = rng.uniform(0, 2.0 * math.pi)
            dist = pr * rng.uniform(1.05, 1.45)
            lx = px + math.cos(ang) * dist
            ly = py + math.sin(ang) * dist
            lz = 0.12 + rng.uniform(0.0, 0.04)
            scale = pr * rng.uniform(0.65, 0.95)
            rot_z = ang + rng.uniform(-0.5, 0.5)

            # 5-vert low-poly leaf diamond/maple silhouette
            pts = [
                (0.0, 0.0, 0.0),
                (0.45 * scale, 0.32 * scale, 0.04 * scale),
                (1.00 * scale, 0.0, -0.02 * scale),
                (0.45 * scale, -0.32 * scale, 0.04 * scale),
            ]
            lverts = []
            cz = math.cos(rot_z)
            sz = math.sin(rot_z)
            for vx, vy, vz in pts:
                wx = lx + vx * cz - vy * sz
                wy = ly + vx * sz + vy * cz
                wz = lz + vz
                lverts.append(bm.verts.new((wx, wy, wz)))
            f = bm.faces.new(lverts)
            f.material_index = 1

    # Connecting vine segments along the soil
    vine_paths = [
        [(-0.85, -0.45, 0.12), (-0.55, -0.32, 0.13), (0.15, -0.10, 0.14), (0.78, -0.38, 0.12)],
        [(-0.65, 0.25, 0.12), (-0.35, 0.38, 0.13), (0.45, 0.45, 0.13), (0.95, 0.18, 0.12)],
    ]
    for path in vine_paths:
        for i in range(len(path) - 1):
            p0 = mathutils.Vector(path[i])
            p1 = mathutils.Vector(path[i + 1])
            seg_vec = p1 - p0
            perp = mathutils.Vector((-seg_vec.y, seg_vec.x, 0.0)).normalized() * 0.018
            up = mathutils.Vector((0, 0, 0.025))
            v0 = bm.verts.new(p0 - perp)
            v1 = bm.verts.new(p0 + perp)
            v2 = bm.verts.new(p1 + perp)
            v3 = bm.verts.new(p1 - perp)
            v4 = bm.verts.new(p0 + up)
            v5 = bm.verts.new(p1 + up)
            for face_vs in ([v0, v1, v5, v4], [v1, v2, v5], [v2, v3, v4, v5], [v0, v4, v3]):
                f = bm.faces.new(face_vs)
                f.material_index = 0

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    set_flat_shading(obj)
    return obj


def create_watering_can(col, mats, location=(-1.42, -0.88, 0.0), rot_z=0.55):
    mesh = bpy.data.meshes.new("Regador_Mesh")
    obj = bpy.data.objects.new("Regador", mesh)
    col.objects.link(obj)
    obj.data.materials.append(mats["galvanized"])
    obj.data.materials.append(mats["rust"])

    bm = bmesh.new()

    # Main body (tapered low-poly cylinder)
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=10,
        radius1=0.145,
        radius2=0.115,
        depth=0.28,
        matrix=mathutils.Matrix.Translation((0, 0, 0.14)),
    )

    # Top partial lip / rim
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=10,
        radius1=0.118,
        radius2=0.122,
        depth=0.025,
        matrix=mathutils.Matrix.Translation((0, 0, 0.285)),
    )

    # Spout (angled tube from lower front)
    spout_mat = (
        mathutils.Matrix.Translation((0.21, 0.0, 0.20))
        @ mathutils.Matrix.Rotation(math.radians(52), 4, 'Y')
    )
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.028,
        radius2=0.018,
        depth=0.34,
        matrix=spout_mat,
    )

    # Rose head (crivo) at tip of spout
    rose_mat = (
        mathutils.Matrix.Translation((0.35, 0.0, 0.31))
        @ mathutils.Matrix.Rotation(math.radians(52), 4, 'Y')
    )
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.020,
        radius2=0.048,
        depth=0.055,
        matrix=rose_mat,
    )

    # Arched top & back handle (simple low-poly bars)
    handle_bars = [
        ((-0.14, 0.0, 0.24), (0.04, 0.0, 0.42), 0.014),
        ((0.04, 0.0, 0.42), (0.12, 0.0, 0.29), 0.014),
        ((-0.14, 0.0, 0.24), (-0.21, 0.0, 0.14), 0.014),
        ((-0.21, 0.0, 0.14), (-0.14, 0.0, 0.06), 0.014),
    ]
    for p0, p1, r in handle_bars:
        v0 = mathutils.Vector(p0)
        v1 = mathutils.Vector(p1)
        mid = (v0 + v1) * 0.5
        vec = v1 - v0
        quat = vec.normalized().to_track_quat('Z', 'Y')
        mat_bar = mathutils.Matrix.Translation(mid) @ quat.to_matrix().to_4x4()
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=False,
            segments=6,
            radius1=r,
            radius2=r,
            depth=vec.length,
            matrix=mat_bar,
        )

    for f in bm.faces:
        f.material_index = 1 if f.calc_center_median().z < 0.05 else 0

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    obj.location = location
    obj.rotation_euler = (0.0, 0.0, rot_z)
    set_flat_shading(obj)
    return obj


def create_irrigation_post(col, mats, location=(-1.65, 0.0, 0.0)):
    mesh = bpy.data.meshes.new("Poste_Rega_Mesh")
    obj = bpy.data.objects.new("Poste_Rega", mesh)
    col.objects.link(obj)
    obj.data.materials.append(mats["rust"])
    obj.data.materials.append(mats["wood"])

    bm = bmesh.new()

    # Wooden stake / support post behind the pipe
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=mathutils.Matrix.Translation((-0.07, 0.0, 0.58))
        @ mathutils.Matrix.Diagonal((0.11, 0.11, 1.24, 1.0)),
    )
    for f in bm.faces:
        f.material_index = 1

    # Concrete/iron base collar
    res_collar = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.14,
        radius2=0.11,
        depth=0.12,
        matrix=mathutils.Matrix.Translation((0.0, 0.0, 0.06)),
    )

    # Vertical rusted water pipe
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.042,
        radius2=0.042,
        depth=1.06,
        matrix=mathutils.Matrix.Translation((0.03, 0.0, 0.55)),
    )

    # Angled nozzle / spout pointing +X toward the pumpkins
    nozzle_mat = (
        mathutils.Matrix.Translation((0.16, 0.0, 1.03))
        @ mathutils.Matrix.Rotation(math.radians(82), 4, 'Y')
    )
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.036,
        radius2=0.024,
        depth=0.26,
        matrix=nozzle_mat,
    )

    # Corroded valve wheel on the side (-Y)
    wheel_mat = (
        mathutils.Matrix.Translation((0.03, -0.09, 0.86))
        @ mathutils.Matrix.Rotation(math.radians(90), 4, 'X')
    )
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.075,
        radius2=0.075,
        depth=0.022,
        matrix=wheel_mat,
    )

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    obj.location = location
    set_flat_shading(obj)

    # World position of the nozzle tip where sparks emerge
    nozzle_tip_world = mathutils.Vector((location[0] + 0.29, location[1], location[2] + 1.05))
    return obj, nozzle_tip_world


def build_watering_sparks(col, mats, post_obj, nozzle_world, pumpkin_specs):
    arm_data = bpy.data.armatures.new("Rig_Agua_Rega_Data")
    arm_obj = bpy.data.objects.new("Rig_Agua_Rega", arm_data)
    col.objects.link(arm_obj)
    arm_obj.location = nozzle_world

    # Parent to post so moving the post keeps the rig attached
    arm_obj.parent = post_obj
    arm_obj.location = nozzle_world - post_obj.location

    num_sparks = 56
    total_frames = 48
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = total_frames
    bpy.context.scene.render.fps = 24

    rng = random.Random(2026)
    spark_configs = []
    for i in range(num_sparks):
        px, py, pz, pr, squash_z, _ = pumpkin_specs[i % len(pumpkin_specs)]
        # Aim directly onto the upper surface of the pumpkin so water touches it
        target_world = mathutils.Vector((
            px + rng.uniform(-pr * 0.45, pr * 0.45),
            py + rng.uniform(-pr * 0.45, pr * 0.45),
            pz + pr * squash_z * 0.72,
        ))
        rel = target_world - nozzle_world
        start_f = 1 + int(i * total_frames / num_sparks)  # staggered evenly across 48 frames
        dur = rng.randint(18, 24)
        arc_lift = rng.uniform(0.32, 0.56)
        base_scale = rng.uniform(0.65, 1.00)
        rot_speed = (
            rng.uniform(-1.1, 1.1),
            rng.uniform(-1.1, 1.1),
            rng.uniform(-1.1, 1.1),
        )
        spark_configs.append((rel, arc_lift, rot_speed, start_f, dur, base_scale))

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    bone_names = []
    for i in range(num_sparks):
        bname = f"Bone_Faisca_{i + 1}"
        bone_names.append(bname)
        bone = arm_data.edit_bones.new(bname)
        bone.head = (0.0, 0.0, 0.0)
        bone.tail = (0.0, 0.08, 0.0)
        bone.roll = 0.0
    bpy.ops.object.mode_set(mode="OBJECT")

    # Build fine low-poly teardrop water droplet meshes
    sparks_mesh = bpy.data.meshes.new("Faiscas_Agua_Mesh")
    sparks_obj = bpy.data.objects.new("Faiscas_Agua", sparks_mesh)
    col.objects.link(sparks_obj)
    sparks_obj.data.materials.append(mats["sparks"])
    sparks_obj.parent = arm_obj
    mod = sparks_obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm_obj

    bm = bmesh.new()
    for i, bname in enumerate(bone_names):
        sparks_obj.vertex_groups.new(name=bname)
        scale_mult = spark_configs[i][5]
        r_drop = 0.0042 * scale_mult
        z_head = -0.009 * scale_mult
        z_belly = -0.002 * scale_mult
        z_tail = 0.030 * scale_mult

        head = bm.verts.new((0.0, 0.0, z_head))
        tail = bm.verts.new((0.0, 0.0, z_tail))
        b0 = bm.verts.new((r_drop, 0.0, z_belly))
        b1 = bm.verts.new((0.0, r_drop, z_belly))
        b2 = bm.verts.new((-r_drop, 0.0, z_belly))
        b3 = bm.verts.new((0.0, -r_drop, z_belly))

        for tri in (
            [head, b1, b0], [head, b2, b1], [head, b3, b2], [head, b0, b3],
            [tail, b0, b1], [tail, b1, b2], [tail, b2, b3], [tail, b3, b0],
        ):
            bm.faces.new(tri)

    bm.to_mesh(sparks_mesh)
    bm.free()
    set_flat_shading(sparks_obj)

    verts_per_spark = 6
    for i, bname in enumerate(bone_names):
        vg = sparks_obj.vertex_groups[bname]
        vg.add(list(range(i * verts_per_spark, (i + 1) * verts_per_spark)), 1.0, "REPLACE")

    # Keyframe single looping Action: "Anim_Regar"
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="POSE")
    arm_obj.animation_data_create()
    action = bpy.data.actions.new(name="Anim_Regar")
    arm_obj.animation_data.action = action

    for i, (rel, arc_lift, rot_speed, start_f, dur, scale_mult) in enumerate(spark_configs):
        pbone = arm_obj.pose.bones[bone_names[i]]
        pbone.rotation_mode = "XYZ"
        for f in range(1, total_frames + 1):
            offset = (f - start_f) % total_frames
            if offset <= dur:
                t = offset / float(dur)
                x_pos = rel.x * t
                y_pos = rel.y * t
                # Parabolic arc that lands cleanly on the pumpkin at t = 1.0
                z_pos = rel.z * (t ** 1.85) + arc_lift * t * (1.0 - t)

                # Velocity tangent so the droplet tail (+Z) trails behind flight direction
                dz_dt = rel.z * 1.85 * (max(t, 1e-4) ** 0.85) + arc_lift * (1.0 - 2.0 * t)
                vel = mathutils.Vector((rel.x, rel.y, dz_dt))
                if vel.length > 1e-5:
                    euler = (-vel).to_track_quat("Z", "Y").to_euler("XYZ")
                    rx, ry, rz = euler.x, euler.y, euler.z
                else:
                    rx = ry = rz = 0.0

                if t < 0.10:
                    s = (t / 0.10) * scale_mult
                elif t < 0.88:
                    s = scale_mult
                else:
                    # Splash / shrink right as it hits the pumpkin
                    s = scale_mult * max(0.0, 1.0 - (t - 0.88) / 0.12)
            else:
                x_pos = y_pos = z_pos = 0.0
                s = 0.0
                rx = ry = rz = 0.0

            pbone.location = (x_pos, y_pos, z_pos)
            pbone.scale = (s, s, s)
            pbone.rotation_euler = (rx, ry, rz)
            pbone.keyframe_insert(data_path="location", frame=f)
            pbone.keyframe_insert(data_path="scale", frame=f)
            pbone.keyframe_insert(data_path="rotation_euler", frame=f)

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj, sparks_obj


def setup_horror_lighting_and_camera(col):
    # Dark foggy Silent Hill / Resident Evil world background
    world = bpy.data.worlds.new("World_Horror")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.045, 0.052, 0.048, 1.0)
        bg.inputs["Strength"].default_value = 0.65

    # Cold moonlight key
    sun_data = bpy.data.lights.new(name="Luz_Lua", type="SUN")
    sun_data.energy = 1.6
    sun_data.color = (0.72, 0.80, 0.88)
    sun_obj = bpy.data.objects.new(name="Luz_Lua", object_data=sun_data)
    col.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(52), math.radians(15), math.radians(-35))

    # Sickly warm lantern rim near the post
    pt_data = bpy.data.lights.new(name="Luz_Poste_Fria", type="POINT")
    pt_data.energy = 35.0
    pt_data.color = (0.85, 0.72, 0.50)
    pt_obj = bpy.data.objects.new(name="Luz_Poste_Fria", object_data=pt_data)
    col.objects.link(pt_obj)
    pt_obj.location = (-1.1, -1.2, 1.5)

    # Camera framing post, watering can, and pumpkin patch
    cam_data = bpy.data.cameras.new("Camera_Preview")
    cam_obj = bpy.data.objects.new("Camera_Preview", cam_data)
    col.objects.link(cam_obj)
    cam_obj.location = (-0.55, -4.65, 2.05)
    direction = mathutils.Vector((-0.25, 0.0, 0.42)) - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam_obj


def render_previews():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except Exception:
            continue
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.image_settings.file_format = "PNG"

    for frame in (1, 14, 28):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(OUTPUT_DIR, f"preview_frame_{frame:02d}.png")
        bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    scene = bpy.context.scene
    col = scene.collection
    mats = create_materials()

    create_soil_bed(col, mats)

    # (x, y, z, radius, squash_z, rot_euler)
    pumpkin_specs = [
        (-0.58, -0.34, 0.24, 0.23, 0.76, (0.05, -0.06, 0.4)),
        (-0.34,  0.38, 0.22, 0.20, 0.80, (-0.04, 0.05, 1.2)),
        ( 0.14, -0.08, 0.26, 0.27, 0.74, (0.02, 0.04, -0.6)),
        ( 0.44,  0.44, 0.21, 0.19, 0.82, (-0.06, -0.03, 2.1)),
        ( 0.78, -0.36, 0.23, 0.22, 0.75, (0.04, -0.05, 0.9)),
        ( 0.96,  0.18, 0.20, 0.18, 0.78, (-0.03, 0.06, -1.4)),
    ]
    for idx, (px, py, pz, pr, squash_z, rot) in enumerate(pumpkin_specs):
        mat_body = mats["pumpkin_pale"] if idx % 3 == 1 else mats["pumpkin"]
        create_pumpkin(
            col,
            f"Abobora_{idx + 1:02d}",
            (px, py, pz),
            pr,
            squash_z,
            rot,
            mat_body,
            mats["stem"],
            seed=100 + idx,
        )

    create_vines_and_leaves(col, mats, pumpkin_specs)
    create_watering_can(col, mats, location=(-1.38, -0.92, 0.0), rot_z=0.52)
    post_obj, nozzle_world = create_irrigation_post(col, mats, location=(-1.65, 0.0, 0.0))
    build_watering_sparks(col, mats, post_obj, nozzle_world, pumpkin_specs)
    setup_horror_lighting_and_camera(col)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
    )
    render_previews()
    print("BUILD_PLANTACAO_COMPLETED")


if __name__ == "__main__":
    main()
