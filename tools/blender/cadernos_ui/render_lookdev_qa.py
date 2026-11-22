"""Auditoria de materiais/UV por slot e renderizacao Cycles Look-Dev (estudio Neutral + iluminacao Delusio AgX)."""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ARTIFACT_DIR = r"C:\Users\conta\.gemini\antigravity\brain\27d90c8d-1698-4a72-a619-55fca03e4887"


def _auditar_materiais_e_uv_por_slot() -> dict:
    """Verifica color spaces, empacotamento, caminhos relativos e overlap UV por slot de material."""
    imgs_info = []
    for img in bpy.data.images:
        if img.name in ("Render Result", "Viewer Node"):
            continue
        imgs_info.append({
            "name": img.name,
            "filepath": img.filepath,
            "size": list(img.size),
            "colorspace": img.colorspace_settings.name,
            "packed": img.packed_file is not None,
            "users": img.users,
        })

    per_slot_uv = {}
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        uv = bm.loops.layers.uv.active
        slots = {}
        n = 128
        for m_idx in range(max(1, len(ob.material_slots))):
            mat_name = ob.material_slots[m_idx].material.name if m_idx < len(ob.material_slots) and ob.material_slots[m_idx].material else f"slot_{m_idx}"
            owner = np.full((n, n), -1, dtype=np.int64)
            over = np.zeros((n, n), dtype=bool)
            zero_faces = 0
            faces_m = [f for f in bm.faces if f.material_index == m_idx]
            for f in faces_m:
                pts = [l[uv].uv.copy() for l in f.loops]
                a2 = sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))
                if abs(a2) < 1e-12:
                    zero_faces += 1
                    continue
                xs, ys = [p.x for p in pts], [p.y for p in pts]
                x0, x1 = max(0, int(min(xs) * n)), min(n, int(max(xs) * n) + 1)
                y0, y1 = max(0, int(min(ys) * n)), min(n, int(max(ys) * n) + 1)
                if x0 >= x1 or y0 >= y1:
                    continue
                cx, cy = np.meshgrid((np.arange(x0, x1) + 0.5) / n, (np.arange(y0, y1) + 0.5) / n, indexing="ij")
                inside = np.zeros(cx.shape, dtype=bool)
                for i in range(1, len(pts) - 1):
                    t = (pts[0], pts[i], pts[i + 1])
                    d = [(t[(k + 1) % 3].x - t[k].x) * (cy - t[k].y) - (t[(k + 1) % 3].y - t[k].y) * (cx - t[k].x) for k in range(3)]
                    inside |= ((d[0] >= 0) & (d[1] >= 0) & (d[2] >= 0)) | ((d[0] <= 0) & (d[1] <= 0) & (d[2] <= 0))
                win, ov = owner[x0:x1, y0:y1], over[x0:x1, y0:y1]
                ov |= inside & (win >= 0) & (win != f.index)
                win[inside & (win < 0)] = f.index
            used = int((owner >= 0).sum())
            slots[mat_name] = {
                "faces": len(faces_m),
                "zero_area_uv": zero_faces,
                "overlap_pct": round(100.0 * int(over.sum()) / max(used, 1), 2),
                "coverage_pct": round(100.0 * used / (n * n), 1),
            }
        bm.free()
        per_slot_uv[ob.name] = slots

    return {"images": imgs_info, "per_slot_uv": per_slot_uv}


