import bpy
import bmesh
import math
import mathutils

def create_sparks_material():
    mat_name = "M_Faiscas_Brancas"
    mat = bpy.data.materials.get(mat_name)
    if not mat:
        mat = bpy.data.materials.new(name=mat_name)
    
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    output_node = nodes.new(type='ShaderNodeOutputMaterial')
    output_node.location = (400, 0)
    
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    
    # Ultra-bright white emission for high visibility in horror lighting
    if hasattr(bsdf.inputs['Base Color'], 'default_value'):
        bsdf.inputs['Base Color'].default_value = (1.0, 1.0, 1.0, 1.0)
    if 'Roughness' in bsdf.inputs:
        bsdf.inputs['Roughness'].default_value = 0.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 1.0
    elif 'Specular' in bsdf.inputs:
        bsdf.inputs['Specular'].default_value = 1.0
        
    if 'Emission Color' in bsdf.inputs:
        bsdf.inputs['Emission Color'].default_value = (1.0, 1.0, 1.0, 1.0)
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = 12.0
    elif 'Emission' in bsdf.inputs:
        bsdf.inputs['Emission'].default_value = (1.0, 1.0, 1.0, 1.0)

    links.new(bsdf.outputs['BSDF'], output_node.inputs['Surface'])
    return mat

def create_hole_in_pipe(pipe_obj):
    me = pipe_obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    
    uv_lay = bm.loops.layers.uv.active

    # Find the front-facing vertical face (Face 19, normal = (0, 1, 0))
    target_face = None
    for f in bm.faces:
        if abs(f.normal.y - 1.0) < 0.05 and min(v.co.z for v in f.verts) < -2.0 and max(v.co.z for v in f.verts) > 6.0:
            target_face = f
            break
            
    if not target_face:
        print("Notice: Front face already has hole or not found")
        bm.free()
        return

    corners = list(target_face.verts)
    v_tl = [v for v in corners if v.co.x < -1.2 and v.co.z > 0][0]
    v_tr = [v for v in corners if v.co.x > -1.2 and v.co.z > 0][0]
    v_br = [v for v in corners if v.co.x > -1.2 and v.co.z < 0][0]
    v_bl = [v for v in corners if v.co.x < -1.2 and v.co.z < 0][0]

    def get_uv(x, z):
        x_fac = (x - (-1.3914)) / (-1.0791 - (-1.3914))
        z_fac = (z - (-2.1470)) / (6.3531 - (-2.1470))
        u = 0.9286 + x_fac * (0.9529 - 0.9286)
        v = 0.2350 + z_fac * (0.8955 - 0.2350)
        return mathutils.Vector((u, v))

    bmesh.ops.delete(bm, geom=[target_face], context='FACES_ONLY')
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()

    # Hole center and size (prominent puncture, radius ~0.048)
    hc_x = -1.23525
    hc_y = 1.41588
    hc_z = -0.60
    radius = 0.048
    
    num_pts = 8
    rim_verts = []
    for i in range(num_pts):
        ang = i * (2.0 * math.pi / num_pts)
        r = radius * (0.88 if i % 2 == 1 else 1.10)
        vx = hc_x + r * math.cos(ang)
        vz = hc_z + r * math.sin(ang)
        rim_verts.append(bm.verts.new((vx, hc_y, vz)))

    recess_y = 1.34
    inner_verts = []
    for i in range(num_pts):
        v = rim_verts[i]
        inner_verts.append(bm.verts.new((v.co.x, recess_y, v.co.z)))

    core_vert = bm.verts.new((hc_x, recess_y - 0.02, hc_z))

    for i in range(num_pts):
        i_next = (i + 1) % num_pts
        f_wall = bm.faces.new([rim_verts[i], rim_verts[i_next], inner_verts[i_next], inner_verts[i]])
        for l in f_wall.loops:
            l[uv_lay].uv = mathutils.Vector((0.05, 0.05))

    for i in range(num_pts):
        i_next = (i + 1) % num_pts
        f_core = bm.faces.new([core_vert, inner_verts[i], inner_verts[i_next]])
        for l in f_core.loops:
            l[uv_lay].uv = mathutils.Vector((0.05, 0.05))

    def add_face_with_uv(verts):
        f = bm.faces.new(verts)
        for l in f.loops:
            l[uv_lay].uv = get_uv(l.vert.co.x, l.vert.co.z)
        return f

    # Connect to pipe outer wall
    add_face_with_uv([v_tl, v_tr, rim_verts[2]])
    add_face_with_uv([v_tl, rim_verts[2], rim_verts[3]])
    add_face_with_uv([v_tr, rim_verts[1], rim_verts[2]])

    add_face_with_uv([v_tr, v_br, rim_verts[0]])
    add_face_with_uv([v_tr, rim_verts[0], rim_verts[1]])
    add_face_with_uv([v_br, rim_verts[7], rim_verts[0]])

    add_face_with_uv([v_br, v_bl, rim_verts[6]])
    add_face_with_uv([v_br, rim_verts[6], rim_verts[7]])
    add_face_with_uv([v_bl, rim_verts[5], rim_verts[6]])

    add_face_with_uv([v_bl, v_tl, rim_verts[4]])
    add_face_with_uv([v_bl, rim_verts[4], rim_verts[5]])
    add_face_with_uv([v_tl, rim_verts[3], rim_verts[4]])

    bm.to_mesh(me)
    bm.free()
    me.update()
    print("Hole created in pipe.")

