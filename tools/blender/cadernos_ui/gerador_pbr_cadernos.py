"""Utilitarios deterministicos de sintese PBR, bake AO no Cycles e wiring ORM para Godot/Blender 5.2."""
import os
import struct
import zlib

import bpy
import numpy as np


# ---------------------------------------------------------------------------
# PNG writer deterministico (sem dependencia de PIL nem color-management)
# ---------------------------------------------------------------------------

def _png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def salvar_png_rgb(arr_vu: np.ndarray, filepath: str) -> None:
    """Salva array float [0..1] (H, W, 3) com V=0 na linha 0 como PNG RGB 8-bit."""
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    h, w, c = arr_vu.shape
    assert c == 3, f"Esperado 3 canais RGB, recebido {c}"
    # PNG armazena scanline 0 no topo (V=1); array interno tem row 0 em V=0.
    img_u8 = np.clip(np.round(arr_vu[::-1] * 255.0), 0.0, 255.0).astype(np.uint8)
    raw = b"".join(b"\x00" + img_u8[y].tobytes() for y in range(h))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw, level=6)
    with open(filepath, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(_png_chunk(b"IHDR", ihdr))
        f.write(_png_chunk(b"IDAT", idat))
        f.write(_png_chunk(b"IEND", b""))


# ---------------------------------------------------------------------------
# Primitivas de ruido vetorial deterministico (NumPy)
# ---------------------------------------------------------------------------

def _value_noise_grid(h: int, w: int, gy: int, gx: int, rng: np.random.Generator, tile: bool = False) -> np.ndarray:
    grid = rng.random((gy + 1, gx + 1), dtype=np.float32)
    if tile:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    else:
        grid[-1, :] = rng.random(gx + 1, dtype=np.float32)
        grid[:, -1] = rng.random(gy + 1, dtype=np.float32)

    ys = np.linspace(0.0, float(gy), h, endpoint=False, dtype=np.float32)
    xs = np.linspace(0.0, float(gx), w, endpoint=False, dtype=np.float32)
    y0 = np.floor(ys).astype(np.int32)
    x0 = np.floor(xs).astype(np.int32)
    fy = ys - y0
    fx = xs - x0
    # Quintic smoothstep
    sy = (fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0))[:, None]
    sx = (fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0))[None, :]

    y1 = y0 + 1
    x1 = x0 + 1
    c00 = grid[y0[:, None], x0[None, :]]
    c10 = grid[y0[:, None], x1[None, :]]
    c01 = grid[y1[:, None], x0[None, :]]
    c11 = grid[y1[:, None], x1[None, :]]

    nx0 = c00 + sx * (c10 - c00)
    nx1 = c01 + sx * (c11 - c01)
    return nx0 + sy * (nx1 - nx0)


