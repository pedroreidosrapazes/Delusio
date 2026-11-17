class_name Silhueta
extends MonstroNoturnoBase

## Criatura psicológica que observa à distância e reage à atenção e à luz da lanterna.
## Possui 4 anéis de espreita, introdução progressiva em 3 etapas, oclusão 3D e investida agressiva.

enum Estado {
	INATIVO = 0,
	INTRODUCAO_ESPREITA = 1,
	OBSERVANDO = 2,
	AMEACA_LANTERNA = 3,
	RECUANDO = 4,
	INVESTIDA = 5,
	CAPTURA = 6
}

enum EstagioIntroducao {
	NAO_INICIADA = 0,
	ETAPA_A_APARICAO_PASSIVA = 1,
	ETAPA_B_TESTE_LANTERNA = 2,
	ETAPA_C_CICLO_NORMAL = 3
}

signal captura_realizada(player: Player)
signal investida_evitada_esconderijo(player: Player)
signal estado_alterado(novo_estado: int, estado_anterior: int)
signal introducao_etapa_concluida(etapa: int)

@export_category("Detecção e Visão")
@export var camera: Camera3D
@export var fade_speed: float = 8.0
@export var look_threshold: float = 0.92
@export var usar_raycast_oclusao: bool = true

@export_category("Teleporte e Anéis")
@export var distancia_minima: float = 15.0
@export var distancia_maxima: float = 30.0
@export var tempo_desaparecida: float = 0.8
@export var tentativas_posicao: int = 12
@export var ponto_introducao: Node3D

@export_category("Reatividade à Lanterna e Captura")
@export var limiar_ameaca_lanterna: float = 0.8
@export var tempo_limite_lanterna: float = 2.0
@export var tempo_ameaca_intro: float = 2.5
@export var tempo_pausa_entre_etapas_intro: float = 4.0
@export var tempo_recuperacao_apos_captura: float = 3.0

const DISTANCIAS_ANEIS: Array[float] = [4.5, 10.0, 18.0, 28.0]

var estado_atual: Estado = Estado.INATIVO
var estagio_introducao: EstagioIntroducao = EstagioIntroducao.NAO_INICIADA

var anel_atual: int = 4 # 1 = 4.5m, 2 = 10.0m, 3 = 18.0m, 4 = 28.0m
var tempo_olhando_lanterna: float = 0.0
var _em_investida: bool = false
var em_investida: bool:
	get:
		return _em_investida
	set(valor):
		_em_investida = valor
		if valor:
			_mudar_estado(Estado.INVESTIDA)
		elif estado_atual == Estado.INVESTIDA:
			_mudar_estado(Estado.OBSERVANDO if ativa else Estado.INATIVO)

var fator_atracao_lanterna: float = 1.0
var tempo_sem_olhar: float = 0.0
var intervalo_avanco_anel: float = 8.0
var velocidade_investida: float = 8.0

@onready var mesh_root: Node3D = get_node_or_null("mesh") as Node3D
@onready var notifier: VisibleOnScreenNotifier3D = get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D

var alpha: float = 1.0
var mudando_posicao: bool = false
var altura_padrao: float = 0.0
var tempo_pausa_intro_restante: float = 0.0
var tempo_recuperacao_captura: float = 0.0
var _aguardando_etapa_b: bool = false
var _mesh_origem_local: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	if config == null:
		config = CriaturaConfig.criar_padrao_silhueta()
	else:
		velocidade_investida = config.velocidade_perseguicao
		intervalo_avanco_anel = maxf(1.0, config.intervalo_min_evento)
	altura_padrao = global_position.y
	if mesh_root != null:
		_mesh_origem_local = mesh_root.position
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


func _mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return
	var anterior := estado_atual
	estado_atual = novo_estado
	if novo_estado != Estado.AMEACA_LANTERNA and mesh_root != null:
		mesh_root.position = _mesh_origem_local
	estado_alterado.emit(int(novo_estado), int(anterior))


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
	_em_investida = false
	tempo_olhando_lanterna = 0.0
	if estado_atual == Estado.INVESTIDA or estado_atual == Estado.AMEACA_LANTERNA:
		_mudar_estado(Estado.OBSERVANDO if ativa else Estado.INATIVO)


func _atualizar_limites_distancia() -> void:
	var dist := obter_distancia_anel()
	distancia_minima = maxf(3.0, dist * 0.8)
	distancia_maxima = dist * 1.2


