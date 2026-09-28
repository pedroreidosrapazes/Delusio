extends Node3D

@export var camera: Camera3D
@export var fade_speed := 8.0
@export var look_threshold := 0.92

# Distância mínima e máxima para o novo local
@export var distancia_minima := 15.0
@export var distancia_maxima := 30.0

# Tempo que ela fica desaparecida antes de reaparecer
@export var tempo_desaparecida := 0.8

# Quantas vezes tenta encontrar um local válido
@export var tentativas_posicao := 10

@onready var mesh = $mesh
@onready var notifier = $VisibleOnScreenNotifier3D

var alpha := 1.0
var mudando_posicao := false


func _ready():
	var meshes = mesh.find_children("*", "MeshInstance3D", true, false)

	for m in meshes:
		var material = m.get_active_material(0)

		if material:
			var material_copy = material.duplicate()
			m.material_override = material_copy
			material_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _process(delta):
	if camera == null:
		return

	# Se estiver mudando de posição, não faz nada
	if mudando_posicao:
		return

	# Se saiu da tela
	if not notifier.is_on_screen():
		fade_to(0.0, delta)
		return

	# Direção da câmera até a silhueta
	var direction = (
		global_position - camera.global_position
	).normalized()

	# Direção para frente da câmera
	var camera_forward = -camera.global_transform.basis.z.normalized()

	# Verifica se o jogador está olhando para ela
	var dot = camera_forward.dot(direction)

	if dot >= look_threshold:
		# Jogador olhou para ela
		mudando_posicao = true
		await criatura_foi_vista()
	else:
		# Continua aparecendo
		fade_to(1.0, delta)


func criatura_foi_vista():
	# Desaparece
	await fade_out()

	# Espera um pouco
	await get_tree().create_timer(tempo_desaparecida).timeout

	# Teleporta para outro lugar
	mover_para_novo_local()

	# Volta a aparecer
	await fade_in()

	mudando_posicao = false


func mover_para_novo_local():
	if camera == null:
		return

	var jogador_pos = camera.global_position

	for i in range(tentativas_posicao):

		# Ângulo aleatório ao redor do jogador
		var angulo = randf_range(0.0, TAU)

		# Distância aleatória
		var distancia = randf_range(
			distancia_minima,
			distancia_maxima
		)

		var nova_posicao = jogador_pos + Vector3(
			cos(angulo) * distancia,
			0.0,
			sin(angulo) * distancia
		)

		# Coloca a silhueta na nova posição
		global_position = nova_posicao

		# Encontrou uma posição
		return


func fade_out():
	while alpha > 0.0:
		alpha = move_toward(alpha, 0.0, fade_speed * get_process_delta_time())
		aplicar_alpha()
		await get_tree().process_frame


func fade_in():
	while alpha < 1.0:
		alpha = move_toward(alpha, 1.0, fade_speed * get_process_delta_time())
		aplicar_alpha()
		await get_tree().process_frame


func fade_to(target: float, delta: float):
	alpha = move_toward(alpha, target, fade_speed * delta)
	aplicar_alpha()


func aplicar_alpha():
	var meshes = mesh.find_children("*", "MeshInstance3D", true, false)

	for m in meshes:
		var material = m.material_override

		if material:
			var color = material.albedo_color
			color.a = alpha
			material.albedo_color = color