def fbm2d(h: int, w: int, base_cells: int = 8, octaves: int = 5, seed: int = 42,
          lacunarity: float = 2.0, gain: float = 0.5, tile: bool = False,
          aspect_y: float = 1.0) -> np.ndarray:
    """Ruido fBm 2D deterministico em [0..1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    freq_x = float(base_cells)
    freq_y = float(base_cells) * aspect_y
    for _ in range(octaves):
        gx = max(2, int(round(freq_x)))
        gy = max(2, int(round(freq_y)))
        acc += amp * _value_noise_grid(h, w, gy, gx, rng, tile=tile)
        norm += amp
        amp *= gain
        freq_x *= lacunarity
        freq_y *= lacunarity
    out = acc / max(norm, 1e-6)
    return np.clip(out, 0.0, 1.0)


def _worley_pebble(h: int, w: int, cells: int = 96, seed: int = 101) -> np.ndarray:
    """Padrao celular leve para grao de couro (0 nas fendas, 1 no centro dos graos)."""
    rng = np.random.default_rng(seed)
    pts_y = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)
    pts_x = rng.uniform(0.15, 0.85, (cells, cells)).astype(np.float32)

    ys = np.linspace(0.0, float(cells), h, endpoint=False, dtype=np.float32)
    xs = np.linspace(0.0, float(cells), w, endpoint=False, dtype=np.float32)
    cy = np.floor(ys).astype(np.int32)[:, None]
    cx = np.floor(xs).astype(np.int32)[None, :]
    fy = ys[:, None]
    fx = xs[None, :]

    min_d2 = np.full((h, w), 10.0, dtype=np.float32)
    sec_d2 = np.full((h, w), 10.0, dtype=np.float32)
    for dy in (-1, 0, 1):
        ny = (cy + dy) % cells
        oy = cy + dy
        for dx in (-1, 0, 1):
            nx = (cx + dx) % cells
            ox = cx + dx
            py = oy + pts_y[ny, nx]
            px = ox + pts_x[ny, nx]
            d2 = (fy - py) ** 2 + (fx - px) ** 2
            better1 = d2 < min_d2
            sec_d2 = np.where(better1, min_d2, np.minimum(sec_d2, d2))
            min_d2 = np.where(better1, d2, min_d2)

    edge = np.sqrt(np.maximum(sec_d2, 0.0)) - np.sqrt(np.maximum(min_d2, 0.0))
    return np.clip(edge * 2.2, 0.0, 1.0)


def altura_para_normal_gl(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """Converte mapa de altura (V, U) em Normal Map tangent-space OpenGL Y+ (H, W, 3) [0..1]."""
    # height[v, u]: v cresce para cima (OpenGL +Y), u cresce para a direita (+X).
    dh_dv, dh_du = np.gradient(height.astype(np.float32))
    nx = -dh_du * strength
    ny = -dh_dv * strength
    nz = np.ones_like(height, dtype=np.float32)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-12)
    rgb = np.stack([nx * inv_len, ny * inv_len, nz * inv_len], axis=-1) * 0.5 + 0.5
    return np.clip(rgb, 0.0, 1.0)


def _smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _lerp3(a: tuple, b: tuple, t: np.ndarray) -> np.ndarray:
    ta = np.asarray(a, dtype=np.float32)[None, None, :]
    tb = np.asarray(b, dtype=np.float32)[None, None, :]
    w = np.clip(t, 0.0, 1.0)[..., None]
    return ta + w * (tb - ta)


def _srgb(r: int, g: int, b: int) -> tuple:
    return (r / 255.0, g / 255.0, b / 255.0)


# ---------------------------------------------------------------------------
# Bake de Ambient Occlusion no Cycles (Blender 5.2)
# ---------------------------------------------------------------------------

def bake_ao_cycles(objetos_bake: list, target_mat_name: str, res: int = 2048, samples: int = 48, margin_px: int = 16) -> np.ndarray:
    """Executa bake de AO no Cycles apenas para target_mat_name e retorna array (res, res) em [0..1]."""
    scene = bpy.context.scene
    prev_engine = scene.render.engine
    prev_device = scene.cycles.device
    prev_samples = scene.cycles.samples
    prev_denoise = scene.cycles.use_denoising
    prev_margin = scene.render.bake.margin
    prev_margin_type = scene.render.bake.margin_type
    prev_clear = scene.render.bake.use_clear

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.bake.margin = margin_px
    scene.render.bake.margin_type = "EXTEND"

    dummy_img = bpy.data.images.new("__tmp_ao_dummy", width=32, height=32, alpha=False, float_buffer=False)
    dummy_img.colorspace_settings.name = "Non-Color"

    ao_final = None
    for ob in objetos_bake:
        img = bpy.data.images.new(f"__tmp_ao_{ob.name}_{target_mat_name}", width=res, height=res, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "Non-Color"
        img.generated_color = (1.0, 1.0, 1.0, 1.0)

        temp_nodes = []
        seen_mats = set()
        for slot in ob.material_slots:
            mat = slot.material
            if mat is None or mat.node_tree is None or mat.name in seen_mats:
                continue
            seen_mats.add(mat.name)
            nt = mat.node_tree
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = img if mat.name == target_mat_name else dummy_img
            for n in nt.nodes:
                n.select = False
            node.select = True
            nt.nodes.active = node
            temp_nodes.append((nt, node))

        scene.render.bake.use_clear = True
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.context.view_layer.objects.active = ob
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob], selected_editable_objects=[ob]):
            res_bake = bpy.ops.object.bake(type="AO")
        if res_bake != {"FINISHED"}:
            raise RuntimeError(f"Bake AO falhou para {ob.name} ({target_mat_name}): {res_bake}")

        buf = np.empty(res * res * 4, dtype=np.float32)
        img.pixels.foreach_get(buf)
        ao_ob = buf.reshape((res, res, 4))[:, :, 0].copy()

        for nt, node in temp_nodes:
            nt.nodes.remove(node)
        bpy.data.images.remove(img)

        if ao_final is None:
            ao_final = ao_ob
        else:
            ao_final = np.minimum(ao_final, ao_ob)

    bpy.data.images.remove(dummy_img)
    scene.render.engine = prev_engine
    scene.cycles.device = prev_device
    scene.cycles.samples = prev_samples
    scene.cycles.use_denoising = prev_denoise
    scene.render.bake.margin = prev_margin
    scene.render.bake.margin_type = prev_margin_type
    scene.render.bake.use_clear = prev_clear
    return np.clip(ao_final, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Construcao de material PBR + ORM + glTF Material Output (Blender 5.2)
# ---------------------------------------------------------------------------

def _gltf_output_group():
    name = "glTF Material Output"
    g = bpy.data.node_groups.get(name)
    if g is None:
        g = bpy.data.node_groups.new(name, "ShaderNodeTree")
        g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        g.nodes.new("NodeGroupOutput")
        g.nodes.new("NodeGroupInput").location = (-200, 0)
    return g


def construir_material_pbr_orm(nome: str, path_bc: str, path_orm: str, path_n: str,
                               strength_normal: float = 1.0, pack: bool = True) -> bpy.types.Material:
    """Cria ou atualiza material Principled BSDF padrao glTF/Godot com BC (sRGB), ORM e Normal."""
    mat = bpy.data.materials.get(nome)
    if mat is None:
        mat = bpy.data.materials.new(nome)
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (420, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (80, 0)
    bsdf.inputs["IOR"].default_value = 1.5
    bsdf.inputs["Specular IOR Level"].default_value = 0.5
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    coord = nt.nodes.new("ShaderNodeTexCoord")
    coord.location = (-1000, 0)
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.location = (-800, 0)
    nt.links.new(coord.outputs["UV"], mapping.inputs["Vector"])

    def load_tex(abs_path: str, cs: str, y_loc: int, label: str):
        abs_norm = os.path.abspath(abs_path)
        for existing in list(bpy.data.images):
            if existing.filepath and os.path.abspath(bpy.path.abspath(existing.filepath)) == abs_norm:
                bpy.data.images.remove(existing)
        img = bpy.data.images.load(abs_norm, check_existing=False)
        img.name = os.path.basename(abs_norm)
        img.colorspace_settings.name = cs
        if bpy.data.filepath:
            img.filepath = bpy.path.relpath(abs_norm)
        if pack:
            img.pack()
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.label = label
        node.location = (-560, y_loc)
        nt.links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        return node

    tex_bc = load_tex(path_bc, "sRGB", 280, "BaseColor")
    tex_orm = load_tex(path_orm, "Non-Color", 0, "ORM")
    tex_n = load_tex(path_n, "Non-Color", -300, "Normal")

    # Cor solida aproximada no viewport Solid/Workbench (diffuse_color sRGB/linear aproximado)
    bc_arr = np.empty(tex_bc.image.size[0] * tex_bc.image.size[1] * 4, dtype=np.float32)
    tex_bc.image.pixels.foreach_get(bc_arr)
    mean_rgb = bc_arr.reshape(-1, 4)[::64, :3].mean(axis=0)
    mat.diffuse_color = (float(mean_rgb[0]), float(mean_rgb[1]), float(mean_rgb[2]), 1.0)

    nt.links.new(tex_bc.outputs["Color"], bsdf.inputs["Base Color"])

    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-240, 0)
    nt.links.new(tex_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])

    gltf_out = nt.nodes.new("ShaderNodeGroup")
    gltf_out.node_tree = _gltf_output_group()
    gltf_out.location = (80, -340)
    nt.links.new(sep.outputs["Red"], gltf_out.inputs["Occlusion"])

    nrm = nt.nodes.new("ShaderNodeNormalMap")
    nrm.space = "TANGENT"
    nrm.inputs["Strength"].default_value = strength_normal
    nrm.location = (-200, -300)
    nt.links.new(tex_n.outputs["Color"], nrm.inputs["Color"])
    nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


# ---------------------------------------------------------------------------
# Sintese PBR especifica dos cadernos (Survival Horror — Capas Escarlates)
# ---------------------------------------------------------------------------

def _aplicar_pautas_pagina(bc: np.ndarray, rough: np.ndarray, height: np.ndarray,
                           u_grid: np.ndarray, v_grid: np.ndarray,
                           u0: float, u1: float, v0: float, v1: float,
                           num_lines: int, ink_rgb: tuple, ink_alpha: float,
                           margin_u: float | None = None,
                           seed: int = 7) -> None:
    """Desenha pautas horizontais sutis e linha de margem opcional dentro de uma regiao UV de pagina."""
    in_page = (u_grid >= u0) & (u_grid <= u1) & (v_grid >= v0) & (v_grid <= v1)
    if not np.any(in_page):
        return
    h, w = bc.shape[:2]
    ink_break = fbm2d(h, w, base_cells=28, octaves=3, seed=seed)
    fade = 0.65 + 0.35 * ink_break

    # Area pautada com folga superior (cabecalho) e inferior
    v_top = v1 - (v1 - v0) * 0.095
    v_bot = v0 + (v1 - v0) * 0.065
    u_pad_l = u0 + (u1 - u0) * 0.055
    u_pad_r = u1 - (u1 - u0) * 0.055
    in_rule_u = (u_grid >= u_pad_l) & (u_grid <= u_pad_r)

    step = (v_top - v_bot) / float(num_lines)
    thickness = step * 0.055
    dist_line = np.abs(((v_grid - v_bot) / step) - np.round((v_grid - v_bot) / step)) * step
    line_mask = (1.0 - _smoothstep(thickness * 0.4, thickness * 1.4, dist_line))
    line_mask *= in_rule_u & (v_grid >= v_bot - thickness) & (v_grid <= v_top + thickness)

    # Linha dupla/cabecalho discreta no topo
    dist_hdr = np.abs(v_grid - (v_top + step * 0.45))
    hdr_mask = (1.0 - _smoothstep(thickness * 0.5, thickness * 1.6, dist_hdr)) * in_rule_u

    total_ink = np.clip((line_mask * ink_alpha + hdr_mask * (ink_alpha * 1.25)) * fade, 0.0, 0.42)

    if margin_u is not None:
        m_thick = (u1 - u0) * 0.0028
        m_mask = (1.0 - _smoothstep(m_thick * 0.4, m_thick * 1.4, np.abs(u_grid - margin_u)))
        m_mask *= (v_grid >= v0 + (v1 - v0) * 0.02) & (v_grid <= v1 - (v1 - v0) * 0.02)
        margin_rgb = _srgb(154, 72, 68)
        bc[:] = _lerp3(tuple([0, 0, 0]), margin_rgb, m_mask * 0.28 * fade) + bc * (1.0 - (m_mask * 0.28 * fade)[..., None])

    ink_arr = np.asarray(ink_rgb, dtype=np.float32)[None, None, :]
    bc[:] = bc * (1.0 - total_ink[..., None]) + ink_arr * total_ink[..., None]
    rough[:] = np.clip(rough - total_ink * 0.04, 0.65, 0.96)
    height[:] = height - total_ink * 0.015


def _gerar_corte_folhas(u_grid: np.ndarray, v_grid: np.ndarray,
                        strip_boxes: list, seed: int = 33) -> tuple:
    """Gera estrias densas de folhas empilhadas para as faixas laterais do bloco de papel."""
    h, w = u_grid.shape
    noise_u = fbm2d(h, w, base_cells=18, octaves=4, seed=seed)
    noise_fine = fbm2d(h, w, base_cells=96, octaves=3, seed=seed + 1)
    bc_strip = np.zeros((h, w, 3), dtype=np.float32)
    h_strip = np.zeros((h, w), dtype=np.float32)
    r_strip = np.full((h, w), 0.90, dtype=np.float32)
    mask_all = np.zeros((h, w), dtype=bool)

    for (u0, u1, v0, v1) in strip_boxes:
        m = (u_grid >= u0) & (u_grid <= u1) & (v_grid >= v0) & (v_grid <= v1)
        mask_all |= m
        # V mapeado ao longo da espessura (x/y) do bloco: 42 folhas por faixa
        v_norm = np.clip((v_grid - v0) / max(v1 - v0, 1e-6), 0.0, 1.0)
        sheet_phase = (v_norm + (noise_u - 0.5) * 0.022) * 34.0
        groove = 0.5 + 0.5 * np.cos(sheet_phase * 2.0 * np.pi)
        sheet_var = np.sin(np.floor(sheet_phase) * 12.9898) * 0.5 + 0.5

        base_paper = _lerp3(_srgb(164, 146, 118), _srgb(206, 190, 158), groove * 0.72 + sheet_var * 0.28)
        # Sujeira leve junto as extremidades da espessura
        edge_v = 1.0 - np.abs(v_norm * 2.0 - 1.0)
        edge_dirt = 1.0 - _smoothstep(0.0, 0.25, edge_v)
        col = base_paper * (1.0 - edge_dirt[..., None] * 0.18 - (1.0 - noise_fine[..., None]) * 0.10)
        bc_strip[m] = col[m]
        h_strip[m] = (groove * 0.45 + noise_fine * 0.15)[m]
        r_strip[m] = (0.86 + (1.0 - groove) * 0.09)[m]

    return bc_strip, r_strip, h_strip, mask_all


def gerar_pbr_diario_capa(res: int, ao: np.ndarray | None, back_box: tuple) -> tuple:
    """Couro vermelho escarlate envelhecido para a capa do Diario do Menu."""
    u = np.linspace(0.0, 1.0, res, dtype=np.float32)[None, :]
    v = np.linspace(0.0, 1.0, res, dtype=np.float32)[:, None]
    u_grid = np.broadcast_to(u, (res, res))
    v_grid = np.broadcast_to(v, (res, res))

    pebble = _worley_pebble(res, res, cells=220, seed=11)
    macro = fbm2d(res, res, base_cells=7, octaves=5, seed=12)
    micro = fbm2d(res, res, base_cells=72, octaves=4, seed=13)
    scratch = fbm2d(res, res, base_cells=28, octaves=3, seed=14, aspect_y=0.18)

    # Paleta vermelho escarlate envelhecido (Survival Horror)
    scarlet_bright = _srgb(178, 22, 24)
    scarlet_mid = _srgb(144, 16, 19)
    scarlet_deep = _srgb(82, 9, 13)
    scuff_crimson = _srgb(154, 64, 52)

    bc = _lerp3(scarlet_deep, scarlet_bright, np.clip(macro * 0.72 + micro * 0.28, 0.0, 1.0))
    # Grao fino e sutil de couro (evita aspecto celular exagerado)
    bc = bc * (0.94 + 0.09 * pebble[..., None])
    bc = _lerp3(scarlet_mid, scarlet_bright, pebble * 0.45 + macro * 0.55) * 0.35 + bc * 0.65

    # Moldura prensada (blind tooling) separada em painel esquerdo e direito, mais vinco da lombada
    u0, u1, v0, v1 = back_box
    in_back = (u_grid >= u0) & (u_grid <= u1) & (v_grid >= v0) & (v_grid <= v1)
    u_mid = 0.5 * (u0 + u1)
    spine_half_w = (u1 - u0) * 0.036

    # Paineis esquerdo e direito da capa dura (fora da faixa da lombada)
    deboss = np.zeros((res, res), dtype=np.float32)
    for pu0, pu1 in ((u0, u_mid - spine_half_w), (u_mid + spine_half_w, u1)):
        in_panel = (u_grid >= pu0) & (u_grid <= pu1) & (v_grid >= v0) & (v_grid <= v1)
        du_p = np.minimum(u_grid - pu0, pu1 - u_grid) / max(pu1 - pu0, 1e-6)
        dv_p = np.minimum(v_grid - v0, v1 - v_grid) / max(v1 - v0, 1e-6)
        d_p = np.minimum(du_p, dv_p)
        g1 = np.exp(-((d_p - 0.075) / 0.005) ** 2)
        g2 = np.exp(-((d_p - 0.098) / 0.0032) ** 2)
        deboss = np.maximum(deboss, np.clip(g1 + 0.7 * g2, 0.0, 1.0) * in_panel)

    # Lombada vertical central da capa com duas dobras confinadas a altura da capa
    dv_back = np.minimum(v_grid - v0, v1 - v_grid) / max(v1 - v0, 1e-6)
    v_cap = _smoothstep(0.015, 0.04, dv_back)
    spine_band = np.exp(-((u_grid - u_mid) / ((u1 - u0) * 0.028)) ** 2) * in_back
    hinge_l = np.exp(-((u_grid - (u_mid - spine_half_w)) / 0.0032) ** 2) * in_back * v_cap
    hinge_r = np.exp(-((u_grid - (u_mid + spine_half_w)) / 0.0032) ** 2) * in_back * v_cap
    hinges = np.clip(hinge_l + hinge_r, 0.0, 1.0)

    # Desgaste nos cantos e bordas da capa + arranhoes finos (sem costura visivel no contorno do back_box)
    du = np.minimum(u_grid - u0, u1 - u_grid) / max(u1 - u0, 1e-6)
    d_border = np.minimum(du, dv_back)
    edge_wear = (1.0 - _smoothstep(0.0, 0.065, d_border)) * in_back * _smoothstep(0.50, 0.80, macro)
    fine_scratch = _smoothstep(0.77, 0.87, scratch) * _smoothstep(0.56, 0.78, micro)
    wear_mask = np.clip(edge_wear * 0.68 + spine_band * 0.25 + fine_scratch * 0.30, 0.0, 0.65)

    bc = bc * (1.0 - deboss[..., None] * 0.38 - hinges[..., None] * 0.44 - spine_band[..., None] * 0.18)
    bc = _lerp3((0, 0, 0), scuff_crimson, wear_mask) + bc * (1.0 - wear_mask[..., None])

    ao_map = ao if ao is not None else np.ones((res, res), dtype=np.float32)
    ao_combined = np.clip(ao_map * (1.0 - deboss * 0.36 - hinges * 0.42) * (0.93 + 0.07 * pebble), 0.15, 1.0)

    rough = np.clip(0.54 + (1.0 - pebble) * 0.12 + (1.0 - macro) * 0.12 + wear_mask * 0.18 + deboss * 0.20, 0.46, 0.90)
    metal = np.zeros((res, res), dtype=np.float32)

    height = pebble * 0.32 + micro * 0.18 - deboss * 0.55 - hinges * 0.60 - fine_scratch * 0.24
    normal = altura_para_normal_gl(height, strength=2.6)
    orm = np.stack([ao_combined, rough, metal], axis=-1)
    return np.clip(bc, 0.0, 1.0), np.clip(orm, 0.0, 1.0), normal


def gerar_pbr_diario_paginas(res: int, ao: np.ndarray | None) -> tuple:
    """Papel creme-sepia envelhecido com pautas, vinco central e estrias laterais para o Diario."""
    u = np.linspace(0.0, 1.0, res, dtype=np.float32)[None, :]
    v = np.linspace(0.0, 1.0, res, dtype=np.float32)[:, None]
    u_grid = np.broadcast_to(u, (res, res))
    v_grid = np.broadcast_to(v, (res, res))

    macro = fbm2d(res, res, base_cells=9, octaves=5, seed=21)
    grain = fbm2d(res, res, base_cells=90, octaves=3, seed=22)
    fibers = fbm2d(res, res, base_cells=56, octaves=3, seed=23, aspect_y=0.35)

    paper_clean = _srgb(218, 202, 170)
    paper_warm = _srgb(196, 174, 136)
    paper_edge = _srgb(148, 120, 86)

    bc = _lerp3(paper_warm, paper_clean, np.clip(0.55 + (macro - 0.5) * 0.55 + (grain - 0.5) * 0.22, 0.0, 1.0))
    bc *= (0.95 + 0.07 * fibers[..., None])
    rough = np.clip(0.80 + (1.0 - grain) * 0.12 + (1.0 - macro) * 0.04, 0.76, 0.95)
    height = grain * 0.22 + fibers * 0.18

    # Pagina esquerda [0.02, 0.49] e direita [0.51, 0.98], V [0.18, 0.98]
    left_box = (0.02, 0.49, 0.18, 0.98)
    right_box = (0.51, 0.98, 0.18, 0.98)

    for (u0, u1, v0, v1), is_left in ((left_box, True), (right_box, False)):
        in_p = (u_grid >= u0) & (u_grid <= u1) & (v_grid >= v0) & (v_grid <= v1)
        un = (u_grid - u0) / (u1 - u0)
        vn = (v_grid - v0) / (v1 - v0)

        # Vinco central (borda direita da pagina esquerda, borda esquerda da pagina direita)
        d_gutter = (1.0 - un) if is_left else un
        gutter_shadow = np.exp(-(d_gutter / 0.055) ** 2) * 0.36 * in_p

        # Envelhecimento restrito as bordas externas (centro limpo para UI)
        d_outer = np.minimum(un if is_left else (1.0 - un), np.minimum(vn, 1.0 - vn))
        edge_stain = (1.0 - _smoothstep(0.0, 0.16, d_outer)) * (0.45 + 0.55 * macro) * in_p

        bc[:] = _lerp3((0, 0, 0), paper_edge, edge_stain * 0.52) + bc * (1.0 - (edge_stain * 0.52)[..., None])
        bc[:] = bc * (1.0 - gutter_shadow[..., None])
        rough[:] = np.clip(rough + edge_stain * 0.05 + gutter_shadow * 0.08, 0.76, 0.96)
        height[:] = height - gutter_shadow * 0.35

    ink = _srgb(122, 102, 82)
    _aplicar_pautas_pagina(bc, rough, height, u_grid, v_grid, *left_box, num_lines=22, ink_rgb=ink, ink_alpha=0.22, margin_u=0.075, seed=24)
    _aplicar_pautas_pagina(bc, rough, height, u_grid, v_grid, *right_box, num_lines=22, ink_rgb=ink, ink_alpha=0.22, margin_u=0.565, seed=25)

    # Faixas laterais do bloco de paginas (V in [0.02, 0.15])
    strips = [
        (0.02, 0.24, 0.02, 0.075),
        (0.26, 0.48, 0.02, 0.075),
        (0.52, 0.74, 0.02, 0.075),
        (0.76, 0.98, 0.02, 0.075),
        (0.02, 0.24, 0.095, 0.15),
        (0.26, 0.48, 0.095, 0.15),
        (0.52, 0.74, 0.095, 0.15),
        (0.76, 0.98, 0.095, 0.15),
    ]
    bc_s, r_s, h_s, m_s = _gerar_corte_folhas(u_grid, v_grid, strips, seed=26)
    bc[m_s] = bc_s[m_s]
    rough[m_s] = r_s[m_s]
    height[m_s] = h_s[m_s]

    ao_map = ao if ao is not None else np.ones((res, res), dtype=np.float32)
    ao_combined = np.clip(ao_map * (0.94 + 0.06 * grain), 0.18, 1.0)
    metal = np.zeros((res, res), dtype=np.float32)
    normal = altura_para_normal_gl(height, strength=1.8)
    orm = np.stack([ao_combined, rough, metal], axis=-1)
    return np.clip(bc, 0.0, 1.0), np.clip(orm, 0.0, 1.0), normal


def gerar_pbr_tasks_capa(res: int, ao: np.ndarray | None) -> tuple:
    """Capa cartonada/textil vermelho escarlate gasta para o Caderno de Tasks."""
    u = np.linspace(0.0, 1.0, res, dtype=np.float32)[None, :]
    v = np.linspace(0.0, 1.0, res, dtype=np.float32)[:, None]
    u_grid = np.broadcast_to(u, (res, res))
    v_grid = np.broadcast_to(v, (res, res))

    # Trama fina de percaline/tecido cartonado
    weave = 0.5 + 0.25 * np.sin(u_grid * res * 0.45) + 0.25 * np.sin(v_grid * res * 0.45)
    macro = fbm2d(res, res, base_cells=8, octaves=5, seed=31)
    micro = fbm2d(res, res, base_cells=64, octaves=4, seed=32)
    edge_noise = fbm2d(res, res, base_cells=16, octaves=4, seed=33)

    scarlet_bright = _srgb(162, 20, 22)
    scarlet_deep = _srgb(80, 10, 13)
    kraft_worn = _srgb(128, 94, 68)

    bc = _lerp3(scarlet_deep, scarlet_bright, np.clip(macro * 0.65 + micro * 0.35, 0.0, 1.0))
    bc *= (0.92 + 0.10 * weave[..., None])

    # Esfolamento discreto nas bordas externas de cada metade (U [0.02,0.48] e [0.52,0.98])
    du_f = np.minimum(u_grid - 0.02, 0.48 - u_grid)
    du_b = np.minimum(u_grid - 0.52, 0.98 - u_grid)
    du = np.where(u_grid < 0.5, du_f, du_b)
    dv = np.minimum(v_grid - 0.02, 0.98 - v_grid)
    d_edge = np.maximum(np.minimum(du, dv), 0.0)
    scuff = (1.0 - _smoothstep(0.0, 0.028, d_edge)) * _smoothstep(0.55, 0.80, edge_noise) * 0.65

    bc = _lerp3((0, 0, 0), kraft_worn, scuff) + bc * (1.0 - scuff[..., None])
    ao_map = ao if ao is not None else np.ones((res, res), dtype=np.float32)
    ao_combined = np.clip(ao_map * (0.94 + 0.06 * weave), 0.15, 1.0)
    rough = np.clip(0.72 + (1.0 - weave) * 0.08 + (1.0 - macro) * 0.10 + scuff * 0.12, 0.66, 0.94)
    metal = np.zeros((res, res), dtype=np.float32)

    height = weave * 0.25 + micro * 0.20 - scuff * 0.28
    normal = altura_para_normal_gl(height, strength=2.2)
    orm = np.stack([ao_combined, rough, metal], axis=-1)
    return np.clip(bc, 0.0, 1.0), np.clip(orm, 0.0, 1.0), normal


def gerar_pbr_tasks_paginas(res: int, ao: np.ndarray | None,
                            holes_front_uv: list, holes_back_uv: list,
                            hole_radius_uv: float = 0.0085) -> tuple:
    """Papel de caderno espiral envelhecido com pautas e 20 furos reais alinhados a mola."""
    u = np.linspace(0.0, 1.0, res, dtype=np.float32)[None, :]
    v = np.linspace(0.0, 1.0, res, dtype=np.float32)[:, None]
    u_grid = np.broadcast_to(u, (res, res))
    v_grid = np.broadcast_to(v, (res, res))

    macro_f = fbm2d(res, res, base_cells=10, octaves=5, seed=41)
    macro_b = fbm2d(res, res, base_cells=10, octaves=5, seed=42)
    macro = np.where(u_grid < 0.5, macro_f, macro_b)
    grain = fbm2d(res, res, base_cells=96, octaves=3, seed=43)
    fibers = fbm2d(res, res, base_cells=60, octaves=3, seed=44, aspect_y=0.35)

    paper_clean = _srgb(212, 198, 170)
    paper_warm = _srgb(190, 172, 138)
    paper_edge = _srgb(148, 124, 90)

    bc = _lerp3(paper_warm, paper_clean, np.clip(0.58 + (macro - 0.5) * 0.50 + (grain - 0.5) * 0.20, 0.0, 1.0))
    bc *= (0.95 + 0.06 * fibers[..., None])
    rough = np.clip(0.80 + (1.0 - grain) * 0.11 + (1.0 - macro) * 0.04, 0.76, 0.95)
    height = grain * 0.20 + fibers * 0.15

    front_box = (0.02, 0.48, 0.16, 0.98)
    back_box = (0.52, 0.98, 0.16, 0.98)

    for (u0, u1, v0, v1) in (front_box, back_box):
        in_p = (u_grid >= u0) & (u_grid <= u1) & (v_grid >= v0) & (v_grid <= v1)
        un = (u_grid - u0) / (u1 - u0)
        vn = (v_grid - v0) / (v1 - v0)
        d_outer = np.minimum(np.minimum(un, 1.0 - un), np.minimum(vn, 1.0 - vn))
        edge_stain = (1.0 - _smoothstep(0.0, 0.14, d_outer)) * (0.45 + 0.55 * macro) * in_p
        bc[:] = _lerp3((0, 0, 0), paper_edge, edge_stain * 0.45) + bc * (1.0 - (edge_stain * 0.45)[..., None])
        rough[:] = np.clip(rough + edge_stain * 0.05, 0.76, 0.96)

    ink = _srgb(106, 112, 122)
    _aplicar_pautas_pagina(bc, rough, height, u_grid, v_grid, *front_box, num_lines=20, ink_rgb=ink, ink_alpha=0.28, margin_u=0.085, seed=45)
    _aplicar_pautas_pagina(bc, rough, height, u_grid, v_grid, *back_box, num_lines=20, ink_rgb=ink, ink_alpha=0.28, margin_u=0.585, seed=46)

    # 20 furos alinhados a espiral na frente e no verso
    hole_dark = _srgb(18, 14, 12)
    ao_holes = np.ones((res, res), dtype=np.float32)
    all_holes = list(holes_front_uv) + list(holes_back_uv)
    # Limita mascara para a faixa de furos
    for (hu, hv) in all_holes:
        dist = np.sqrt((u_grid - hu) ** 2 + (v_grid - hv) ** 2)
        inner = 1.0 - _smoothstep(hole_radius_uv * 0.72, hole_radius_uv * 1.05, dist)
        collar_shadow = (1.0 - _smoothstep(hole_radius_uv * 0.85, hole_radius_uv * 1.95, dist)) * 0.45
        rim_bump = np.exp(-((dist - hole_radius_uv * 1.15) / (hole_radius_uv * 0.25)) ** 2) * 0.25

        bc[:] = _lerp3((0, 0, 0), hole_dark, inner) + bc * (1.0 - inner[..., None])
        bc[:] = bc * (1.0 - collar_shadow[..., None] * 0.55)
        ao_holes = np.minimum(ao_holes, 1.0 - inner * 0.88 - collar_shadow * 0.45)
        height[:] = height - inner * 0.95 + rim_bump
        rough[:] = np.clip(rough + inner * 0.14 + collar_shadow * 0.06, 0.76, 0.98)

    # 8 faixas laterais de corte de paginas em V in [0.02, 0.14]
    strips = [
        (0.02, 0.24, 0.02, 0.07),
        (0.26, 0.48, 0.02, 0.07),
        (0.52, 0.74, 0.02, 0.07),
        (0.76, 0.98, 0.02, 0.07),
        (0.02, 0.24, 0.085, 0.135),
        (0.26, 0.48, 0.085, 0.135),
        (0.52, 0.74, 0.085, 0.135),
        (0.76, 0.98, 0.085, 0.135),
    ]
    bc_s, r_s, h_s, m_s = _gerar_corte_folhas(u_grid, v_grid, strips, seed=47)
    bc[m_s] = bc_s[m_s]
    rough[m_s] = r_s[m_s]
    height[m_s] = h_s[m_s]

    ao_map = ao if ao is not None else np.ones((res, res), dtype=np.float32)
    ao_combined = np.clip(np.minimum(ao_map, ao_holes) * (0.94 + 0.06 * grain), 0.08, 1.0)
    metal = np.zeros((res, res), dtype=np.float32)
    normal = altura_para_normal_gl(height, strength=2.2)
    orm = np.stack([ao_combined, rough, metal], axis=-1)
    return np.clip(bc, 0.0, 1.0), np.clip(orm, 0.0, 1.0), normal


def gerar_pbr_tasks_mola(res: int, ao: np.ndarray | None) -> tuple:
    """Aco galvanizado escurecido com estrias longitudinais e pontos sutis de oxidacao."""
    # U percorre o perimetro do arame, V percorre o comprimento da espiral (20 voltas)
    brush = fbm2d(res, res, base_cells=16, octaves=4, seed=51, tile=True, aspect_y=4.0)
    tarnish = fbm2d(res, res, base_cells=10, octaves=5, seed=52, tile=True)
    rust_noise = fbm2d(res, res, base_cells=14, octaves=4, seed=53, tile=True)
    micro = fbm2d(res, res, base_cells=48, octaves=3, seed=54, tile=True)

    steel_clean = _srgb(164, 159, 152)
    steel_dark = _srgb(102, 97, 92)
    rust_col = _srgb(96, 58, 38)

    bc = _lerp3(steel_dark, steel_clean, np.clip(0.45 + brush * 0.40 + (tarnish - 0.5) * 0.30, 0.0, 1.0))
    rust_mask = _smoothstep(0.66, 0.80, rust_noise) * _smoothstep(0.42, 0.72, micro)
    bc = _lerp3((0, 0, 0), rust_col, rust_mask) + bc * (1.0 - rust_mask[..., None])

    metal = np.clip(0.95 - rust_mask * 0.75, 0.18, 0.96)
    rough = np.clip(0.32 + (1.0 - brush) * 0.14 + (1.0 - tarnish) * 0.10 + rust_mask * 0.42, 0.28, 0.88)

    ao_map = ao if ao is not None else np.ones((res, res), dtype=np.float32)
    ao_combined = np.clip(ao_map * (0.92 + 0.08 * micro), 0.15, 1.0)

    height = brush * 0.25 + micro * 0.15 + rust_mask * 0.22
    normal = altura_para_normal_gl(height, strength=1.6)
    orm = np.stack([ao_combined, rough, metal], axis=-1)
    return np.clip(bc, 0.0, 1.0), np.clip(orm, 0.0, 1.0), normal
