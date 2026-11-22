"""Pipeline completo de limpeza, UV, bake AO, texturizacao PBR 2K e exportacao de Diario.blend."""
import json
import math
import os
import sys

import bmesh
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = r"C:\Users\conta\.gemini\config\skills\blender-export-pipelines\scripts"
sys.path.insert(0, SCRIPT_DIR)
sys.path.insert(0, EXPORT_DIR)
import export_asset  # noqa: E402
import gerador_pbr_cadernos as gpbr  # noqa: E402

PROJECT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))
UI_DIR = os.path.join(PROJECT_DIR, "assets", "ui")
TEX_DIR = os.path.join(UI_DIR, "textures")
BLEND_PATH = os.path.join(UI_DIR, "Diário.blend")
GLB_PATH = os.path.join(UI_DIR, "diario_menu.glb")

# IDs de sub-regiao (face layer "part_id")
PART_COVER_BACK = 0
PART_COVER_OTHER = 1
PART_PAGE_LEFT = 2
PART_PAGE_RIGHT = 3
PART_EDGE_CURVE_L = 4
PART_EDGE_CURVE_R = 5
PART_EDGE_TOP_L = 6
PART_EDGE_TOP_R = 7
PART_EDGE_BOT_L = 8
PART_EDGE_BOT_R = 9
PART_EDGE_STEP_L = 10
PART_EDGE_STEP_R = 11


def _classificar_face_original(f) -> int:
    xs = [v.co.x for v in f.verts]
    cx, cy, cz = f.calc_center_median()
    n = f.normal
    if max(xs) <= 0.0715:
        if n.x < -0.95:
            return PART_COVER_BACK
        return PART_COVER_OTHER
    if abs(n.z) > 0.9:
        if cz > 0.0:
            return PART_EDGE_TOP_L if cy < 0.0 else PART_EDGE_TOP_R
        return PART_EDGE_BOT_L if cy < 0.0 else PART_EDGE_BOT_R
    if f.calc_area() > 1.5:
        return PART_PAGE_LEFT if cy < 0.0 else PART_PAGE_RIGHT
    if abs(n.y) > 0.98 and abs(cx - 0.078) < 0.02:
        return PART_EDGE_STEP_L if cy < 0.0 else PART_EDGE_STEP_R
    return PART_EDGE_CURVE_L if cy < 0.0 else PART_EDGE_CURVE_R


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * max(0.0, min(1.0, t))