func ativar() -> void:
	super.ativar()
	alpha = 1.0
	anel_atual = 4
	tempo_olhando_lanterna = 0.0
	tempo_sem_olhar = 0.0
	_em_investida = false
	mudando_posicao = false
	_aguardando_etapa_b = false
	tempo_pausa_intro_restante = 0.0
	tempo_recuperacao_captura = 0.0
	if estagio_introducao == EstagioIntroducao.NAO_INICIADA:
		estagio_introducao = EstagioIntroducao.ETAPA_C_CICLO_NORMAL
	_atualizar_limites_distancia()
	aplicar_alpha()
	_mudar_estado(Estado.OBSERVANDO)


func iniciar_etapa_introducao(etapa: EstagioIntroducao, ponto_alvo: Node3D = null) -> void:
	if ponto_alvo != null:
		ponto_introducao = ponto_alvo
	super.ativar()
	estagio_introducao = etapa
	_em_investida = false
	tempo_olhando_lanterna = 0.0
	tempo_sem_olhar = 0.0
	mudando_posicao = false
	_aguardando_etapa_b = false
	tempo_pausa_intro_restante = 0.0
	tempo_recuperacao_captura = 0.0
	alpha = 1.0
	aplicar_alpha()

	match etapa:
		EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA:
			anel_atual = 4
			_atualizar_limites_distancia()
			_posicionar_ponto_introducao()
			_mudar_estado(Estado.INTRODUCAO_ESPREITA)
		EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			anel_atual = 4
			_atualizar_limites_distancia()
			mover_para_novo_local()
			_mudar_estado(Estado.OBSERVANDO)
		_:
			anel_atual = 4
			_atualizar_limites_distancia()
			_mudar_estado(Estado.OBSERVANDO)


func _posicionar_ponto_introducao() -> void:
	var marcador := ponto_introducao
	if marcador == null and get_tree() != null:
		marcador = get_tree().get_first_node_in_group("ponto_intro_silhueta") as Node3D
	if marcador != null and is_instance_valid(marcador):
		global_position = marcador.global_position
		altura_padrao = global_position.y
	elif camera != null:
		var frente := -camera.global_transform.basis.z
		var frente_xz := Vector3(frente.x, 0.0, frente.z)
		if frente_xz.length_squared() < 0.001:
			frente_xz = Vector3(0.0, 0.0, -1.0)
		else:
			frente_xz = frente_xz.normalized()
		global_position = camera.global_position + frente_xz * 20.0
		global_position.y = altura_padrao


func desativar() -> void:
	super.desativar()
	_em_investida = false
	tempo_olhando_lanterna = 0.0
	tempo_sem_olhar = 0.0
	mudando_posicao = false
	_aguardando_etapa_b = false
	tempo_pausa_intro_restante = 0.0
	tempo_recuperacao_captura = 0.0
	_mudar_estado(Estado.INATIVO)


func _obter_player() -> Player:
	if camera != null and camera.get_parent() is Player:
		return camera.get_parent() as Player
	return super._obter_player()


func _obter_mult_agressividade() -> float:
	var mult_agressividade: float = 1.0
	var gerente := GameManager.instance
	if gerente != null and ("gerenciador_medicamentos" in gerente) and gerente.gerenciador_medicamentos != null:
		mult_agressividade += float(gerente.gerenciador_medicamentos.obter_modificador("agressividade_silhueta", 0.0))
	return maxf(0.25, mult_agressividade)


func _obter_mult_atracao_lanterna() -> float:
	var mult := 1.0
	var gerente := GameManager.instance
	if gerente != null and ("gerenciador_medicamentos" in gerente) and gerente.gerenciador_medicamentos != null:
		mult += float(gerente.gerenciador_medicamentos.obter_modificador("mult_atracao_lanterna", 0.0))
	return maxf(0.25, mult)


func receber_estimulo_sonoro(pos: Vector3, raio: float) -> void:
	super.receber_estimulo_sonoro(pos, raio)


