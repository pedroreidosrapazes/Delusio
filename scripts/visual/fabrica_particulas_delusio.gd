class_name FabricaParticulasDelusio
extends RefCounted

## Fábrica central de sistemas de partículas 3D leves (GPUParticles3D + QuadMesh billboard)
## sem necessidade de novos modelos 3D ou texturas externas.


static func _criar_quad_mesh(tamanho: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = tamanho
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.no_depth_test = false
	mesh.material = mat
	return mesh


static func _montar_sistema(
	nome: String,
	quantidade: int,
	tempo_vida: float,
	tamanho_quad: Vector2,
	cor: Color,
	direcao: Vector3,
	espalhamento: float,
	vel_min: float,
	vel_max: float,
	gravidade: Vector3,
	caixa_emissao: Vector3 = Vector3.ZERO
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quantidade
	p.lifetime = tempo_vida
	p.explosiveness = 0.0
	p.one_shot = false
	p.emitting = true
	p.draw_pass_1 = _criar_quad_mesh(tamanho_quad)

	var proc := ParticleProcessMaterial.new()
	proc.direction = direcao
	proc.spread = espalhamento
	proc.initial_velocity_min = vel_min
	proc.initial_velocity_max = vel_max
	proc.gravity = gravidade
	proc.color = cor
	proc.scale_min = 0.65
	proc.scale_max = 1.25
	if caixa_emissao != Vector3.ZERO:
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		proc.emission_box_extents = caixa_emissao
	p.process_material = proc
	return p


static func criar_vazamento_agua() -> GPUParticles3D:
	return _montar_sistema(
		"ParticulasVazamentoAgua",
		28,
		0.75,
		Vector2(0.05, 0.11),
		Color(0.62, 0.84, 0.98, 0.72),
		Vector3(0.15, -1.0, 0.25),
		22.0,
		1.4,
		2.8,
		Vector3(0.0, -9.2, 0.0),
		Vector3(0.14, 0.14, 0.14)
	)


static func criar_faiscas_eletricas() -> GPUParticles3D:
	var p := _montar_sistema(
		"ParticulasFaiscasEletricas",
		22,
		0.45,
		Vector2(0.04, 0.04),
		Color(1.0, 0.76, 0.28, 0.92),
		Vector3(0.0, 0.45, 1.0),
		65.0,
		1.2,
		3.1,
		Vector3(0.0, -7.5, 0.0),
		Vector3(0.18, 0.24, 0.12)
	)
	p.emitting = false
	return p


static func criar_poeira_rastro() -> GPUParticles3D:
	return _montar_sistema(
		"ParticulasRastro",
		16,
		1.8,
		Vector2(0.06, 0.06),
		Color(0.76, 0.85, 0.94, 0.45),
		Vector3(0.0, 1.0, 0.0),
		35.0,
		0.15,
		0.45,
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.35, 0.12, 0.35)
	)


static func criar_brilho_item() -> GPUParticles3D:
	return _montar_sistema(
		"ParticulasBrilhoItem",
		12,
		1.35,
		Vector2(0.045, 0.045),
		Color(0.95, 0.84, 0.52, 0.62),
		Vector3(0.0, 1.0, 0.0),
		50.0,
		0.12,
		0.32,
		Vector3(0.0, 0.05, 0.0),
		Vector3(0.16, 0.08, 0.16)
	)


static func criar_poeira_lanterna() -> GPUParticles3D:
	var p := _montar_sistema(
		"ParticulasPoeiraLanterna",
		26,
		1.6,
		Vector2(0.025, 0.025),
		Color(1.0, 0.93, 0.76, 0.32),
		Vector3(0.0, 0.15, -1.0),
		35.0,
		0.08,
		0.24,
		Vector3(0.0, -0.02, 0.0),
		Vector3(0.45, 0.32, 1.4)
	)
	p.position = Vector3(0.0, 0.0, -1.6)
	p.emitting = false
	return p


static func criar_nevoa_breu() -> GPUParticles3D:
	return _montar_sistema(
		"ParticulasBreuSul",
		44,
		2.8,
		Vector2(0.24, 0.24),
		Color(0.10, 0.12, 0.16, 0.48),
		Vector3(0.0, 0.35, 0.0),
		75.0,
		0.20,
		0.55,
		Vector3(0.0, 0.04, 0.0),
		Vector3(12.0, 1.6, 8.0)
	)


static func criar_sombra_silhueta() -> GPUParticles3D:
	var p := _montar_sistema(
		"ParticulasSombraSilhueta",
		24,
		1.4,
		Vector2(0.18, 0.18),
		Color(0.05, 0.04, 0.06, 0.68),
		Vector3(0.0, 1.0, 0.0),
		55.0,
		0.25,
		0.75,
		Vector3(0.0, 0.12, 0.0),
		Vector3(0.38, 0.9, 0.38)
	)
	p.position = Vector3(0.0, 1.0, 0.0)
	p.emitting = false
	return p


static func disparar_burst_tarefa(pai: Node, tipo: StringName, pos_global: Vector3) -> GPUParticles3D:
	if pai == null or not is_instance_valid(pai) or not pai.is_inside_tree():
		return null

	var cor := Color(0.85, 0.85, 0.80, 0.85)
	var tam := Vector2(0.08, 0.08)
	var grav := Vector3(0.0, -5.0, 0.0)
	var vel_max := 2.6

	match tipo:
		&"agua":
			cor = Color(0.58, 0.84, 0.98, 0.85)
			tam = Vector2(0.07, 0.10)
			grav = Vector3(0.0, -8.5, 0.0)
		&"folhas":
			cor = Color(0.32, 0.64, 0.30, 0.90)
			tam = Vector2(0.09, 0.06)
			grav = Vector3(0.0, -2.8, 0.0)
			vel_max = 3.0
		&"faiscas":
			cor = Color(1.0, 0.78, 0.26, 0.95)
			tam = Vector2(0.05, 0.05)
			grav = Vector3(0.0, -7.8, 0.0)
			vel_max = 3.8
		&"graos":
			cor = Color(0.84, 0.68, 0.34, 0.90)
			tam = Vector2(0.06, 0.06)
			grav = Vector3(0.0, -7.2, 0.0)
		&"fita", &"item":
			cor = Color(0.86, 0.90, 0.95, 0.82)
			tam = Vector2(0.07, 0.07)
			grav = Vector3(0.0, 0.35, 0.0)
			vel_max = 1.6

	var burst := _montar_sistema(
		"BurstParticulas_%s" % String(tipo),
		24,
		0.65,
		tam,
		cor,
		Vector3(0.0, 1.0, 0.0),
		78.0,
		0.8,
		vel_max,
		grav,
		Vector3(0.22, 0.18, 0.22)
	)
	burst.one_shot = true
	burst.explosiveness = 0.92
	pai.add_child(burst)
	if burst is Node3D:
		(burst as Node3D).global_position = pos_global
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	return burst