def run() -> None:
    os.makedirs(TEX_DIR, exist_ok=True)
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

    ob = bpy.data.objects.get("Diario") or bpy.data.objects.get("Cube")
    if ob is None:
        raise RuntimeError("Objeto 'Diario' ou 'Cube' nao encontrado em Diário.blend")
    ob.name = "Diario"
    ob.data.name = "Diario_Mesh"

    # Garante 2 slots de material: 0 = M_Diario_Capa, 1 = M_Diario_Paginas
    ob.data.materials.clear()
    mat_capa = bpy.data.materials.get("M_Diario_Capa") or bpy.data.materials.new("M_Diario_Capa")
    mat_pag = bpy.data.materials.get("M_Diario_Paginas") or bpy.data.materials.new("M_Diario_Paginas")
    ob.data.materials.append(mat_capa)
    ob.data.materials.append(mat_pag)

    # Limpa N-gons mantendo grupos intactos
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    part_layer = bm.faces.layers.int.get("part_id") or bm.faces.layers.int.new("part_id")

    ngons = []
    for f in bm.faces:
        pid = _classificar_face_original(f)
        f[part_layer] = pid
        f.material_index = 0 if pid in (PART_COVER_BACK, PART_COVER_OTHER) else 1
        if len(f.verts) > 4:
            ngons.append(f)

    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
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
            # Separa capa traseira plana das bordas chanfradas
            elif {f0[part_layer], f1[part_layer]} == {PART_COVER_BACK, PART_COVER_OTHER}:
                is_sharp = True
            # Vinco central nitido entre pagina esquerda e pagina direita
            elif {f0[part_layer], f1[part_layer]} == {PART_PAGE_LEFT, PART_PAGE_RIGHT}:
                is_sharp = True
        else:
            is_sharp = True
        e.smooth = not is_sharp
        e.seam = is_sharp

    bm.to_mesh(ob.data)
    bm.free()

    # Garante UVMap unico
    while len(ob.data.uv_layers) > 1:
        ob.data.uv_layers.remove(ob.data.uv_layers[-1])
    if not ob.data.uv_layers:
        ob.data.uv_layers.new(name="UVMap")
    ob.data.uv_layers[0].name = "UVMap"
    ob.data.uv_layers[0].active = True

    # Smart Project apenas para as faces secundarias da capa (PART_COVER_OTHER)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.data.objects:
        o.select_set(o == ob)

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    part_layer = bm.faces.layers.int.get("part_id")
    for f in bm.faces:
        f.select = (f[part_layer] == PART_COVER_OTHER)
    bm.select_flush(False)
    bm.to_mesh(ob.data)
    bm.free()

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.03, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Agora escreve UVs deterministicas finais para todas as regioes
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv_layer = bm.loops.layers.uv.active
    part_layer = bm.faces.layers.int.get("part_id")

    # Remapeia PART_COVER_OTHER para U [0.02, 0.98], V [0.02, 0.34]
    other_uvs = [l[uv_layer].uv for f in bm.faces if f[part_layer] == PART_COVER_OTHER for l in f.loops]
    min_u = min(u.x for u in other_uvs)
    max_u = max(u.x for u in other_uvs)
    min_v = min(u.y for u in other_uvs)
    max_v = max(u.y for u in other_uvs)
    du_o = max(max_u - min_u, 1e-6)
    dv_o = max(max_v - min_v, 1e-6)
    for uv in other_uvs:
        uv.x = 0.02 + 0.96 * ((uv.x - min_u) / du_o)
        uv.y = 0.02 + 0.32 * ((uv.y - min_v) / dv_o)

    # Mapeia verso principal da capa + todas as paginas e faixas de corte
    back_box = (0.04, 0.96, 0.38, 0.96)
    strip_boxes = {
        PART_EDGE_CURVE_L: (0.02, 0.24, 0.02, 0.075),
        PART_EDGE_CURVE_R: (0.26, 0.48, 0.02, 0.075),
        PART_EDGE_TOP_L: (0.52, 0.74, 0.02, 0.075),
        PART_EDGE_TOP_R: (0.76, 0.98, 0.02, 0.075),
        PART_EDGE_BOT_L: (0.02, 0.24, 0.095, 0.15),
        PART_EDGE_BOT_R: (0.26, 0.48, 0.095, 0.15),
        PART_EDGE_STEP_L: (0.52, 0.74, 0.095, 0.15),
        PART_EDGE_STEP_R: (0.76, 0.98, 0.095, 0.15),
    }

    for f in bm.faces:
        pid = f[part_layer]
        for loop in f.loops:
            co = loop.vert.co
            uv = loop[uv_layer].uv
            if pid == PART_COVER_BACK:
                # Olhando o verso (-X) com +Z para cima, +Y fica a esquerda e -Y a direita
                u_t = (1.6428 - co.y) / (2.0 * 1.6428)
                v_t = (co.z + 0.9628) / (2.0 * 0.9628)
                uv.x = _lerp(back_box[0], back_box[1], u_t)
                uv.y = _lerp(back_box[2], back_box[3], v_t)
            elif pid == PART_PAGE_LEFT:
                u_t = (co.y + 1.3594) / 1.3594
                v_t = (co.z + 0.895) / 1.79
                uv.x = _lerp(0.02, 0.49, u_t)
                uv.y = _lerp(0.18, 0.98, v_t)
            elif pid == PART_PAGE_RIGHT:
                u_t = co.y / 1.3594
                v_t = (co.z + 0.895) / 1.79
                uv.x = _lerp(0.51, 0.98, u_t)
                uv.y = _lerp(0.18, 0.98, v_t)
            elif pid in strip_boxes:
                u0, u1, v0, v1 = strip_boxes[pid]
                if pid in (PART_EDGE_CURVE_L, PART_EDGE_CURVE_R):
                    u_t = (co.z + 0.895) / 1.79
                    v_t = (co.x - 0.0854) / (0.301 - 0.0854)
                elif pid in (PART_EDGE_TOP_L, PART_EDGE_BOT_L):
                    u_t = (co.y + 1.575) / 1.575
                    v_t = (co.x - 0.071) / (0.301 - 0.071)
                elif pid in (PART_EDGE_TOP_R, PART_EDGE_BOT_R):
                    u_t = co.y / 1.575
                    v_t = (co.x - 0.071) / (0.301 - 0.071)
                else:  # STEP_L / STEP_R
                    u_t = (co.z + 0.895) / 1.79
                    v_t = (co.x - 0.0711) / (0.0854 - 0.0711)
                uv.x = _lerp(u0, u1, u_t)
                uv.y = _lerp(v0, v1, v_t)

    bm.to_mesh(ob.data)
    bm.free()

    # Bake AO real no Cycles (2048x2048, 48 samples) para cada slot
    print("Diario: executando bake AO Cycles (Capa)...")
    ao_capa = gpbr.bake_ao_cycles([ob], "M_Diario_Capa", res=2048, samples=48, margin_px=16)
    print("Diario: executando bake AO Cycles (Paginas)...")
    ao_pag = gpbr.bake_ao_cycles([ob], "M_Diario_Paginas", res=2048, samples=48, margin_px=16)

    # Gera e salva mapas PBR 2K
    print("Diario: sintetizando mapas PBR 2K...")
    bc_c, orm_c, n_c = gpbr.gerar_pbr_diario_capa(2048, ao_capa, back_box)
    bc_p, orm_p, n_p = gpbr.gerar_pbr_diario_paginas(2048, ao_pag)

    p_c_bc = os.path.join(TEX_DIR, "T_Diario_Capa_BC.png")
    p_c_orm = os.path.join(TEX_DIR, "T_Diario_Capa_ORM.png")
    p_c_n = os.path.join(TEX_DIR, "T_Diario_Capa_N.png")
    p_p_bc = os.path.join(TEX_DIR, "T_Diario_Paginas_BC.png")
    p_p_orm = os.path.join(TEX_DIR, "T_Diario_Paginas_ORM.png")
    p_p_n = os.path.join(TEX_DIR, "T_Diario_Paginas_N.png")

    gpbr.salvar_png_rgb(bc_c, p_c_bc)
    gpbr.salvar_png_rgb(orm_c, p_c_orm)
    gpbr.salvar_png_rgb(n_c, p_c_n)
    gpbr.salvar_png_rgb(bc_p, p_p_bc)
    gpbr.salvar_png_rgb(orm_p, p_p_orm)
    gpbr.salvar_png_rgb(n_p, p_p_n)

    # Salva primeiro para garantir bpy.data.filepath definido ao resolver relpath
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    gpbr.construir_material_pbr_orm("M_Diario_Capa", p_c_bc, p_c_orm, p_c_n, strength_normal=1.0, pack=True)
    gpbr.construir_material_pbr_orm("M_Diario_Paginas", p_p_bc, p_p_orm, p_p_n, strength_normal=0.85, pack=True)

    for o in bpy.data.objects:
        o.select_set(False)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print(f"Diario salvo em {BLEND_PATH}")


if __name__ == "__main__":
    run()
    if os.path.exists(GLB_PATH):
        os.remove(GLB_PATH)
    print("Diario: exportando GLB para Godot...")
    res = export_asset.run(
        preset="godot",
        objects=["Diario"],
        out=GLB_PATH,
        set=["export_tangents=True"],
    )
    print("@@JSON@@" + json.dumps(res, ensure_ascii=False))
