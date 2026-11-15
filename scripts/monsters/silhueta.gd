class_name Silhueta
extends Node3D

## Criatura misteriosa que observa e se teleporta quando o jogador a encara.
## Possui 4 anéis de espreita, reatividade à lanterna e investida agressiva.

@export_category("Detecção e Visão")
@export var camera: Camera3D
@export var fade_speed: float = 8.0
@export var look_threshold: float = 0.92

@export_category("Teleporte e Anéis")
@export var distancia_minima: float = 15.0
@export var distancia_maxima: float = 30.0
@export var tempo_desaparecida: float = 0.8
@export var tentativas_posicao: int = 10

const DISTANCIAS_ANEIS: Array[float] = [4.5, 10.0, 18.0, 28.0]
var anel_atual: int = 4 # 1 = 4.5m, 2 = 10.0m, 3 = 18.0m, 4 = 28.0m
var tempo_olhando_lanterna: float = 0.0
var em_investida: bool = false
var fator_atracao_lanterna: float = 1.0
var tempo_sem_olhar: float = 0.0
var intervalo_avanco_anel: float = 8.0
var velocidade_investida: float = 8.0

@onready var mesh_root: Node3D = $mesh
@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

var alpha: float = 1.0
var mudando_posicao: bool = false
var ativa: bool = false
var altura_padrao: float = 0.0


func _ready() -> void:
	altura_padrao = global_position.y
	_preparar_materiais()
	_atualizar_limites_distancia()
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


func obter_distancia_anel(anel: int = -1) -> float:
	var a := anel if anel != -1 else anel_atual
	var idx: int = clampi(a - 1, 0, DISTANCIAS_ANEIS.size() - 1)
	return DISTANCIAS_ANEIS[idx]


func avancar_anel() -> void:
	anel_atual = maxi(1, anel_atual - 1)
	_atualizar_limites_distancia()


func recuar_anel() -> void:
	anel_atual = mini(4, anel_atual + 1)
	_atualizar_limites_distancia()


func parar_investida() -> void:
	em_investida = false
	tempo_olhando_lanterna = 0.0


func _atualizar_limites_distancia() -> void:
	var dist := obter_distancia_anel()
	distancia_minima = maxf(3.0, dist * 0.8)
	distancia_maxima = dist * 1.2


func ativar() -> void:
	ativa = true
	visible = true
	alpha = 1.0
	anel_atual = 4
	tempo_olhando_lanterna = 0.0
	em_investida = false
	_atualizar_limites_distancia()
	aplicar_alpha()
	mudando_posicao = false
	set_process(true)


func desativar() -> void:
	ativa = false
	visible = false
	em_investida = false
	tempo_olhando_lanterna = 0.0
	set_process(false)


func _obter_player() -> Player:
	if camera != null and camera.get_parent() is Player:
		return camera.get_parent() as Player
	if get_tree() != null:
		return get_tree().get_first_node_in_group("player") as Player
	return null


func _process(delta: float) -> void:
	if not ativa or camera == null:
		return

	var player: Player = _obter_player()
	var lanterna_acesa: bool = (player != null and player.esta_com_lanterna_acesa())
	fator_atracao_lanterna = 2.0 if lanterna_acesa else 1.0

	var mult_agressividade: float = 1.0
	var gerente := GameManager.instance
	if gerente != null and ("gerenciador_medicamentos" in gerente) and gerente.gerenciador_medicamentos != null:
		mult_agressividade += float(gerente.gerenciador_medicamentos.obter_modificador("agressividade_silhueta", 0.0))

	if em_investida:
		if player != null:
			if not lanterna_acesa and player.esta_escondido():
				parar_investida()
				recuar_anel()
				mover_para_novo_local()
			else:
				var dir_p: Vector3 = (player.global_position - global_position).normalized()
				global_position += dir_p * (velocidade_investida * mult_agressividade) * delta
				global_position.y = altura_padrao
		return

	if mudando_posicao:
		return

	# Se saiu da tela
	if notifier and not notifier.is_on_screen():
		fade_to(0.0, delta)
		return

	# Direção da câmera até a silhueta
	var direcao: Vector3 = (global_position - camera.global_position).normalized()
	# Direção para frente da câmera (-Z no padrão Godot)
	var camera_forward: Vector3 = -camera.global_transform.basis.z.normalized()

	# Produto escalar: 1.0 = olhando diretamente, 0.0 = perpendicular
	var dot: float = camera_forward.dot(direcao)

	if dot >= look_threshold:
		tempo_sem_olhar = 0.0
		if lanterna_acesa:
			tempo_olhando_lanterna += delta * mult_agressividade
			if tempo_olhando_lanterna > 2.0:
				em_investida = true
				return

		mudando_posicao = true
		criatura_foi_vista()
	else:
		tempo_olhando_lanterna = maxf(0.0, tempo_olhando_lanterna - delta)
		fade_to(1.0, delta)

		# Avanço gradativo de anel se o jogador não olhar para trás
		tempo_sem_olhar += delta * fator_atracao_lanterna * mult_agressividade
		if tempo_sem_olhar >= intervalo_avanco_anel:
			tempo_sem_olhar = 0.0
			avancar_anel()


func criatura_foi_vista() -> void:
	recuar_anel()
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

	_atualizar_limites_distancia()

	for i in range(tentativas_posicao):
		var angulo = randf_range(0.0, TAU)
		var distancia = randf_range(distancia_minima, distancia_maxima)
		var candidata = jogador_pos + Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		candidata.y = altura_padrao

		var dir_para_candidata: Vector3 = (candidata - jogador_pos).normalized()
		var dot: float = camera_forward.dot(dir_para_candidata)

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
