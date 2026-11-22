"""Pipeline completo de correcao geometrica, reconstrucao da mola, UV, bake AO, PBR e exportacao de Caderno dobrado tasks.blend."""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = r"C:\Users\conta\.gemini\config\skills\blender-export-pipelines\scripts"
sys.path.insert(0, SCRIPT_DIR)
sys.path.insert(0, EXPORT_DIR)
import export_asset  # noqa: E402
import gerador_pbr_cadernos as gpbr  # noqa: E402

PROJECT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))
UI_DIR = os.path.join(PROJECT_DIR, "assets", "ui")
TEX_DIR = os.path.join(UI_DIR, "textures")
BLEND_PATH = os.path.join(UI_DIR, "Caderno dobrado tasks.blend")
GLB_PATH = os.path.join(UI_DIR, "caderno_dobrado_tasks.glb")

# Parametros da helice medidos na Mola original
HELIX_CX = 0.52614
HELIX_CY = 0.02001
HELIX_Z0 = -0.80829
HELIX_RX = 1.4223 * 0.07643
HELIX_RY = 1.4223 * 0.09361
HELIX_PITCH = 0.6 * 0.13372
HELIX_TURNS = 20
WIRE_RADIUS = 0.014

# Extremos locais das paginas apos correcao da micro-face 15
PAGE_X_MIN = -0.92746
PAGE_X_MAX = 0.95500
PAGE_Z_ABS = 0.95490
PAGE_Y_MAIN = -0.19000
PAGE_Y_BASE = -0.05520


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * max(0.0, min(1.0, t))


def _helix_point(t: float) -> Vector:
    th = 2.0 * math.pi * t
    return Vector((
        HELIX_CX + HELIX_RX * math.cos(th),
        HELIX_CY + HELIX_RY * math.sin(th),
        HELIX_Z0 + HELIX_PITCH * t,
    ))


def _calcular_furos_uv(inv_frente: Matrix, inv_verso: Matrix) -> tuple:
    """Calcula coordenadas UV exatas dos 20 furos da mola em Frente e Verso."""
    holes_frente = []
    holes_verso = []
    for k in range(HELIX_TURNS):
        best_f = None
        for s in range(400):
            # Metade -X / -Y da volta k (t in [k+0.50, k+0.98])
            t = k + 0.50 + 0.48 * (s / 399.0)
            lp = inv_frente @ _helix_point(t)
            err = abs(lp.y - PAGE_Y_MAIN)
            if best_f is None or err < best_f[0]:
                best_f = (err, lp.x, lp.z)
        lx_f = min(max(best_f[1], PAGE_X_MIN + 0.03), PAGE_X_MAX - 0.025)
        u_f = _lerp(0.02, 0.48, (lx_f - PAGE_X_MIN) / (PAGE_X_MAX - PAGE_X_MIN))
        v_f = _lerp(0.16, 0.98, (best_f[2] + PAGE_Z_ABS) / (2.0 * PAGE_Z_ABS))
        holes_frente.append((u_f, v_f))

        best_v = None
        for s in range(400):
            # Metade -X / +Y da volta k (t in [k+0.15, k+0.55])
            t = k + 0.15 + 0.40 * (s / 399.0)
            lp = inv_verso @ _helix_point(t)
            err = abs(lp.y - PAGE_Y_MAIN)
            if best_v is None or err < best_v[0]:
                best_v = (err, lp.x, lp.z)
        lx_v = min(max(best_v[1], PAGE_X_MIN + 0.03), PAGE_X_MAX - 0.022)
        u_v = _lerp(0.98, 0.52, (lx_v - PAGE_X_MIN) / (PAGE_X_MAX - PAGE_X_MIN))
        v_v = _lerp(0.16, 0.98, (best_v[2] + PAGE_Z_ABS) / (2.0 * PAGE_Z_ABS))
        v_v = min(max(v_v, 0.175), 0.965)
        holes_verso.append((u_v, v_v))

    return holes_frente, holes_verso