func receber_foco_lanterna(delta: float) -> void:
	if not ativa:
		return
	if config != null and not config.sensivel_a_luz:
		return
	if estado_atual == Estado.INTRODUCAO_ESPREITA or estado_atual == Estado.CAPTURA:
		return

	var fator := _obter_mult_agressividade() * _obter_mult_atracao_lanterna()
	tempo_olhando_lanterna += delta * fator

	var limite_ataque := tempo_ameaca_intro if estagio_introducao == EstagioIntroducao.ETAPA_B_TESTE_LANTERNA else tempo_limite_lanterna
	if tempo_olhando_lanterna > limite_ataque:
		if estagio_introducao == EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			estagio_introducao = EstagioIntroducao.ETAPA_C_CICLO_NORMAL
			introducao_etapa_concluida.emit(int(EstagioIntroducao.ETAPA_B_TESTE_LANTERNA))
		_em_investida = true
		_mudar_estado(Estado.INVESTIDA)
	elif tempo_olhando_lanterna >= limiar_ameaca_lanterna and estado_atual == Estado.OBSERVANDO:
		_mudar_estado(Estado.AMEACA_LANTERNA)

	super.receber_foco_lanterna(delta)


func reagir_esconderijo_no_escuro(player: Player) -> bool:
	if player != null and player.esta_escondido() and not player.esta_com_lanterna_acesa():
		parar_investida()
		recuar_anel()
		mover_para_novo_local()
		if estagio_introducao == EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			estagio_introducao = EstagioIntroducao.ETAPA_C_CICLO_NORMAL
			introducao_etapa_concluida.emit(int(EstagioIntroducao.ETAPA_B_TESTE_LANTERNA))
		investida_evitada_esconderijo.emit(player)
		return true
	return false


func realizar_captura(player: Player) -> void:
	_mudar_estado(Estado.CAPTURA)
	_em_investida = false
	tempo_olhando_lanterna = 0.0
	tempo_sem_olhar = 0.0
	anel_atual = 4
	tempo_recuperacao_captura = tempo_recuperacao_apos_captura
	_atualizar_limites_distancia()
	captura_realizada.emit(player)
	jogador_capturado.emit(self, player)
	if GameManager.instance != null and GameManager.instance.has_method("registrar_captura_monstro"):
		GameManager.instance.registrar_captura_monstro(self, player)
	mover_para_novo_local()
	_mudar_estado(Estado.OBSERVANDO if ativa else Estado.INATIVO)


func _esta_no_alcance_captura(player: Player) -> bool:
	if player == null:
		return false
	var diff := player.global_position - global_position
	var dist_3d := diff.length()
	var dist_xz := Vector2(diff.x, diff.z).length()
	return dist_3d <= distancia_captura or (dist_xz <= distancia_captura and absf(diff.y) <= 12.0)


func _obter_espaco_3d() -> PhysicsDirectSpaceState3D:
	if not is_inside_tree() or get_world_3d() == null:
		return null
	return get_world_3d().direct_space_state


func _obter_excecoes_raycast(player: Player = null) -> Array[RID]:
	var excl: Array[RID] = []
	if player != null and player is CollisionObject3D:
		excl.append((player as CollisionObject3D).get_rid())
	for c in find_children("*", "CollisionObject3D", true, false):
		if c is CollisionObject3D:
			excl.append((c as CollisionObject3D).get_rid())
	return excl


func tem_linha_de_visao(alvo_player: Player = null) -> bool:
	if not usar_raycast_oclusao or camera == null:
		return true
	var space := _obter_espaco_3d()
	if space == null:
		return true

	var origem := camera.global_position
	var destino := global_position + Vector3(0.0, 1.4, 0.0)
	if origem.distance_squared_to(destino) < 0.04:
		return true

	var query := PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = _obter_excecoes_raycast(alvo_player)
	query.hit_from_inside = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true

	var pos_hit: Vector3 = hit.get("position", origem)
	return pos_hit.distance_to(destino) <= 0.75


func esta_no_feixe_lanterna(player: Player) -> bool:
	if player == null or not player.esta_com_lanterna_acesa() or camera == null:
		return false
	if not tem_linha_de_visao(player):
		return false

	var alcance := 32.0
	var meio_angulo := 26.0
	if player.luz_lanterna != null:
		alcance = maxf(8.0, player.luz_lanterna.spot_range)
		meio_angulo = clampf(player.luz_lanterna.spot_angle * 0.5, 5.0, 85.0)

	var cam_pos := camera.global_position
	var cam_forward := -camera.global_transform.basis.z.normalized()
	var alvo_centro := global_position
	var alvo_peito := global_position + Vector3(0.0, 1.3, 0.0)
	var dist := minf(cam_pos.distance_to(alvo_centro), cam_pos.distance_to(alvo_peito))
	if dist > alcance:
		return false

	var dot_centro := cam_forward.dot((alvo_centro - cam_pos).normalized()) if cam_pos.distance_squared_to(alvo_centro) > 0.001 else 1.0
	var dot_peito := cam_forward.dot((alvo_peito - cam_pos).normalized()) if cam_pos.distance_squared_to(alvo_peito) > 0.001 else 1.0
	var melhor_dot := clampf(maxf(dot_centro, dot_peito), -1.0, 1.0)
	var angulo_graus := rad_to_deg(acos(melhor_dot))
	return angulo_graus <= meio_angulo


