@tool
class_name GeradorGramaDread
extends MultiMeshInstance3D

## Gerador/distribuidor de vegetação retrô (Crossed Quads em asterisco, 3 planos / 6 triângulos)
## para o MultiMeshInstance3D com variação de altura (grama média e tufos altos de borda/matagal).

@export_group("Geração")
@export var gerar_agora: bool = false:
	set(valor):
		if valor:
			gerar_vegetacao()
		gerar_agora = false
@export var gerar_no_ready: bool = true
@export var semente: int = 2005

@export_group("Área e Quantidade")
@export var quantidade_tufos: int = 4500
@export var area_tamanho: Vector2 = Vector2(260.0, 260.0)
@export var altura_raycast: float = 80.0
@export var mascara_colisao_chao: int = 1

@export_group("Camadas de Altura (Média vs Matagal Alto)")
@export var largura_tufo: float = 1.35
@export var altura_tufo_base: float = 1.0
@export var escala_media_min: float = 0.65
@export var escala_media_max: float = 1.10
@export var escala_alta_min: float = 1.45
@export var escala_alta_max: float = 2.15
@export_range(0.0, 1.0) var chance_tufo_alto_centro: float = 0.12
@export_range(0.0, 1.0) var chance_tufo_alto_bordas: float = 0.68
@export_range(0.1, 1.0) var inicio_borda_normalizada: float = 0.58

@export_group("Evitar Trilhas / Áreas Livres")
@export var splatmap_trilhas: Texture2D
@export_range(0.0, 1.0) var limite_terra_splatmap: float = 0.45
@export var uv_terreno_tamanho: Vector2 = Vector2(419.68, 419.68)
@export var uv_terreno_centro: Vector2 = Vector2(0.0, 53.89)
@export var raios_exclusao_circulares: Array[Vector3] = [] # Vector3(x, z, raio)

@export_group("Material")
@export var material_grama: Material


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if gerar_no_ready and (multimesh == null or multimesh.instance_count == 0):
		gerar_vegetacao()


func gerar_vegetacao() -> void:
	var space_state := _obter_space_state()
	if space_state == null:
		push_warning("GeradorGramaDread: World3D indisponível para raycast.")
		return

	var mesh_tufo := _criar_malha_asterisco(largura_tufo, altura_tufo_base)
	if material_grama != null:
		mesh_tufo.surface_set_material(0, material_grama)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_tufo

	var splat_img: Image = null
	if splatmap_trilhas != null:
		splat_img = splatmap_trilhas.get_image()

	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var transforms: Array[Transform3D] = []

	var meia_x := area_tamanho.x * 0.5
	var meia_z := area_tamanho.y * 0.5
	var centro_global := global_position

	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = mascara_colisao_chao
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var tentativas_max := quantidade_tufos * 2
	var tentativas := 0

	while transforms.size() < quantidade_tufos and tentativas < tentativas_max:
		tentativas += 1

		var lx := rng.randf_range(-meia_x, meia_x)
		var lz := rng.randf_range(-meia_z, meia_z)
		var wx := centro_global.x + lx
		var wz := centro_global.z + lz

		if _esta_em_exclusao(wx, wz):
			continue

		if splat_img != null and _esta_em_trilha_splatmap(splat_img, wx, wz):
			continue

		query.from = Vector3(wx, centro_global.y + altura_raycast, wz)
		query.to = Vector3(wx, centro_global.y - altura_raycast, wz)
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var pos_local := to_local(hit["position"])

		# Camadas de altura: mais tufos altos (altura do peito/cintura) nas bordas/matagais
		var dist_norm := maxf(absf(lx) / maxf(meia_x, 0.01), absf(lz) / maxf(meia_z, 0.01))
		var t_borda := clampf((dist_norm - inicio_borda_normalizada) / maxf(1.0 - inicio_borda_normalizada, 0.01), 0.0, 1.0)
		var chance_alto := lerpf(chance_tufo_alto_centro, chance_tufo_alto_bordas, t_borda)

		var esc_y: float
		var esc_xz: float
		if rng.randf() < chance_alto:
			esc_y = rng.randf_range(escala_alta_min, escala_alta_max)
			esc_xz = rng.randf_range(0.95, 1.35)
		else:
			esc_y = rng.randf_range(escala_media_min, escala_media_max)
			esc_xz = rng.randf_range(0.80, 1.15)

		var rot_y := rng.randf_range(0.0, TAU)
		var basis := Basis.from_euler(Vector3(0.0, rot_y, 0.0)).scaled(Vector3(esc_xz, esc_y, esc_xz))
		transforms.append(Transform3D(basis, pos_local))

	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	multimesh = mm


func _obter_space_state() -> PhysicsDirectSpaceState3D:
	var w3d := get_world_3d()
	if w3d == null:
		return null
	return w3d.direct_space_state


func _esta_em_exclusao(wx: float, wz: float) -> bool:
	for ex in raios_exclusao_circulares:
		var dx := wx - ex.x
		var dz := wz - ex.y
		if dx * dx + dz * dz <= ex.z * ex.z:
			return true
	return false


func _esta_em_trilha_splatmap(img: Image, wx: float, wz: float) -> bool:
	var u := ((wx - uv_terreno_centro.x) / maxf(uv_terreno_tamanho.x, 0.01)) + 0.5
	var v := ((wz - uv_terreno_centro.y) / maxf(uv_terreno_tamanho.y, 0.01)) + 0.5
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return false
	var px := clampi(int(u * float(img.get_width() - 1)), 0, img.get_width() - 1)
	var py := clampi(int(v * float(img.get_height() - 1)), 0, img.get_height() - 1)
	return img.get_pixel(px, py).r >= limite_terra_splatmap


func _criar_malha_asterisco(largura: float, altura: float) -> ArrayMesh:
	# 3 planos retangulares cruzados a 0°, 60° e 120° = 6 triângulos por tufo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var meia_l := largura * 0.5
	var angulos := [0.0, PI / 3.0, 2.0 * PI / 3.0]

	for ang in angulos:
		var ca := cos(ang)
		var sa := sin(ang)
		var normal := Vector3(-sa, 0.0, ca)

		var p0 := Vector3(-meia_l * ca, 0.0, -meia_l * sa)
		var p1 := Vector3(meia_l * ca, 0.0, meia_l * sa)
		var p2 := Vector3(meia_l * ca, altura, meia_l * sa)
		var p3 := Vector3(-meia_l * ca, altura, -meia_l * sa)

		# Triângulo 1
		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p0)

		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p1)

		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p2)

		# Triângulo 2
		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p0)

		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p2)

		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p3)

	return st.commit()
