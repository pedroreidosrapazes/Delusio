"""Cria o rig minimalista de 4 ossos para Diario.blend e sincroniza diario_menu.glb."""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = r"C:\Users\conta\.gemini\config\skills\blender-export-pipelines\scripts"
sys.path.insert(0, EXPORT_DIR)
import export_asset  # noqa: E402

PROJECT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))
UI_DIR = os.path.join(PROJECT_DIR, "assets", "ui")
BLEND_PATH = os.path.join(UI_DIR, "Diário.blend")
GLB_PATH = os.path.join(UI_DIR, "diario_menu.glb")
BACKUP_PATH = r"c:\Projetos\Delusio\Modelos-3D\Backups-Blender\Diario_pre_rig.blend"


def _limpar_rig_anterior(ob: bpy.types.Object) -> None:
    """Remove modificadores de Armature e rig anterior para manter execucao idempotente."""
    mod_nomes = [m.name for m in ob.modifiers if m.type == "ARMATURE"]
    for nome in mod_nomes:
        ob.modifiers.remove(ob.modifiers[nome])

    if ob.parent is not None and ob.parent.name == "RIG_Diario":
        ob.parent = None
        ob.matrix_parent_inverse = Matrix.Identity(4)

    arm_obj_ant = bpy.data.objects.get("RIG_Diario")
    if arm_obj_ant is not None:
        bpy.data.objects.remove(arm_obj_ant, do_unlink=True)

    arm_data_ant = bpy.data.armatures.get("RIG_Diario_Data")
    if arm_data_ant is not None:
        bpy.data.armatures.remove(arm_data_ant, do_unlink=True)