func _process(delta: float) -> void:
	if not ativa or camera == null:
		return

	if _aguardando_etapa_b:
		tempo_pausa_intro_restante -= delta
		if tempo_pausa_intro_restante <= 0.0:
			_aguardando_etapa_b = false
			iniciar_etapa_introducao(EstagioIntroducao.ETAPA_B_TESTE_LANTERNA)
		return

	if tempo_recuperacao_captura > 0.0:
		tempo_recuperacao_captura = maxf(0.0, tempo_recuperacao_captura - delta)

	var player: Player = _obter_player()
	var lanterna_acesa: bool = (player != null and player.esta_com_lanterna_acesa())
	fator_atracao_lanterna = 2.0 if lanterna_acesa else 1.0

	var mult_agressividade: float = _obter_mult_agressividade()
	var mult_atracao: float = _obter_mult_atracao_lanterna()

	if em_investida or estado_atual == Estado.INVESTIDA:
		if player != null:
			if reagir_esconderijo_no_escuro(player):
				return
			if _esta_no_alcance_captura(player):
				realizar_captura(player)
				return
			var delta_pos := player.global_position - global_position
			var dir_xz := Vector3(delta_pos.x, 0.0, delta_pos.z)
			if dir_xz.length_squared() > 0.0001:
				var dir_p: Vector3 = dir_xz.normalized()
				global_position += dir_p * (velocidade_investida * mult_agressividade) * delta
				global_position.y = altura_padrao
			if _esta_no_alcance_captura(player):
				realizar_captura(player)
		return

	if mudando_posicao or estado_atual == Estado.RECUANDO or estado_atual == Estado.CAPTURA:
		return

	if DisplayServer.get_name() != "headless" and notifier and not notifier.is_on_screen():
		if estado_atual == Estado.AMEACA_LANTERNA:
			_mudar_estado(Estado.OBSERVANDO)
		fade_to(0.0, delta)
		return

	var direcao: Vector3 = (global_position - camera.global_position).normalized()
	var camera_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var dot: float = camera_forward.dot(direcao)
	var visivel_sem_parede := tem_linha_de_visao(player)

	if estado_atual == Estado.INTRODUCAO_ESPREITA:
		fade_to(1.0, delta)
		if dot >= look_threshold and visivel_sem_parede:
			_concluir_etapa_a_introducao()
		return

	if estado_atual == Estado.AMEACA_LANTERNA:
		fade_to(1.0, delta)
		if mesh_root != null:
			var t := Time.get_ticks_msec() * 0.04
			mesh_root.position = _mesh_origem_local + Vector3(sin(t) * 0.05, cos(t * 1.3) * 0.03, 0.0)
		if reagir_esconderijo_no_escuro(player):
			return

		if dot >= look_threshold and esta_no_feixe_lanterna(player):
			receber_foco_lanterna(delta)
			return

		if estagio_introducao == EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			estagio_introducao = EstagioIntroducao.ETAPA_C_CICLO_NORMAL
			introducao_etapa_concluida.emit(int(EstagioIntroducao.ETAPA_B_TESTE_LANTERNA))

		tempo_olhando_lanterna = maxf(0.0, tempo_olhando_lanterna - delta * 2.0)
		if dot >= look_threshold and visivel_sem_parede and not lanterna_acesa:
			_iniciar_recuo()
		elif tempo_olhando_lanterna <= 0.0:
			_mudar_estado(Estado.OBSERVANDO)
		return

	# Estado.OBSERVANDO
	if dot >= look_threshold and visivel_sem_parede:
		tempo_sem_olhar = 0.0
		if tempo_recuperacao_captura <= 0.0 and esta_no_feixe_lanterna(player):
			receber_foco_lanterna(delta)
			return

		if estagio_introducao == EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			estagio_introducao = EstagioIntroducao.ETAPA_C_CICLO_NORMAL
			introducao_etapa_concluida.emit(int(EstagioIntroducao.ETAPA_B_TESTE_LANTERNA))

		_iniciar_recuo()
	else:
		tempo_olhando_lanterna = maxf(0.0, tempo_olhando_lanterna - delta)
		fade_to(1.0, delta)

		if tempo_recuperacao_captura > 0.0:
			return
		if player != null and player.esta_escondido() and not lanterna_acesa:
			return

		tempo_sem_olhar += delta * fator_atracao_lanterna * mult_atracao * mult_agressividade
		if tempo_sem_olhar >= intervalo_avanco_anel:
			tempo_sem_olhar = 0.0
			avancar_anel()