def build_rigged_sparks(collection, sparks_mat):
    # Remove previous sparks and rig
    for obj in list(bpy.data.objects):
        if obj.name.startswith(('Faisca', 'Rig_Faiscas', 'Spark', 'Agua')):
            bpy.data.objects.remove(obj, do_unlink=True)

    hc_world = mathutils.Vector((-1.23525, 11.8741, 1.1271))

    # 1. Create Armature
    arm_data = bpy.data.armatures.new("Rig_Faiscas_Data")
    arm_obj = bpy.data.objects.new("Rig_Faiscas", arm_data)
    collection.objects.link(arm_obj)
    arm_obj.location = hc_world

    pipe_obj = bpy.data.objects.get("Cube")
    if pipe_obj:
        arm_obj.parent = pipe_obj
        arm_obj.location = (-1.23525, 1.4159, -0.60)

    # 12 prominent sparks shooting in an energetic fan pattern
    # (dx, dy_forward, dz, rot_xyz, start_frame, duration, base_scale)
    spark_data = [
        (-0.14, 0.45,  0.10, ( 0.6,  0.9,  1.2),  1, 10, 1.5),
        ( 0.16, 0.52, -0.08, (-0.7,  0.5,  0.9),  3, 10, 1.7),
        (-0.06, 0.38, -0.16, ( 1.1, -0.6,  0.7),  6,  9, 1.3),
        ( 0.12, 0.48,  0.14, ( 0.5,  1.2, -0.8),  8, 10, 1.6),
        (-0.18, 0.55, -0.05, (-0.8, -0.7,  1.0), 11, 10, 1.8),
        ( 0.08, 0.42,  0.12, ( 0.9,  0.4, -1.1), 13,  9, 1.4),
        (-0.10, 0.50,  0.07, ( 0.7, -0.8,  0.6), 16, 10, 1.6),
        ( 0.15, 0.46, -0.12, (-0.6,  1.0, -0.5), 18, 10, 1.5),
        (-0.08, 0.36, -0.10, ( 1.0,  0.5,  0.8), 21,  9, 1.3),
        ( 0.18, 0.54,  0.08, (-0.5, -0.9,  1.1), 23, 10, 1.7),
        (-0.15, 0.44,  0.15, ( 0.8,  0.7, -0.9), 26, 10, 1.5),
        ( 0.07, 0.40, -0.15, (-0.9,  0.6,  0.7), 28,  9, 1.4),
    ]

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')
    
    bone_names = []
    for i in range(len(spark_data)):
        bname = f"Bone_Faisca_{i + 1}"
        bone_names.append(bname)
        bone = arm_data.edit_bones.new(bname)
        bone.head = (0, 0, 0)
        bone.tail = (0, 0.08, 0)
        
    bpy.ops.object.mode_set(mode='OBJECT')

    # 2. Create Sparks Mesh
    sparks_mesh = bpy.data.meshes.new("Faiscas_Mesh")
    sparks_obj = bpy.data.objects.new("Faiscas", sparks_mesh)
    collection.objects.link(sparks_obj)
    sparks_obj.data.materials.append(sparks_mat)
    
    sparks_obj.parent = arm_obj
    mod = sparks_obj.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj

    bm = bmesh.new()
    total_frames = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = total_frames

    # Build 12 3D 4-pointed retro spark stars (distinct, sharp, eye-catching)
    vertex_group_map = {}
    
    for i, bname in enumerate(bone_names):
        vg = sparks_obj.vertex_groups.new(name=bname)
        
        # 4-pointed star low-poly shape:
        # 4 extended points in X and Z, and volume in Y
        r_tip = 0.048 * (spark_data[i][6] / 1.5) # prominent spark tip
        r_inner = 0.016
        thick_y = 0.024
        
        # Central tips:
        p_px = bm.verts.new(( r_tip, 0, 0))       # +X
        p_nx = bm.verts.new((-r_tip, 0, 0))       # -X
        p_pz = bm.verts.new((0, 0,  r_tip))       # +Z
        p_nz = bm.verts.new((0, 0, -r_tip))       # -Z
        
        # Inner corner points:
        c1 = bm.verts.new(( r_inner, 0,  r_inner))
        c2 = bm.verts.new((-r_inner, 0,  r_inner))
        c3 = bm.verts.new((-r_inner, 0, -r_inner))
        c4 = bm.verts.new(( r_inner, 0, -r_inner))
        
        # Front and back 3D apexes:
        front = bm.verts.new((0,  thick_y, 0))
        back  = bm.verts.new((0, -thick_y, 0))
        
        # Connect front faces:
        bm.faces.new([front, p_pz, c1])
        bm.faces.new([front, c1, p_px])
        bm.faces.new([front, p_px, c4])
        bm.faces.new([front, c4, p_nz])
        bm.faces.new([front, p_nz, c3])
        bm.faces.new([front, c3, p_nx])
        bm.faces.new([front, p_nx, c2])
        bm.faces.new([front, c2, p_pz])
        
        # Connect back faces:
        bm.faces.new([back, c1, p_pz])
        bm.faces.new([back, p_px, c1])
        bm.faces.new([back, c4, p_px])
        bm.faces.new([back, p_nz, c4])
        bm.faces.new([back, c3, p_nz])
        bm.faces.new([back, p_nx, c3])
        bm.faces.new([back, c2, p_nx])
        bm.faces.new([back, p_pz, c2])

    bm.to_mesh(sparks_mesh)
    bm.free()

    # Assign vertex weights (10 vertices per spark)
    verts_per_spark = 10
    for i, bname in enumerate(bone_names):
        vg = sparks_obj.vertex_groups[bname]
        v_indices = list(range(i * verts_per_spark, (i + 1) * verts_per_spark))
        vg.add(v_indices, 1.0, 'REPLACE')

    # 3. Create SINGLE ACTION: "Anim_Vazamento"
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='POSE')
    
    arm_obj.animation_data_create()
    action = bpy.data.actions.new(name="Anim_Vazamento")
    arm_obj.animation_data.action = action

    for i, (dx, dy, dz, rot_speed, start_f, dur, scale_mult) in enumerate(spark_data):
        bname = bone_names[i]
        pbone = arm_obj.pose.bones[bname]
        
        for f in range(1, total_frames + 1):
            offset = (f - start_f) % total_frames
            
            if offset <= dur:
                t = offset / float(dur)
                # Rapid burst deceleration
                y_pos = dy * (1.0 - (1.0 - t) ** 2.2)
                x_pos = dx * t
                z_pos = dz * t - 0.05 * (t ** 2) # gravity drop
                
                # Scale curve: pops open to full size very quickly, pulses, then shrinks
                if t < 0.15:
                    s = (t / 0.15) * scale_mult
                elif t < 0.60:
                    # slight pulse
                    pulse = 1.0 + 0.15 * math.sin((t - 0.15) * math.pi * 4.0)
                    s = scale_mult * pulse
                else:
                    s = scale_mult * (1.0 - (t - 0.60) / 0.40)
                    
                rx = rot_speed[0] * t * math.pi * 4.0
                ry = rot_speed[1] * t * math.pi * 4.0
                rz = rot_speed[2] * t * math.pi * 4.0
            else:
                x_pos, y_pos, z_pos = 0.0, 0.0, 0.0
                s = 0.0
                rx, ry, rz = 0.0, 0.0, 0.0

            pbone.location = (x_pos, y_pos, z_pos)
            pbone.scale = (s, s, s)
            pbone.rotation_euler = (rx, ry, rz)
            
            pbone.keyframe_insert(data_path="location", frame=f)
            pbone.keyframe_insert(data_path="scale", frame=f)
            pbone.keyframe_insert(data_path="rotation_euler", frame=f)

    bpy.ops.object.mode_set(mode='OBJECT')
    print("Rigged prominent sparks created successfully with 'Anim_Vazamento' Action!")

def execute():
    scene = bpy.context.scene
    col = scene.collection
    pipe_obj = bpy.data.objects.get("Cube")
    
    create_hole_in_pipe(pipe_obj)
    sparks_mat = create_sparks_material()
    build_rigged_sparks(col, sparks_mat)
    print("EXECUTION COMPLETED!")

if __name__ == '__main__':
    execute()