def run() -> dict:
    """Riga o objeto Diario em 4 ossos (Root, Lombada, Pagina.L, Pagina.R) sem alterar a malha."""
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

    if not os.path.exists(BACKUP_PATH):
        os.makedirs(os.path.dirname(BACKUP_PATH), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BACKUP_PATH, copy=True)

    ob = bpy.data.objects.get("Diario")
    if ob is None or ob.type != "MESH":
        raise RuntimeError("Objeto mesh 'Diario' nao encontrado em Diário.blend")

    if len(ob.data.vertices) != 54 or len(ob.data.polygons) != 80:
        raise RuntimeError(
            f"Contagem inesperada em Diario: {len(ob.data.vertices)} verts / {len(ob.data.polygons)} faces"
        )
    if (
        ob.location.length > 1e-4
        or Vector(ob.rotation_euler).length > 1e-4
        or (ob.scale - Vector((1.0, 1.0, 1.0))).length > 1e-4
    ):
        raise RuntimeError(
            f"Transform nao zerado em Diario: loc={tuple(ob.location)}, rot={tuple(ob.rotation_euler)}, scale={tuple(ob.scale)}"
        )

    _limpar_rig_anterior(ob)

    arm_data = bpy.data.armatures.new("RIG_Diario_Data")
    arm_data.display_type = "OCTAHEDRAL"
    arm_data.show_names = True

    rig_ob = bpy.data.objects.new("RIG_Diario", arm_data)
    rig_ob.location = (0.0, 0.0, 0.0)
    rig_ob.rotation_euler = (0.0, 0.0, 0.0)
    rig_ob.scale = (1.0, 1.0, 1.0)
    rig_ob.show_in_front = True

    colecao_alvo = ob.users_collection[0] if ob.users_collection else bpy.context.scene.collection
    colecao_alvo.objects.link(rig_ob)

    bpy.context.view_layer.objects.active = rig_ob
    for o in bpy.data.objects:
        o.select_set(o == rig_ob)

    with bpy.context.temp_override(
        object=rig_ob,
        active_object=rig_ob,
        selected_objects=[rig_ob],
        selected_editable_objects=[rig_ob],
    ):
        bpy.ops.object.mode_set(mode="EDIT")

    ebones = arm_data.edit_bones

    eb_root = ebones.new("Root")
    eb_root.head = Vector((0.0, 0.0, 0.0))
    eb_root.tail = Vector((0.55, 0.0, 0.0))
    eb_root.roll = 0.0
    eb_root.use_deform = False

    eb_lombada = ebones.new("Lombada")
    eb_lombada.parent = eb_root
    eb_lombada.use_connect = False
    eb_lombada.head = Vector((0.071, 0.0, -1.0))
    eb_lombada.tail = Vector((0.071, 0.0, 1.0))
    eb_lombada.align_roll(Vector((1.0, 0.0, 0.0)))
    eb_lombada.use_deform = True

    eb_pag_l = ebones.new("Pagina.L")
    eb_pag_l.parent = eb_lombada
    eb_pag_l.use_connect = False
    eb_pag_l.head = Vector((0.071, 0.0, 0.0))
    eb_pag_l.tail = Vector((0.071, -1.60, 0.0))
    eb_pag_l.align_roll(Vector((0.0, 0.0, 1.0)))
    eb_pag_l.use_deform = True

    eb_pag_r = ebones.new("Pagina.R")
    eb_pag_r.parent = eb_lombada
    eb_pag_r.use_connect = False
    eb_pag_r.head = Vector((0.071, 0.0, 0.0))
    eb_pag_r.tail = Vector((0.071, 1.60, 0.0))
    eb_pag_r.align_roll(Vector((0.0, 0.0, 1.0)))
    eb_pag_r.use_deform = True

    with bpy.context.temp_override(
        object=rig_ob,
        active_object=rig_ob,
        selected_objects=[rig_ob],
        selected_editable_objects=[rig_ob],
    ):
        bpy.ops.object.mode_set(mode="OBJECT")

    # Bone Collection unica (Blender 5.2+)
    bcoll = arm_data.collections.new("Controles")
    bcoll.is_visible = True
    for bone in arm_data.bones:
        bcoll.assign(bone)

    # Configuracao amigavel no Pose Mode sem criar keyframes/actions
    for pb in rig_ob.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
        if pb.name in ("Pagina.L", "Pagina.R"):
            pb.lock_location = (True, True, True)
            pb.lock_scale = (True, True, True)
            pb.lock_rotation = (True, True, False)
        elif pb.name == "Lombada":
            pb.lock_scale = (True, True, True)

    # Vertex groups deterministicos 1.0 sem modificacao geometrica
    ob.vertex_groups.clear()
    vg_lombada = ob.vertex_groups.new(name="Lombada")
    vg_pag_l = ob.vertex_groups.new(name="Pagina.L")
    vg_pag_r = ob.vertex_groups.new(name="Pagina.R")

    cont_l = 0
    cont_lomb = 0
    cont_r = 0
    for v in ob.data.vertices:
        if v.co.y < -1e-4:
            vg_pag_l.add([v.index], 1.0, "REPLACE")
            cont_l += 1
        elif v.co.y > 1e-4:
            vg_pag_r.add([v.index], 1.0, "REPLACE")
            cont_r += 1
        else:
            vg_lombada.add([v.index], 1.0, "REPLACE")
            cont_lomb += 1

    if (cont_l, cont_lomb, cont_r) != (24, 6, 24):
        raise RuntimeError(f"Pesos inesperados: L={cont_l}, Lombada={cont_lomb}, R={cont_r}")

    ob.parent = rig_ob
    ob.parent_type = "OBJECT"
    ob.matrix_parent_inverse = Matrix.Identity(4)

    mod = ob.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = rig_ob
    mod.use_vertex_groups = True
    mod.use_deform_preserve_volume = False

    # Deixa o rig selecionado/ativo para facilitar entrar em Pose Mode ao abrir o .blend
    for o in bpy.data.objects:
        o.select_set(o == rig_ob)
    bpy.context.view_layer.objects.active = rig_ob

    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    if os.path.exists(GLB_PATH):
        os.remove(GLB_PATH)
    res_export = export_asset.run(
        preset="godot",
        objects=["RIG_Diario", "Diario"],
        out=GLB_PATH,
        set=["export_tangents=True", "export_def_bones=False"],
    )

    return {
        "blend": BLEND_PATH,
        "backup": BACKUP_PATH,
        "backup_exists": os.path.exists(BACKUP_PATH),
        "glb": GLB_PATH,
        "weights": {"Pagina.L": cont_l, "Lombada": cont_lomb, "Pagina.R": cont_r},
        "bones": [b.name for b in arm_data.bones],
        "export": res_export,
    }


if __name__ == "__main__":
    resultado = run()
    print("@@JSON@@" + json.dumps(resultado, ensure_ascii=False))