func _concluir_etapa_a_introducao() -> void:
	mudando_posicao = true
	_mudar_estado(Estado.RECUANDO)
	estagio_introducao = EstagioIntroducao.ETAPA_B_TESTE_LANTERNA
	introducao_etapa_concluida.emit(int(EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA))
	if is_inside_tree():
		await fade_out()
	else:
		alpha = 0.0
		aplicar_alpha()
	visible = false
	mudando_posicao = false
	_aguardando_etapa_b = true
	tempo_pausa_intro_restante = tempo_pausa_entre_etapas_intro
	_mudar_estado(Estado.INATIVO)


func _iniciar_recuo() -> void:
	mudando_posicao = true
	_mudar_estado(Estado.RECUANDO)
	criatura_foi_vista()


func criatura_foi_vista() -> void:
	recuar_anel()
	if is_inside_tree():
		await fade_out()
		if get_tree() != null:
			await get_tree().create_timer(tempo_desaparecida).timeout
		mover_para_novo_local()
		await fade_in()
	else:
		mover_para_novo_local()
		alpha = 1.0
		aplicar_alpha()
	mudando_posicao = false
	if ativa and not em_investida:
		_mudar_estado(Estado.OBSERVANDO)


func _tem_teto_acima(pos: Vector3) -> bool:
	var space := _obter_espaco_3d()
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, 4.5, 0.0))
	query.exclude = _obter_excecoes_raycast(_obter_player())
	return not space.intersect_ray(query).is_empty()


func _posicao_livre_de_parede(pos: Vector3) -> bool:
	var space := _obter_espaco_3d()
	if space == null:
		return true
	var excl := _obter_excecoes_raycast(_obter_player())
	var centro := pos + Vector3(0.0, 1.2, 0.0)
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(centro, centro + dir * 0.85)
		query.exclude = excl
		if not space.intersect_ray(query).is_empty():
			return false
	return true


func mover_para_novo_local() -> void:
	if camera == null:
		return

	var jogador_pos := camera.global_position
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var melhor_posicao := global_position
	var achou_ideal := false
	var space := _obter_espaco_3d()
	var excl := _obter_excecoes_raycast(_obter_player())
	var jogador_coberto := _tem_teto_acima(jogador_pos)

	_atualizar_limites_distancia()

	for i in range(tentativas_posicao):
		var angulo := randf_range(0.0, TAU)
		var distancia := randf_range(distancia_minima, distancia_maxima)
		var candidata := jogador_pos + Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		candidata.y = altura_padrao

		if space != null:
			var ray_chao := PhysicsRayQueryParameters3D.create(
				Vector3(candidata.x, jogador_pos.y + 8.0, candidata.z),
				Vector3(candidata.x, jogador_pos.y - 16.0, candidata.z)
			)
			ray_chao.exclude = excl
			var hit_chao := space.intersect_ray(ray_chao)
			if not hit_chao.is_empty():
				candidata.y = (hit_chao["position"] as Vector3).y

		var dir_para_candidata: Vector3 = (candidata - jogador_pos).normalized()
		var dot: float = camera_forward.dot(dir_para_candidata)
		var fora_olhar := dot < 0.35
		var sem_parede := _posicao_livre_de_parede(candidata)
		var teto_compativel := jogador_coberto or not _tem_teto_acima(candidata)

		if fora_olhar and sem_parede and teto_compativel:
			melhor_posicao = candidata
			achou_ideal = true
			break
		if not achou_ideal and sem_parede and teto_compativel:
			melhor_posicao = candidata

	global_position = melhor_posicao
	altura_padrao = global_position.y


func fade_out() -> void:
	while alpha > 0.0 and is_inside_tree():
		alpha = move_toward(alpha, 0.0, fade_speed * get_process_delta_time())
		aplicar_alpha()
		await get_tree().process_frame


func fade_in() -> void:
	while alpha < 1.0 and is_inside_tree():
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
