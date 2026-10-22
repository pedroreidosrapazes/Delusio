class_name Silhueta
extends Node3D

## Criatura misteriosa que observa e se teleporta quando o jogador a encara.

@export_category("Detecção e Visão")
@export var camera: Camera3D
@export var fade_speed: float = 8.0
@export var look_threshold: float = 0.92

@export_category("Teleporte")
@export var distancia_minima: float = 15.0
@export var distancia_maxima: float = 30.0
@export var tempo_desaparecida: float = 0.8
@export var tentativas_posicao: int = 10

@onready var mesh_root: Node3D = $mesh
@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

var alpha: float = 1.0
var mudando_posicao: bool = false
var ativa: bool = false
var altura_padrao: float = 0.0

func _ready() -> void:
	altura_padrao = global_position.y
	_preparar_materiais()
	desativar()

func _preparar_materiais() -> void:
	if mesh_root == null:
		return
	var meshes = mesh_root.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if m is MeshInstance3D:
			var mat = m.get_active_material(0)
			if mat:
				var mat_copy = mat.duplicate()
				if mat_copy is BaseMaterial3D:
					mat_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.material_override = mat_copy

func ativar() -> void:
	ativa = true
	visible = true
	alpha = 1.0
	aplicar_alpha()
	mudando_posicao = false
	set_process(true)

func desativar() -> void:
	ativa = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not ativa or camera == null or mudando_posicao:
		return

	# Se saiu da tela
	if notifier and not notifier.is_on_screen():
		fade_to(0.0, delta)
		return

	# Direção da câmera até a silhueta
	var direcao = (global_position - camera.global_position).normalized()
	# Direção para frente da câmera (-Z no padrão Godot)
	var camera_forward = -camera.global_transform.basis.z.normalized()

	# Produto escalar: 1.0 = olhando diretamente, 0.0 = perpendicular
	var dot = camera_forward.dot(direcao)

	if dot >= look_threshold:
		mudando_posicao = true
		criatura_foi_vista()
	else:
		fade_to(1.0, delta)

func criatura_foi_vista() -> void:
	await fade_out()
	await get_tree().create_timer(tempo_desaparecida).timeout
	mover_para_novo_local()
	await fade_in()
	mudando_posicao = false

func mover_para_novo_local() -> void:
	if camera == null:
		return

	var jogador_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z.normalized()
	var melhor_posicao = global_position

	for i in range(tentativas_posicao):
		var angulo = randf_range(0.0, TAU)
		var distancia = randf_range(distancia_minima, distancia_maxima)
		var candidata = jogador_pos + Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		candidata.y = altura_padrao

		var dir_para_candidata = (candidata - jogador_pos).normalized()
		var dot = camera_forward.dot(dir_para_candidata)

		# Posiciona onde o jogador NÃO está olhando de frente no momento
		if dot < 0.4:
			melhor_posicao = candidata
			break
		melhor_posicao = candidata

	global_position = melhor_posicao

func fade_out() -> void:
	while alpha > 0.0:
		alpha = move_toward(alpha, 0.0, fade_speed * get_process_delta_time())
		aplicar_alpha()
		await get_tree().process_frame

func fade_in() -> void:
	while alpha < 1.0:
		alpha = move_toward(alpha, 1.0, fade_speed * get_process_delta_time())
		aplicar_alpha()
		await get_tree().process_frame

func fade_to(target: float, delta: float) -> void:
	alpha = move_toward(alpha, target, fade_speed * delta)
	aplicar_alpha()

func aplicar_alpha() -> void:
	if mesh_root == null:
		return
	var meshes = mesh_root.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if m is MeshInstance3D and m.material_override is BaseMaterial3D:
			var mat: BaseMaterial3D = m.material_override
			mat.albedo_color.a = alpha