def _bounds(obs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, max((hi - lo).length / 2, 1e-3)


def _add_area_light(name: str, loc: Vector, target: Vector, energy: float, size: float, color=(1.0, 1.0, 1.0)):
    ld = bpy.data.lights.new(name, type="AREA")
    ld.energy = energy
    ld.size = size
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (target - loc).normalized().to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(lo)
    return lo


def _render_lookdev_sheet(asset_kind: str, out_path: str, res: int = 768) -> str:
    sc = bpy.context.scene
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    center, radius = _bounds(meshes)

    # Salva configuracoes existentes e limpa luzes temporariamente apenas em memoria (nao salva .blend!)
    orig_hide = {o: o.hide_render for o in sc.objects}
    for o in sc.objects:
        if o.type == "LIGHT":
            o.hide_render = True

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 40
    sc.cycles.use_denoising = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"

    # Mundo escuro neutro com ambient suave
    world = bpy.data.worlds.new("LD_World")
    sc.world = world
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.045, 0.048, 0.055, 1.0)
    bg.inputs[1].default_value = 0.85

    cam_data = bpy.data.cameras.new("LD_Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("LD_Cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam

    fov = 2.0 * math.atan(cam_data.sensor_width / (2.0 * cam_data.lens))
    dist = radius / math.sin(fov / 2.0) * 1.12
    cam_data.clip_start = 0.01
    cam_data.clip_end = dist * 8.0

    # Luzes de estudio 3 pontos (posicionadas em relacao ao asset)
    if asset_kind == "diario":
        # Diario olha para +X
        l_key = _add_area_light("LD_Key", center + Vector((dist * 1.1, -dist * 0.6, dist * 0.7)), center, 1600.0, radius * 1.4, (1.0, 0.96, 0.90))
        l_fill = _add_area_light("LD_Fill", center + Vector((dist * 0.9, dist * 0.9, dist * 0.2)), center, 700.0, radius * 1.8, (0.85, 0.92, 1.0))
        l_back = _add_area_light("LD_Back", center + Vector((-dist * 1.2, -dist * 0.4, dist * 0.5)), center, 1200.0, radius * 1.6, (1.0, 0.97, 0.92))
        shots = [
            ("front_3q", center + Vector((0.88, -0.45, 0.22)).normalized() * dist * 0.95, center, "Khronos PBR Neutral", False),
            ("back_cover", center + Vector((-0.92, 0.22, 0.14)).normalized() * dist * 0.95, center, "Khronos PBR Neutral", False),
            ("closeup_pages", center + Vector((0.22, -0.05, -0.05)) + Vector((0.88, -0.25, -0.10)).normalized() * (dist * 0.46), center + Vector((0.18, 0.0, 0.0)), "Khronos PBR Neutral", False),
            ("menu_lamp", center + Vector((0.82, -0.52, 0.26)).normalized() * dist * 0.95, center, "AgX", True),
        ]
    else:
        # Caderno tasks: Frente olha -Y, Verso olha +Y, Mola em +X
        l_key = _add_area_light("LD_Key", center + Vector((dist * 0.6, -dist * 1.1, dist * 0.6)), center, 900.0, radius * 1.4, (1.0, 0.96, 0.90))
        l_fill = _add_area_light("LD_Fill", center + Vector((-dist * 0.9, -dist * 0.4, dist * 0.3)), center, 420.0, radius * 1.8, (0.85, 0.92, 1.0))
        l_back = _add_area_light("LD_Back", center + Vector((dist * 0.6, dist * 1.1, dist * 0.5)), center, 850.0, radius * 1.5, (1.0, 0.96, 0.92))
        shots = [
            ("front_3q", center + Vector((0.35, -0.90, 0.22)).normalized() * dist * 0.95, center, "Khronos PBR Neutral", False),
            ("back_3q", center + Vector((0.35, 0.90, 0.22)).normalized() * dist * 0.95, center, "Khronos PBR Neutral", False),
            ("closeup_spiral", Vector((0.42, -0.02, 0.05)) + Vector((0.38, -0.88, 0.20)).normalized() * (dist * 0.42), Vector((0.40, -0.02, 0.05)), "Khronos PBR Neutral", False),
            ("horror_lamp", center + Vector((0.40, -0.88, 0.24)).normalized() * dist * 0.95, center, "AgX", True),
        ]

    tile_paths = []
    for tag, cam_pos, aim, vt, horror_mode in shots:
        if horror_mode:
            # Iluminacao ambar estilo main_menu.tscn + preenchimento frio
            bg.inputs[0].default_value = (0.015, 0.017, 0.022, 1.0)
            bg.inputs[1].default_value = 0.25
            l_key.data.color = (0.92, 0.56, 0.25)
            l_key.data.energy = 1150.0 if asset_kind == "diario" else 620.0
            l_fill.data.color = (0.22, 0.29, 0.38)
            l_fill.data.energy = 260.0 if asset_kind == "diario" else 160.0
            l_back.data.energy = 140.0
        else:
            bg.inputs[0].default_value = (0.045, 0.048, 0.055, 1.0)
            bg.inputs[1].default_value = 0.85
            l_key.data.color = (1.0, 0.96, 0.90)
            l_key.data.energy = 1600.0 if asset_kind == "diario" else 900.0
            l_fill.data.color = (0.85, 0.92, 1.0)
            l_fill.data.energy = 700.0 if asset_kind == "diario" else 420.0
            l_back.data.energy = 1200.0 if asset_kind == "diario" else 850.0

        try:
            sc.view_settings.view_transform = vt
        except TypeError:
            sc.view_settings.view_transform = "Standard"
        sc.view_settings.exposure = 0.1

        cam.location = cam_pos
        cam.rotation_euler = (aim - cam_pos).normalized().to_track_quat("-Z", "Y").to_euler()
        tp = os.path.splitext(out_path)[0] + f"_{tag}.png"
        sc.render.filepath = tp
        bpy.ops.render.render(write_still=True)
        tile_paths.append(tp)

    # Monta contact sheet 2x2
    imgs = []
    for p in tile_paths:
        im = bpy.data.images.load(p, check_existing=False)
        a = np.empty(res * res * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        imgs.append(a.reshape(res, res, 4))
        bpy.data.images.remove(im)

    sheet = np.ones((2 * res, 2 * res, 4), dtype=np.float32)
    for i, a in enumerate(imgs):
        rr, cc = 1 - (i // 2), i % 2
        sheet[rr * res:(rr + 1) * res, cc * res:(cc + 1) * res] = a

    out_im = bpy.data.images.new("LD_Sheet", 2 * res, 2 * res, alpha=True)
    out_im.pixels.foreach_set(sheet.ravel())
    out_im.filepath_raw = out_path
    out_im.file_format = "PNG"
    out_im.save()
    bpy.data.images.remove(out_im)

    for p in tile_paths:
        if os.path.exists(p):
            os.remove(p)

    for o, h in orig_hide.items():
        o.hide_render = h
    return out_path


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", required=True, choices=["diario", "tasks"])
    ap.add_argument("--out", required=True)
    ap.add_argument("--res", type=int, default=768)
    args = ap.parse_args(argv)

    audit = _auditar_materiais_e_uv_por_slot()
    sheet = _render_lookdev_sheet(args.kind, args.out, res=args.res)
    audit["lookdev_sheet"] = sheet
    print("@@JSON@@" + json.dumps(audit, ensure_ascii=False))


if __name__ == "__main__":
    main()