def _preparar_metade(ob: bpy.types.Object, novo_nome: str, is_frente: bool,
                     mat_capa: bpy.types.Material, mat_pag: bpy.types.Material) -> Matrix:
    """Corrige micro-face, aplica transform/normais, elimina n-gons e mapeia UVs das paginas."""
    orig_matrix = ob.matrix_world.copy()
    ob.name = novo_nome
    ob.data.name = f"{novo_nome}_Mesh"
    ob.modifiers.clear()

    ob.data.materials.clear()
    ob.data.materials.append(mat_capa)
    ob.data.materials.append(mat_pag)

    while len(ob.data.uv_layers) > 1:
        ob.data.uv_layers.remove(ob.data.uv_layers[-1])
    if not ob.data.uv_layers:
        ob.data.uv_layers.new(name="UVMap")
    ob.data.uv_layers[0].name = "UVMap"
    ob.data.uv_layers[0].active = True

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()

    # Corrige micro-face 15: recua borda +X do bloco de paginas para 0.955
    for v in bm.verts:
        if v.co.x > 0.97265 and v.co.y <= -0.055:
            v.co.x = PAGE_X_MAX

    part_layer = bm.faces.layers.int.get("part_id") or bm.faces.layers.int.new("part_id")
    uv_layer = bm.loops.layers.uv.active

    # Faces originais de pagina: 18 (main), 12 (bot), 19 (right), 20 (top), 21 (left)
    page_ids = {12, 18, 19, 20, 21}
    row_v = (0.02, 0.07) if is_frente else (0.085, 0.135)
    edge_u_boxes = {
        12: (0.02, 0.24),
        20: (0.26, 0.48),
        19: (0.52, 0.74),
        21: (0.76, 0.98),
    }
    u0_capa = 0.02 if is_frente else 0.52

    ngons = []
    for f in bm.faces:
        idx = f.index
        f[part_layer] = idx
        is_page = idx in page_ids
        f.material_index = 1 if is_page else 0
        if len(f.verts) > 4:
            ngons.append(f)

        # Escreve UVs deterministicas (paginas e capa) em coordenadas locais ANTES de triangulacao e transform
        for loop in f.loops:
            co = loop.vert.co
            uv = loop[uv_layer].uv
            if is_page:
                if idx == 18:
                    u_t = (co.x - PAGE_X_MIN) / (PAGE_X_MAX - PAGE_X_MIN)
                    v_t = (co.z + PAGE_Z_ABS) / (2.0 * PAGE_Z_ABS)
                    uv.x = _lerp(0.02, 0.48, u_t) if is_frente else _lerp(0.98, 0.52, u_t)
                    uv.y = _lerp(0.16, 0.98, v_t)
                else:
                    u0, u1 = edge_u_boxes[idx]
                    v_t = (co.y - PAGE_Y_MAIN) / (PAGE_Y_BASE - PAGE_Y_MAIN)
                    if idx in (12, 20):
                        u_t = (co.x - PAGE_X_MIN) / (PAGE_X_MAX - PAGE_X_MIN)
                    else:
                        u_t = (co.z + PAGE_Z_ABS) / (2.0 * PAGE_Z_ABS)
                    uv.x = _lerp(u0, u1, u_t)
                    uv.y = _lerp(row_v[0], row_v[1], v_t)
            else:
                if idx == 8:
                    uv.x = _lerp(u0_capa, u0_capa + 0.28, (co.x + 0.9726) / 1.9452)
                    uv.y = _lerp(0.22, 0.96, (co.z + 1.0) / 2.0)
                elif idx in (0, 1, 4, 5, 9):
                    uv.x = _lerp(u0_capa + 0.30, u0_capa + 0.37, (0.0552 - co.y) / 0.1104)
                    uv.y = _lerp(0.22, 0.96, (co.z + 1.0) / 2.0)
                elif idx in (2, 3, 6, 7, 13):
                    uv.x = _lerp(u0_capa + 0.39, u0_capa + 0.46, (0.0552 - co.y) / 0.1104)
                    uv.y = _lerp(0.22, 0.96, (co.z + 1.0) / 2.0)
                elif idx == 10:
                    uv.x = _lerp(u0_capa, u0_capa + 0.22, (co.x + 1.0) / 2.0)
                    uv.y = _lerp(0.12, 0.19, (co.y + 0.0552) / 0.1104)
                elif idx == 11:
                    uv.x = _lerp(u0_capa + 0.24, u0_capa + 0.46, (co.x + 1.0) / 2.0)
                    uv.y = _lerp(0.12, 0.19, (co.y + 0.0552) / 0.1104)
                elif idx == 14:
                    uv.x = _lerp(u0_capa, u0_capa + 0.10, (co.z + 1.0) / 2.0)
                    uv.y = _lerp(0.02, 0.09, (co.x + 0.9726) / (0.9726 - abs(PAGE_X_MIN)))
                elif idx == 15:
                    uv.x = _lerp(u0_capa + 0.12, u0_capa + 0.22, (co.z + 1.0) / 2.0)
                    uv.y = _lerp(0.02, 0.09, (co.x - PAGE_X_MAX) / (0.9726 - PAGE_X_MAX))
                elif idx == 16:
                    uv.x = _lerp(u0_capa + 0.24, u0_capa + 0.34, (co.x + 0.9726) / 1.9452)
                    uv.y = _lerp(0.02, 0.09, (co.z - PAGE_Z_ABS) / (1.0 - PAGE_Z_ABS))
                elif idx == 17:
                    uv.x = _lerp(u0_capa + 0.36, u0_capa + 0.46, (co.x + 0.9726) / 1.9452)
                    uv.y = _lerp(0.02, 0.09, (co.z + 1.0) / (1.0 - PAGE_Z_ABS))

    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")

    # Aplica matrix_world nas coordenadas locais e garante volume assinalado positivo (normais para fora)
    bm.transform(orig_matrix)
    ob.matrix_world = Matrix.Identity(4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm_t = bm.copy()
    bmesh.ops.triangulate(bm_t, faces=bm_t.faces[:])
    bm_t.verts.ensure_lookup_table()
    ref_o = bm_t.verts[0].co.copy()
    signed_vol = sum(
        (f.verts[0].co - ref_o).dot((f.verts[1].co - ref_o).cross(f.verts[2].co - ref_o)) / 6.0
        for f in bm_t.faces
    )
    bm_t.free()
    if signed_vol < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.normal_update()

    # Smooth shading + sharp/seams em arestas > 55 deg ou fronteira capa<->pagina
    angle_limit = math.radians(55.0)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        is_sharp = False
        if len(e.link_faces) == 2:
            f0, f1 = e.link_faces[0], e.link_faces[1]
            if f0.material_index != f1.material_index:
                is_sharp = True
            elif f0.normal.angle(f1.normal, 0.0) > angle_limit:
                is_sharp = True
        else:
            is_sharp = True
        e.smooth = not is_sharp
        e.seam = is_sharp

    bm.to_mesh(ob.data)
    bm.free()

    return orig_matrix


def _reconstruir_mola(ob: bpy.types.Object, mat_mola: bpy.types.Material) -> None:
    """Reconstroi a espiral como tubo fechado de parede unica (~3.8k tris) com UV cilindrica limpa."""
    ob.name = "Caderno_Mola"
    ob.data.name = "Caderno_Mola_Mesh"
    ob.modifiers.clear()
    ob.matrix_world = Matrix.Identity(4)

    ob.data.materials.clear()
    ob.data.materials.append(mat_mola)

    while len(ob.data.uv_layers) > 1:
        ob.data.uv_layers.remove(ob.data.uv_layers[-1])
    if not ob.data.uv_layers:
        ob.data.uv_layers.new(name="UVMap")
    ob.data.uv_layers[0].name = "UVMap"
    ob.data.uv_layers[0].active = True

    steps_per_turn = 12
    total_steps = HELIX_TURNS * steps_per_turn
    seg_rad = 8

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv.active

    rings = []
    for i in range(total_steps + 1):
        t = HELIX_TURNS * (i / float(total_steps))
        th = 2.0 * math.pi * t
        c = _helix_point(t)
        tang = Vector((
            -2.0 * math.pi * HELIX_RX * math.sin(th),
            2.0 * math.pi * HELIX_RY * math.cos(th),
            HELIX_PITCH,
        )).normalized()
        rad_ref = Vector((math.cos(th), math.sin(th), 0.0)).normalized()
        binorm = tang.cross(rad_ref).normalized()
        norm = binorm.cross(tang).normalized()

        ring = []
        for k in range(seg_rad):
            phi = 2.0 * math.pi * k / float(seg_rad)
            pos = c + WIRE_RADIUS * (math.cos(phi) * norm + math.sin(phi) * binorm)
            ring.append(bm.verts.new(pos))
        rings.append(ring)

    # Paredes do tubo com UV cilindrica continua sem sobreposicao
    for i in range(total_steps):
        v0 = _lerp(0.02, 0.98, i / float(total_steps))
        v1 = _lerp(0.02, 0.98, (i + 1) / float(total_steps))
        r0 = rings[i]
        r1 = rings[i + 1]
        for k in range(seg_rad):
            k_next = (k + 1) % seg_rad
            f = bm.faces.new((r0[k], r0[k_next], r1[k_next], r1[k]))
            f.smooth = True
            f.material_index = 0
            u0 = _lerp(0.02, 0.90, k / float(seg_rad))
            u1 = _lerp(0.02, 0.90, (k + 1) / float(seg_rad))
            uvs = ((u0, v0), (u1, v0), (u1, v1), (u0, v1))
            for loop, uv_val in zip(f.loops, uvs):
                loop[uv_layer].uv = uv_val

    # Tampas fechadas nas duas pontas (triangulos ligados ao centro -> 0 n-gons, 0 boundary edges)
    cap_specs = (
        (rings[0], _helix_point(0.0), True, (0.92, 0.98, 0.02, 0.08)),
        (rings[-1], _helix_point(float(HELIX_TURNS)), False, (0.92, 0.98, 0.10, 0.16)),
    )
    for ring, center_pt, reverse_order, (cu0, cu1, cv0, cv1) in cap_specs:
        vc = bm.verts.new(center_pt)
        uc = 0.5 * (cu0 + cu1)
        vc_uv = 0.5 * (cv0 + cv1)
        rad_uv = 0.45 * (cu1 - cu0)
        for k in range(seg_rad):
            k_next = (k + 1) % seg_rad
            a0 = 2.0 * math.pi * k / float(seg_rad)
            a1 = 2.0 * math.pi * (k + 1) / float(seg_rad)
            uv0 = (uc + rad_uv * math.cos(a0), vc_uv + rad_uv * math.sin(a0))
            uv1 = (uc + rad_uv * math.cos(a1), vc_uv + rad_uv * math.sin(a1))
            if reverse_order:
                f = bm.faces.new((vc, ring[k_next], ring[k]))
                uvs = ((uc, vc_uv), uv1, uv0)
            else:
                f = bm.faces.new((vc, ring[k], ring[k_next]))
                uvs = ((uc, vc_uv), uv0, uv1)
            f.smooth = False
            f.material_index = 0
            for loop, uv_val in zip(f.loops, uvs):
                loop[uv_layer].uv = uv_val

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()

    # Sharp + seam nas bordas das tampas e seam longitudinal em k==0
    for e in bm.edges:
        if len(e.link_faces) == 2:
            f0, f1 = e.link_faces[0], e.link_faces[1]
            if f0.smooth != f1.smooth:
                e.smooth = False
                e.seam = True
            else:
                e.smooth = True
                # Seam longitudinal onde u=0.02 encontra u=0.90
                u_vals = set()
                for lf in (f0, f1):
                    for l in lf.loops:
                        if l.vert in e.verts:
                            u_vals.add(round(l[uv_layer].uv.x, 3))
                if 0.02 in u_vals and 0.90 in u_vals:
                    e.seam = True

    bm.to_mesh(ob.data)
    bm.free()


def run() -> dict:
    os.makedirs(TEX_DIR, exist_ok=True)
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

    mat_capa = bpy.data.materials.get("M_CadernoTasks_Capa") or bpy.data.materials.new("M_CadernoTasks_Capa")
    mat_pag = bpy.data.materials.get("M_CadernoTasks_Paginas") or bpy.data.materials.new("M_CadernoTasks_Paginas")
    mat_mola = bpy.data.materials.get("M_CadernoTasks_Mola") or bpy.data.materials.new("M_CadernoTasks_Mola")

    ob_frente = bpy.data.objects.get("Caderno") or bpy.data.objects.get("Caderno_Frente")
    ob_verso = bpy.data.objects.get("Caderno.001") or bpy.data.objects.get("Caderno_Verso")
    ob_mola = bpy.data.objects.get("Mola") or bpy.data.objects.get("Caderno_Mola")
    if not (ob_frente and ob_verso and ob_mola):
        raise RuntimeError("Objetos esperados nao encontrados em Caderno dobrado tasks.blend")

    is_original = (ob_frente.name == "Caderno")
    if is_original:
        inv_f = ob_frente.matrix_world.inverted()
        inv_v = ob_verso.matrix_world.inverted()
        _preparar_metade(ob_frente, "Caderno_Frente", True, mat_capa, mat_pag)
        _preparar_metade(ob_verso, "Caderno_Verso", False, mat_capa, mat_pag)
        _reconstruir_mola(ob_mola, mat_mola)
    else:
        # Reexecucao idempotente sobre malha ja limpa: armazena matrizes para projetar os 20 furos
        # Em malha ja transformada, precisamos usar os UVs atuais das paginas para inferir furos diretamente
        inv_f = Matrix.Identity(4)
        inv_v = Matrix.Identity(4)

    if is_original:
        holes_f, holes_v = _calcular_furos_uv(inv_f, inv_v)
    else:
        # Projeta pontos da helice nos triangulos das paginas ja em espaco de mundo
        def project_holes_world(ob_target: bpy.types.Object, is_front_half: bool) -> list:
            me = ob_target.data
            uv_d = me.uv_layers.active.data
            page_polys = [p for p in me.polygons if p.material_index == 1 and p.area > 0.5]
            p_center = sum((p.center for p in page_polys), Vector()) / len(page_polys)
            p_norm = page_polys[0].normal
            xs_p = [me.vertices[vi].co.x for p in page_polys for vi in p.vertices]
            zs_p = [me.vertices[vi].co.z for p in page_polys for vi in p.vertices]
            us_p = [uv_d[li].uv.x for p in page_polys for li in p.loop_indices]
            vs_p = [uv_d[li].uv.y for p in page_polys for li in p.loop_indices]
            x_min, x_max = min(xs_p), max(xs_p)
            z_min, z_max = min(zs_p), max(zs_p)
            u_min, u_max = min(us_p), max(us_p)
            v_min, v_max = min(vs_p), max(vs_p)
            out = []
            for k in range(HELIX_TURNS):
                best = None
                t0, span = (0.50, 0.48) if is_front_half else (0.15, 0.40)
                for s in range(400):
                    pt = _helix_point(k + t0 + span * (s / 399.0))
                    err = abs((pt - p_center).dot(p_norm))
                    if best is None or err < best[0]:
                        best = (err, pt)
                pt = best[1]
                tx = max(0.02, min(0.985, (pt.x - x_min) / max(x_max - x_min, 1e-6)))
                tz = max(0.01, min(0.99, (pt.z - z_min) / max(z_max - z_min, 1e-6)))
                hu = _lerp(u_min, u_max, tx if is_front_half else (1.0 - tx))
                hv = _lerp(v_min, v_max, tz)
                if not is_front_half:
                    hv = min(max(hv, 0.175), 0.965)
                out.append((hu, hv))
            return out

        holes_f = project_holes_world(ob_frente, True)
        holes_v = project_holes_world(ob_verso, False)

    # Bake AO Cycles mantendo os 3 objetos visiveis aos raios
    print("Tasks: executando bake AO Cycles (Paginas 2K)...")
    ao_pag = gpbr.bake_ao_cycles([ob_frente, ob_verso], "M_CadernoTasks_Paginas", res=2048, samples=48, margin_px=16)
    print("Tasks: executando bake AO Cycles (Capa 1K)...")
    ao_capa = gpbr.bake_ao_cycles([ob_frente, ob_verso], "M_CadernoTasks_Capa", res=1024, samples=48, margin_px=12)
    print("Tasks: executando bake AO Cycles (Mola 1K)...")
    ao_mola = gpbr.bake_ao_cycles([ob_mola], "M_CadernoTasks_Mola", res=1024, samples=48, margin_px=12)

    print("Tasks: sintetizando mapas PBR...")
    bc_c, orm_c, n_c = gpbr.gerar_pbr_tasks_capa(1024, ao_capa)
    bc_p, orm_p, n_p = gpbr.gerar_pbr_tasks_paginas(2048, ao_pag, holes_f, holes_v, hole_radius_uv=0.0092)
    bc_m, orm_m, n_m = gpbr.gerar_pbr_tasks_mola(1024, ao_mola)

    paths = {
        "c_bc": os.path.join(TEX_DIR, "T_CadernoTasks_Capa_BC.png"),
        "c_orm": os.path.join(TEX_DIR, "T_CadernoTasks_Capa_ORM.png"),
        "c_n": os.path.join(TEX_DIR, "T_CadernoTasks_Capa_N.png"),
        "p_bc": os.path.join(TEX_DIR, "T_CadernoTasks_Paginas_BC.png"),
        "p_orm": os.path.join(TEX_DIR, "T_CadernoTasks_Paginas_ORM.png"),
        "p_n": os.path.join(TEX_DIR, "T_CadernoTasks_Paginas_N.png"),
        "m_bc": os.path.join(TEX_DIR, "T_CadernoTasks_Mola_BC.png"),
        "m_orm": os.path.join(TEX_DIR, "T_CadernoTasks_Mola_ORM.png"),
        "m_n": os.path.join(TEX_DIR, "T_CadernoTasks_Mola_N.png"),
    }

    gpbr.salvar_png_rgb(bc_c, paths["c_bc"])
    gpbr.salvar_png_rgb(orm_c, paths["c_orm"])
    gpbr.salvar_png_rgb(n_c, paths["c_n"])
    gpbr.salvar_png_rgb(bc_p, paths["p_bc"])
    gpbr.salvar_png_rgb(orm_p, paths["p_orm"])
    gpbr.salvar_png_rgb(n_p, paths["p_n"])
    gpbr.salvar_png_rgb(bc_m, paths["m_bc"])
    gpbr.salvar_png_rgb(orm_m, paths["m_orm"])
    gpbr.salvar_png_rgb(n_m, paths["m_n"])

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    gpbr.construir_material_pbr_orm("M_CadernoTasks_Capa", paths["c_bc"], paths["c_orm"], paths["c_n"], strength_normal=0.95, pack=True)
    gpbr.construir_material_pbr_orm("M_CadernoTasks_Paginas", paths["p_bc"], paths["p_orm"], paths["p_n"], strength_normal=0.95, pack=True)
    gpbr.construir_material_pbr_orm("M_CadernoTasks_Mola", paths["m_bc"], paths["m_orm"], paths["m_n"], strength_normal=0.80, pack=True)

    for o in bpy.data.objects:
        o.select_set(False)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    return {
        "holes_frente_first3": [(round(u, 4), round(v, 4)) for u, v in holes_f[:3]],
        "holes_verso_first3": [(round(u, 4), round(v, 4)) for u, v in holes_v[:3]],
        "holes_verso_last2": [(round(u, 4), round(v, 4)) for u, v in holes_v[-2:]],
    }


if __name__ == "__main__":
    info = run()
    if os.path.exists(GLB_PATH):
        os.remove(GLB_PATH)
    print("Tasks: exportando GLB para Godot...")
    res = export_asset.run(
        preset="godot",
        objects=["Caderno_Frente", "Caderno_Verso", "Caderno_Mola"],
        out=GLB_PATH,
        set=["export_tangents=True"],
    )
    res["holes_info"] = info
    print("@@JSON@@" + json.dumps(res, ensure_ascii=False))
