class_name RondanteFazenda
extends MonstroNoturnoBase

## 2º Monstro Noturno — O Rondante da Fazenda.
## Arquitetura agnóstica ao mapa com NavigationAgent3D + fallback RayCast3D,
## presença flexível (Contínua ou Pressão Dinâmica), oclusão visual 3D,
## animações reais unificadas e dilema tático com a Silhueta.

enum Estado {
	INATIVO = 0,
	PATRULHA = 1,
	INVESTIGANDO = 2,
	CACADA = 3,
	ATORDOADO_LUZ = 4,
	ESPREITA_QUINA = 5,
	BUSCA_FRUSTRADA = 6,
	ATAQUE_GARRAS = 7,
	EM_ESPERA = 8,
	RETIRANDO = 9
}

signal estado_alterado(novo_estado: int, estado_anterior: int)
signal som_investigado(posicao: Vector3)
signal atordoado_por_luz(duracao: float)
signal ronda_iniciada_por_pressao(posicao_spawn: Vector3)
signal ronda_encerrada_retirada()
signal ataque_garras_iniciado(alvo: Player)

@export_category("Patrulha e Navegação Agnóstica")
@export var pontos_patrulha: Array[Node3D] = []
@export var posicoes_patrulha_fallback: Array[Vector3] = [
	Vector3(-12.0, 0.5, 22.0),
	Vector3(0.0, 0.5, 26.0),
	Vector3(8.0, 0.5, 28.0),
	Vector3(-6.0, 0.5, 34.0),
	Vector3(-18.0, 0.5, 40.0)
]
@export var usar_raycast_oclusao: bool = true
@export var usar_desvio_obstaculo_raycast: bool = true
@export var usar_colisao_paredes: bool = true
@export_flags_3d_physics var mascara_colisao_ambiente: int = 1
@export var raio_colisao_corpo: float = 0.38
@export var altura_colisao_corpo: float = 1.40
@export var offset_y_colisao_corpo: float = 1.08
@export var altura_max_degrau: float = 0.45

@export_category("Visual 3D e Áudio")
@export var usar_modelo_3d_real: bool = true
@export var escala_modelo_3d: float = 0.28
@export var offset_rotacao_y_modelo_graus: float = 180.0
@export var velocidade_giro_patrulha: float = 4.2
@export var velocidade_giro_cacada: float = 6.5
@export var cadencia_passos_patrulha: float = 0.72
@export var cadencia_passos_cacada: float = 0.40

@export_category("Temporizadores da IA")
@export var duracao_investigacao: float = 4.0
@export var tempo_foco_para_atordoar: float = 0.4
@export var duracao_atordoamento_luz: float = 2.5
@export var cooldown_atordoamento_max: float = 5.0
@export var duracao_ataque_garras: float = 0.65
@export var alcance_ataque_garras: float = 2.4

var estado_atual: Estado = Estado.INATIVO
var indice_patrulha_atual: int = 0
var ultima_posicao_som: Vector3 = Vector3.ZERO
var ultima_posicao_vista_jogador: Vector3 = Vector3.ZERO
var tempo_investigacao_restante: float = 0.0
var tempo_tolerancia_esconderijo_restante: float = 0.0
var tempo_foco_lanterna_acumulado: float = 0.0
var tempo_atordoado_restante: float = 0.0
var cooldown_atordoamento_restante: float = 0.0
var viu_jogador_entrar_esconderijo: bool = false

var pressao_ruido_atual: float = 0.0
var tempo_ronda_restante: float = 0.0
var tempo_espreita_quina_restante: float = 0.0
var tempo_ataque_restante: float = 0.0

var visual_placeholder: MeshInstance3D = null
var nav_agent: NavigationAgent3D = null
var modelo_pivot: Node3D = null
var anim_player: AnimationPlayer = null
var audio_passos: AudioStreamPlayer3D = null
var audio_vocalizacao: AudioStreamPlayer3D = null

var pontos_wall_peek: Array[Node3D] = []
var pontos_entrada_saida: Array[Node3D] = []
var _waypoints_path3d: Array[Vector3] = []
var _waypoints_procedurais: Array[Vector3] = []
var _rotas_manuais: bool = false
var _prioridade_som_atual: float = 0.0
var _timer_passos: float = 0.0
var _destino_retirada: Vector3 = Vector3.ZERO
var _direcao_espreita_atual: Vector3 = Vector3.FORWARD
var _pontos_espreita_visitados: Dictionary = {}
var _forma_colisao_corpo: CapsuleShape3D = null
var _sentido_desvio_preferido: float = 1.0
var _timer_memoria_desvio: float = 0.0
var _tempo_bloqueado_movimento: float = 0.0
var _tempo_sem_progresso_alvo: float = 0.0
var _menor_dist_alvo_mov: float = INF


func _ready() -> void:
	super._ready()
	if config == null:
		config = CriaturaConfig.criar_padrao_rondante()
	_rotas_manuais = not pontos_patrulha.is_empty()
	_garantir_estrutura_nos()
	atualizar_rotas_do_mapa()
	desativar()


func _garantir_estrutura_nos() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		nav_agent.path_desired_distance = 0.8
		nav_agent.target_desired_distance = 1.0
		add_child(nav_agent)

	audio_passos = get_node_or_null("AudioPassos3D") as AudioStreamPlayer3D
	if audio_passos == null:
		audio_passos = AudioStreamPlayer3D.new()
		audio_passos.name = "AudioPassos3D"
		audio_passos.max_distance = 26.0
		add_child(audio_passos)
	audio_passos.bus = BancoAudioDelusio.resolver_bus(&"SFX")
	audio_passos.stream = BancoAudioDelusio.obter_sfx(&"rondante_passo")

	audio_vocalizacao = get_node_or_null("AudioVocalizacao3D") as AudioStreamPlayer3D
	if audio_vocalizacao == null:
		audio_vocalizacao = AudioStreamPlayer3D.new()
		audio_vocalizacao.name = "AudioVocalizacao3D"
		audio_vocalizacao.max_distance = 32.0
		add_child(audio_vocalizacao)
	audio_vocalizacao.bus = BancoAudioDelusio.resolver_bus(&"SFX")
	audio_vocalizacao.stream = BancoAudioDelusio.obter_sfx(&"rondante_vocalizacao")

	visual_placeholder = get_node_or_null("VisualPlaceholder") as MeshInstance3D
	if visual_placeholder == null:
		visual_placeholder = _criar_visual_placeholder()
		add_child(visual_placeholder)

	modelo_pivot = get_node_or_null("ModeloPivot") as Node3D
	if modelo_pivot == null and usar_modelo_3d_real:
		modelo_pivot = Node3D.new()
		modelo_pivot.name = "ModeloPivot"
		add_child(modelo_pivot)
	if modelo_pivot != null:
		modelo_pivot.scale = Vector3.ONE * escala_modelo_3d
		modelo_pivot.rotation = Vector3(0.0, deg_to_rad(offset_rotacao_y_modelo_graus), 0.0)

	if modelo_pivot != null and usar_modelo_3d_real:
		anim_player = RondanteAnimador.montar_no_pivo(modelo_pivot)
		if anim_player != null and modelo_pivot.get_node_or_null("RIG-Monstro") != null:
			visual_placeholder.visible = false
		else:
			visual_placeholder.visible = true
	else:
		visual_placeholder.visible = true


func _criar_visual_placeholder() -> MeshInstance3D:
	var corpo := MeshInstance3D.new()
	corpo.name = "VisualPlaceholder"
	var cap := CapsuleMesh.new()
	cap.radius = 0.45
	cap.height = 2.2
	corpo.mesh = cap
	corpo.position = Vector3(0.0, 1.1, 0.0)

	var mat_corpo := StandardMaterial3D.new()
	mat_corpo.albedo_color = Color(0.04, 0.04, 0.05, 1.0)
	mat_corpo.roughness = 0.92
	corpo.material_override = mat_corpo

	var mat_olho := StandardMaterial3D.new()
	mat_olho.albedo_color = Color(0.95, 0.45, 0.15, 1.0)
	mat_olho.emission_enabled = true
	mat_olho.emission = Color(1.0, 0.45, 0.15, 1.0)
	mat_olho.emission_energy_multiplier = 2.2

	var olho_esq := MeshInstance3D.new()
	olho_esq.name = "OlhoEsquerdo"
	var esfera_esq := SphereMesh.new()
	esfera_esq.radius = 0.055
	esfera_esq.height = 0.11
	olho_esq.mesh = esfera_esq
	olho_esq.material_override = mat_olho
	olho_esq.position = Vector3(-0.14, 0.65, -0.38)
	corpo.add_child(olho_esq)

	var olho_dir := MeshInstance3D.new()
	olho_dir.name = "OlhoDireito"
	var esfera_dir := SphereMesh.new()
	esfera_dir.radius = 0.055
	esfera_dir.height = 0.11
	olho_dir.mesh = esfera_dir
	olho_dir.material_override = mat_olho
	olho_dir.position = Vector3(0.14, 0.65, -0.38)
	corpo.add_child(olho_dir)

	return corpo


func atualizar_rotas_do_mapa(forcar_reconstrucao: bool = false) -> void:
	if get_tree() == null:
		return

	if forcar_reconstrucao or not _rotas_manuais:
		pontos_patrulha.clear()
		for node in get_tree().get_nodes_in_group("pontos_patrulha"):
			if node is Node3D:
				if node is PontoRonda and not (node as PontoRonda).ativo:
					continue
				pontos_patrulha.append(node as Node3D)

	pontos_wall_peek.clear()
	for node in get_tree().get_nodes_in_group("pontos_wall_peek"):
		if node is Node3D:
			if node is PontoRonda and not (node as PontoRonda).ativo:
				continue
			pontos_wall_peek.append(node as Node3D)

	pontos_entrada_saida.clear()
	for node in get_tree().get_nodes_in_group("pontos_entrada_saida_rondante"):
		if node is Node3D:
			if node is PontoRonda and not (node as PontoRonda).ativo:
				continue
			pontos_entrada_saida.append(node as Node3D)

	_waypoints_path3d.clear()
	for node in get_tree().get_nodes_in_group("rotas_rondante"):
		if node is Path3D:
			var path := node as Path3D
			if path.curve != null and path.curve.get_baked_length() > 0.5:
				var comp := path.curve.get_baked_length()
				var passo := maxf(4.0, comp / maxf(2.0, floorf(comp / 6.0)))
				var dist := 0.0
				while dist <= comp:
					var pt_local := path.curve.sample_baked(dist)
					_waypoints_path3d.append(path.to_global(pt_local))
					dist += passo


func _obter_config_efetiva() -> CriaturaConfig:
	if config == null:
		config = CriaturaConfig.criar_padrao_rondante()
	return config


func mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return
	var anterior := estado_atual
	estado_atual = novo_estado
	_tempo_bloqueado_movimento = 0.0
	_timer_memoria_desvio = 0.0
	_tempo_sem_progresso_alvo = 0.0
	_menor_dist_alvo_mov = INF
	if novo_estado == Estado.PATRULHA or novo_estado == Estado.INATIVO or novo_estado == Estado.EM_ESPERA:
		viu_jogador_entrar_esconderijo = false
	if novo_estado == Estado.PATRULHA:
		_prioridade_som_atual = 0.0
	_sincronizar_animacao_estado(novo_estado)
	if novo_estado == Estado.BUSCA_FRUSTRADA and is_inside_tree():
		BancoAudioDelusio.tocar_3d(self, &"rondante_bater_chao", global_position, 0.0, 30.0, 0.06)
	estado_alterado.emit(int(novo_estado), int(anterior))


func _sincronizar_animacao_estado(estado: Estado) -> void:
	if anim_player == null:
		return
	match estado:
		Estado.INATIVO, Estado.EM_ESPERA:
			anim_player.stop()
		Estado.PATRULHA, Estado.RETIRANDO:
			_tocar_animacao(&"walkcycle", 1.0)
		Estado.INVESTIGANDO:
			_tocar_animacao(&"walkcycle", 1.2)
		Estado.CACADA:
			_tocar_animacao(&"walkcycle", 1.75)
		Estado.ESPREITA_QUINA:
			_tocar_animacao(&"wall_peek", 1.0)
		Estado.BUSCA_FRUSTRADA:
			_tocar_animacao(&"bater_chao", 1.0)
		Estado.ATORDOADO_LUZ:
			_tocar_animacao(&"desnorteado", 1.0)
		Estado.ATAQUE_GARRAS:
			_tocar_animacao(&"atacar_garras", 1.25)


func _tocar_animacao(nome: StringName, velocidade: float = 1.0) -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(nome):
		anim_player.play(nome, 0.18, velocidade)
	elif nome == &"bater_chao" and anim_player.has_animation(&"desnorteado"):
		anim_player.play(&"desnorteado", 0.18, velocidade)
	elif anim_player.has_animation(&"walkcycle"):
		anim_player.play(&"walkcycle", 0.18, velocidade)


func ativar() -> void:
	var cfg := _obter_config_efetiva()
	_garantir_estrutura_nos()
	atualizar_rotas_do_mapa()
	super.ativar()
	set_physics_process(true)
	tempo_foco_lanterna_acumulado = 0.0
	tempo_atordoado_restante = 0.0
	cooldown_atordoamento_restante = 0.0
	tempo_espreita_quina_restante = 0.0
	tempo_ataque_restante = 0.0
	pressao_ruido_atual = 0.0
	_prioridade_som_atual = 0.0
	_tempo_bloqueado_movimento = 0.0
	_timer_memoria_desvio = 0.0
	_tempo_sem_progresso_alvo = 0.0
	_menor_dist_alvo_mov = INF
	viu_jogador_entrar_esconderijo = false
	_pontos_espreita_visitados.clear()

	if cfg.modo_presenca_rondante == CriaturaConfig.ModoPresencaRondante.PRESSAO_DINAMICA:
		visible = false
		mudar_estado(Estado.EM_ESPERA)
	else:
		visible = true
		tempo_ronda_restante = randf_range(cfg.duracao_ronda_min, cfg.duracao_ronda_max)
		mudar_estado(Estado.PATRULHA)


func desativar() -> void:
	super.desativar()
	set_physics_process(false)
	tempo_foco_lanterna_acumulado = 0.0
	tempo_atordoado_restante = 0.0
	tempo_investigacao_restante = 0.0
	tempo_tolerancia_esconderijo_restante = 0.0
	tempo_espreita_quina_restante = 0.0
	tempo_ataque_restante = 0.0
	pressao_ruido_atual = 0.0
	_prioridade_som_atual = 0.0
	_tempo_bloqueado_movimento = 0.0
	_timer_memoria_desvio = 0.0
	_tempo_sem_progresso_alvo = 0.0
	_menor_dist_alvo_mov = INF
	viu_jogador_entrar_esconderijo = false
	mudar_estado(Estado.INATIVO)


func registrar_pressao_ruido(valor: float, pos_origem: Vector3 = Vector3.ZERO) -> void:
	if not ativa or estado_atual != Estado.EM_ESPERA:
		return
	var cfg := _obter_config_efetiva()
	pressao_ruido_atual += maxf(0.0, valor)
	if pressao_ruido_atual >= cfg.limiar_pressao_entrada:
		tentar_entrar_por_pressao(pos_origem)


func tentar_entrar_por_pressao(pos_interesse: Vector3 = Vector3.ZERO) -> bool:
	if not ativa:
		return false
	var cfg := _obter_config_efetiva()

	var gerente := GameManager.instance
	if gerente != null and gerente.diretor_eventos_noite != null and gerente.diretor_eventos_noite.has_method("pode_rondante_entrar"):
		if not gerente.diretor_eventos_noite.pode_rondante_entrar():
			return false

	var ponto_spawn := _escolher_ponto_entrada_saida(true)
	global_position = ponto_spawn
	_ajustar_altura_chao(true)
	var space := _obter_espaco_3d()
	if space != null:
		global_position = _despenetrar_horizontalmente(global_position, space, _obter_excecoes_raycast(_obter_player()))
	visible = true
	pressao_ruido_atual = 0.0
	tempo_ronda_restante = randf_range(cfg.duracao_ronda_min, cfg.duracao_ronda_max)

	if pos_interesse != Vector3.ZERO:
		ultima_posicao_som = pos_interesse
		tempo_investigacao_restante = duracao_investigacao
		mudar_estado(Estado.INVESTIGANDO)
	else:
		mudar_estado(Estado.PATRULHA)

	ronda_iniciada_por_pressao.emit(global_position)
	return true


func _escolher_ponto_entrada_saida(exigir_fora_visao: bool) -> Vector3:
	var cfg := _obter_config_efetiva()
	var player := _obter_player()
	var cam := player.camera if player != null else null
	var pos_ref := player.global_position if player != null else global_position

	var candidatas: Array[Vector3] = []
	for p in pontos_entrada_saida:
		if p != null and is_instance_valid(p):
			candidatas.append(p.global_position)

	if candidatas.is_empty():
		var dist_min := maxf(16.0, cfg.distancia_min_spawn_jogador)
		for i in range(8):
			var ang := float(i) * (TAU / 8.0)
			candidatas.append(pos_ref + Vector3(cos(ang) * dist_min, 0.0, sin(ang) * dist_min))

	var melhor := candidatas[0]
	var melhor_score := -99999.0
	for cand in candidatas:
		var d := cand.distance_to(pos_ref)
		var score := d
		if exigir_fora_visao and d < cfg.distancia_min_spawn_jogador:
			score -= 100.0
		if exigir_fora_visao and cam != null:
			var cam_fwd := -cam.global_transform.basis.z.normalized()
			var dir_c := (cand - cam.global_position).normalized()
			if cam_fwd.dot(dir_c) > 0.35:
				score -= 60.0
		if not _posicao_livre_colisao(cand):
			score -= 250.0
		if score > melhor_score:
			melhor_score = score
			melhor = cand

	return melhor


func receber_estimulo_sonoro(pos: Vector3, raio: float) -> void:
	super.receber_estimulo_sonoro(pos, raio)
	if not ativa or estado_atual == Estado.INATIVO or estado_atual == Estado.ATORDOADO_LUZ or estado_atual == Estado.ATAQUE_GARRAS:
		return

	if estado_atual == Estado.EM_ESPERA:
		registrar_pressao_ruido(clampf(raio * 1.4, 8.0, 45.0), pos)
		return

	var cfg := _obter_config_efetiva()
	var alcance_efetivo := maxf(raio, cfg.raio_audicao_passos)
	if global_position.distance_to(pos) > alcance_efetivo:
		return

	if estado_atual == Estado.INVESTIGANDO and raio < _prioridade_som_atual and _distancia_xz(global_position, ultima_posicao_som) > 2.5:
		return

	_prioridade_som_atual = raio
	ultima_posicao_som = pos
	tempo_investigacao_restante = duracao_investigacao
	_tempo_sem_progresso_alvo = 0.0
	_menor_dist_alvo_mov = INF

	if estado_atual in [Estado.PATRULHA, Estado.INVESTIGANDO, Estado.ESPREITA_QUINA, Estado.BUSCA_FRUSTRADA, Estado.RETIRANDO]:
		mudar_estado(Estado.INVESTIGANDO)
		som_investigado.emit(pos)


func receber_foco_lanterna(delta: float) -> void:
	super.receber_foco_lanterna(delta)
	if not ativa or estado_atual in [Estado.INATIVO, Estado.EM_ESPERA, Estado.ATAQUE_GARRAS]:
		return
	var cfg := _obter_config_efetiva()
	if not cfg.sensivel_a_luz:
		return
	if cooldown_atordoamento_restante > 0.0 or estado_atual == Estado.ATORDOADO_LUZ:
		return

	tempo_foco_lanterna_acumulado += delta
	if tempo_foco_lanterna_acumulado >= tempo_foco_para_atordoar:
		tempo_foco_lanterna_acumulado = 0.0
		tempo_atordoado_restante = duracao_atordoamento_luz
		cooldown_atordoamento_restante = cooldown_atordoamento_max
		mudar_estado(Estado.ATORDOADO_LUZ)
		if is_inside_tree():
			BancoAudioDelusio.tocar_3d(self, &"rondante_atordoado", global_position, -1.0, 26.0, 0.05)
		atordoado_por_luz.emit(duracao_atordoamento_luz)

		# Dilema tático: usar a lanterna contra o Rondante atrai a Silhueta
		var gerente := GameManager.instance
		if gerente != null and gerente.silhueta != null and is_instance_valid(gerente.silhueta):
			var sil = gerente.silhueta
			if ("ativa" in sil) and sil.ativa and sil.has_method("avancar_anel"):
				sil.avancar_anel()


func notificar_jogador_entrou_esconderijo(player: Player) -> void:
	if not ativa or player == null:
		return
	if estado_atual == Estado.CACADA and pode_ver_jogador_sem_esconderijo(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= 4.5:
			viu_jogador_entrar_esconderijo = true


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


func tem_linha_de_visao(player: Player) -> bool:
	if player == null:
		return false
	if not usar_raycast_oclusao:
		return true
	var space := _obter_espaco_3d()
	if space == null:
		return true

	var origem := global_position + Vector3(0.0, 1.8, 0.0)
	var excl := _obter_excecoes_raycast(player)
	for offset_y in [1.3, 1.68]:
		var destino := player.global_position + Vector3(0.0, offset_y, 0.0)
		if origem.distance_squared_to(destino) < 0.04:
			return true

		var query := PhysicsRayQueryParameters3D.create(origem, destino, mascara_colisao_ambiente, excl)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true

		var col_hit: Object = hit.get("collider")
		if player.esconderijo_atual != null and is_instance_valid(player.esconderijo_atual):
			if col_hit == player.esconderijo_atual or (col_hit is Node and player.esconderijo_atual.is_ancestor_of(col_hit as Node)):
				return true

		var normal_hit: Vector3 = hit.get("normal", Vector3.ZERO)
		var pos_hit: Vector3 = hit.get("position", origem)
		if normal_hit.y >= 0.70 and pos_hit.distance_to(destino) <= 0.65:
			return true

	return false


func _obter_dificuldade_endless() -> Dictionary:
	var gerente := GameManager.instance
	if gerente != null and gerente.has_method("obter_parametros_dificuldade_dia"):
		return gerente.obter_parametros_dificuldade_dia()
	return {"mult_velocidade_monstros": 1.0, "mult_visao_rondante": 1.0}


func pode_ver_jogador_sem_esconderijo(player: Player) -> bool:
	if player == null or not ativa or estado_atual in [Estado.INATIVO, Estado.EM_ESPERA]:
		return false
	var cfg := _obter_config_efetiva()
	var dif: Dictionary = _obter_dificuldade_endless()
	var alcance := cfg.raio_visao * (1.25 if player.esta_com_lanterna_acesa() else 1.0) * float(dif.get("mult_visao_rondante", 1.0))
	if _jogador_em_zona_breu(player):
		alcance *= _obter_mult_visao_zona_breu()
	var diff := player.global_position - global_position
	var dist_xz := Vector2(diff.x, diff.z).length()
	if dist_xz > alcance or absf(diff.y) > 8.0:
		return false
	if dist_xz <= 2.2:
		return tem_linha_de_visao(player)

	var frente := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	if frente.length_squared() < 0.0001:
		frente = Vector3(0.0, 0.0, -1.0)
	else:
		frente = frente.normalized()

	var dir_p := Vector3(diff.x, 0.0, diff.z).normalized()
	var angulo := rad_to_deg(frente.angle_to(dir_p))
	if angulo > cfg.angulo_visao_graus * 0.5:
		return false
	return tem_linha_de_visao(player)


func pode_ver_jogador(player: Player) -> bool:
	if player == null or not ativa or estado_atual in [Estado.INATIVO, Estado.EM_ESPERA]:
		return false
	if player.esta_escondido():
		if viu_jogador_entrar_esconderijo:
			return true
		if player.esconderijo_atual != null and player.esconderijo_atual.has_method("esta_comprometido"):
			if player.esconderijo_atual.esta_comprometido(player):
				return true
		return false

	viu_jogador_entrar_esconderijo = false
	return pode_ver_jogador_sem_esconderijo(player)


func _process(delta: float) -> void:
	processar_ia(delta)


func processar_ia(delta: float) -> void:
	if not ativa or estado_atual == Estado.INATIVO:
		return
	if GameManager.instance != null and GameManager.instance.jogo_encerrado:
		return

	var cfg := _obter_config_efetiva()
	var dif: Dictionary = _obter_dificuldade_endless()
	var mult_vel: float = float(dif.get("mult_velocidade_monstros", 1.0))
	cooldown_atordoamento_restante = maxf(0.0, cooldown_atordoamento_restante - delta)

	if estado_atual == Estado.EM_ESPERA:
		return

	var player := _obter_player()
	_processar_foco_lanterna_jogador(player, delta)

	match estado_atual:
		Estado.PATRULHA:
			if pode_ver_jogador(player):
				_entrar_em_cacada(player, cfg)
				return

			if cfg.modo_presenca_rondante == CriaturaConfig.ModoPresencaRondante.PRESSAO_DINAMICA:
				tempo_ronda_restante -= delta
				if tempo_ronda_restante <= 0.0:
					_iniciar_retirada()
					return

			var ponto_peek := _buscar_ponto_wall_peek_proximo()
			if ponto_peek != null:
				iniciar_espreita_quina(ponto_peek)
				return

			var alvo_patrulha := obter_waypoint_atual()
			_mover_para(alvo_patrulha, cfg.velocidade_patrulha * mult_vel, delta)
			_processar_audio_passos(delta, cadencia_passos_patrulha)
			if _distancia_xz(global_position, alvo_patrulha) <= 1.1:
				avancar_waypoint_patrulha()
			elif _tempo_bloqueado_movimento >= 2.5 or _tempo_sem_progresso_alvo >= 4.5:
				_tempo_bloqueado_movimento = 0.0
				_tempo_sem_progresso_alvo = 0.0
				avancar_waypoint_patrulha()

		Estado.ESPREITA_QUINA:
			if pode_ver_jogador(player):
				_entrar_em_cacada(player, cfg)
				return
			if _direcao_espreita_atual.length_squared() > 0.001:
				_rotacionar_para_direcao(_direcao_espreita_atual, delta, 5.0)
			tempo_espreita_quina_restante -= delta
			if tempo_espreita_quina_restante <= 0.0:
				mudar_estado(Estado.PATRULHA)

		Estado.INVESTIGANDO:
			if pode_ver_jogador(player):
				_entrar_em_cacada(player, cfg)
				return

			var vel_investigar := ((cfg.velocidade_patrulha + cfg.velocidade_perseguicao) * 0.5) * mult_vel
			if _distancia_xz(global_position, ultima_posicao_som) > 1.2:
				_mover_para(ultima_posicao_som, vel_investigar, delta)
				_processar_audio_passos(delta, cadencia_passos_patrulha * 0.85)
				if _tempo_bloqueado_movimento >= 1.0 or _tempo_sem_progresso_alvo >= 1.5:
					tempo_investigacao_restante -= delta
					if tempo_investigacao_restante <= 0.0:
						mudar_estado(Estado.PATRULHA)
			else:
				tempo_investigacao_restante -= delta
				if tempo_investigacao_restante <= 0.0:
					mudar_estado(Estado.PATRULHA)

		Estado.CACADA:
			if pode_ver_jogador(player):
				ultima_posicao_vista_jogador = player.global_position
				tempo_tolerancia_esconderijo_restante = cfg.tempo_tolerancia_esconderijo
				if _esta_no_alcance_captura(player):
					_iniciar_ataque_garras(player)
					return
				_mover_para(player.global_position, cfg.velocidade_perseguicao * mult_vel, delta)
				_processar_audio_passos(delta, cadencia_passos_cacada)
				if _esta_no_alcance_captura(player):
					_iniciar_ataque_garras(player)
			else:
				if _distancia_xz(global_position, ultima_posicao_vista_jogador) > 1.3:
					_mover_para(ultima_posicao_vista_jogador, cfg.velocidade_perseguicao * 0.85 * mult_vel, delta)
					_processar_audio_passos(delta, cadencia_passos_cacada)
					tempo_tolerancia_esconderijo_restante -= delta
					if tempo_tolerancia_esconderijo_restante <= 0.0:
						mudar_estado(Estado.PATRULHA)
				else:
					mudar_estado(Estado.BUSCA_FRUSTRADA)

		Estado.BUSCA_FRUSTRADA:
			if pode_ver_jogador(player):
				_entrar_em_cacada(player, cfg)
				return
			tempo_tolerancia_esconderijo_restante -= delta
			if tempo_tolerancia_esconderijo_restante <= 0.0:
				mudar_estado(Estado.PATRULHA)

		Estado.ATAQUE_GARRAS:
			tempo_ataque_restante -= delta
			if tempo_ataque_restante <= 0.0:
				if player != null and not player.esta_escondido() and _distancia_xz(global_position, player.global_position) <= alcance_ataque_garras and tem_linha_de_visao(player):
					realizar_captura(player)
				else:
					if player != null:
						ultima_posicao_som = player.global_position
						tempo_investigacao_restante = duracao_investigacao * 0.6
					mudar_estado(Estado.INVESTIGANDO)

		Estado.ATORDOADO_LUZ:
			if player != null:
				var dir_recuo := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z)
				if dir_recuo.length_squared() > 0.001:
					_mover_com_colisao(dir_recuo.normalized() * (cfg.velocidade_patrulha * 0.12) * delta)
					_ajustar_altura_chao(false)

			tempo_atordoado_restante -= delta
			if tempo_atordoado_restante <= 0.0:
				if player != null:
					ultima_posicao_som = player.global_position
					tempo_investigacao_restante = duracao_investigacao * 0.75
					mudar_estado(Estado.INVESTIGANDO)
				else:
					mudar_estado(Estado.PATRULHA)

		Estado.RETIRANDO:
			if pode_ver_jogador(player):
				_entrar_em_cacada(player, cfg)
				return
			_mover_para(_destino_retirada, cfg.velocidade_patrulha * 1.1 * mult_vel, delta)
			_processar_audio_passos(delta, cadencia_passos_patrulha)
			if _distancia_xz(global_position, _destino_retirada) <= 1.5 or _tempo_bloqueado_movimento >= 3.5 or _tempo_sem_progresso_alvo >= 5.0:
				visible = false
				pressao_ruido_atual = 0.0
				mudar_estado(Estado.EM_ESPERA)
				ronda_encerrada_retirada.emit()


func _entrar_em_cacada(_player: Player, _cfg: CriaturaConfig) -> void:
	# Mecânica de perseguição removida: mantém patrulha normal.
	if estado_atual != Estado.PATRULHA:
		mudar_estado(Estado.PATRULHA)


func _iniciar_ataque_garras(_player: Player) -> void:
	mudar_estado(Estado.PATRULHA)


func _iniciar_retirada() -> void:
	_destino_retirada = _escolher_ponto_entrada_saida(true)
	mudar_estado(Estado.RETIRANDO)


func iniciar_espreita_quina(ponto: Node3D, duracao_custom: float = -1.0) -> void:
	if ponto == null:
		return
	var id_ponto := ponto.get_instance_id()
	_pontos_espreita_visitados[id_ponto] = Time.get_ticks_msec()
	if duracao_custom > 0.0:
		tempo_espreita_quina_restante = duracao_custom
	elif ponto is PontoRonda:
		tempo_espreita_quina_restante = (ponto as PontoRonda).tempo_espreita
	else:
		tempo_espreita_quina_restante = 2.5

	if ponto is PontoRonda:
		_direcao_espreita_atual = (ponto as PontoRonda).obter_direcao_espreita()
	else:
		var f := -ponto.global_transform.basis.z
		_direcao_espreita_atual = Vector3(f.x, 0.0, f.z).normalized()
		if _direcao_espreita_atual.length_squared() < 0.001:
			_direcao_espreita_atual = Vector3.FORWARD

	mudar_estado(Estado.ESPREITA_QUINA)


func _buscar_ponto_wall_peek_proximo() -> Node3D:
	if pontos_wall_peek.is_empty():
		return null
	var agora := Time.get_ticks_msec()
	for p in pontos_wall_peek:
		if p == null or not is_instance_valid(p):
			continue
		if _distancia_xz(global_position, p.global_position) <= 1.4:
			var ultimo_ms: int = int(_pontos_espreita_visitados.get(p.get_instance_id(), -999999))
			if agora - ultimo_ms >= 18000:
				return p
	return null


func _processar_audio_passos(delta: float, cadencia: float) -> void:
	_timer_passos += delta
	if _timer_passos >= cadencia:
		_timer_passos = 0.0
		if audio_passos != null and audio_passos.stream != null:
			audio_passos.play()


func _processar_foco_lanterna_jogador(player: Player, delta: float) -> void:
	if player == null or not player.esta_com_lanterna_acesa() or player.camera == null:
		tempo_foco_lanterna_acumulado = maxf(0.0, tempo_foco_lanterna_acumulado - delta * 0.5)
		return
	if not tem_linha_de_visao(player):
		tempo_foco_lanterna_acumulado = maxf(0.0, tempo_foco_lanterna_acumulado - delta * 0.5)
		return

	var cam := player.camera
	var alvo_cabeca := global_position + Vector3(0.0, 1.5, 0.0)
	var dist := cam.global_position.distance_to(alvo_cabeca)
	if dist > 14.0 or dist < 0.1:
		tempo_foco_lanterna_acumulado = maxf(0.0, tempo_foco_lanterna_acumulado - delta * 0.5)
		return

	var cam_forward := -cam.global_transform.basis.z.normalized()
	var dir_alvo := (alvo_cabeca - cam.global_position).normalized()
	if cam_forward.dot(dir_alvo) >= 0.82:
		receber_foco_lanterna(delta)
	else:
		tempo_foco_lanterna_acumulado = maxf(0.0, tempo_foco_lanterna_acumulado - delta * 0.5)


func _obter_forma_colisao_corpo() -> CapsuleShape3D:
	if _forma_colisao_corpo == null:
		_forma_colisao_corpo = CapsuleShape3D.new()
	_forma_colisao_corpo.radius = maxf(0.15, raio_colisao_corpo)
	_forma_colisao_corpo.height = maxf(_forma_colisao_corpo.radius * 2.0 + 0.1, altura_colisao_corpo)
	return _forma_colisao_corpo


func _posicao_livre_colisao(pos_base: Vector3) -> bool:
	if not usar_colisao_paredes:
		return true
	var space := _obter_espaco_3d()
	if space == null:
		return true
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _obter_forma_colisao_corpo()
	params.transform = Transform3D(Basis.IDENTITY, pos_base + Vector3(0.0, offset_y_colisao_corpo, 0.0))
	params.collision_mask = mascara_colisao_ambiente
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = _obter_excecoes_raycast(_obter_player())
	return space.intersect_shape(params, 1).is_empty()


func _despenetrar_horizontalmente(pos_base: Vector3, space: PhysicsDirectSpaceState3D, excl: Array[RID]) -> Vector3:
	if not usar_colisao_paredes or space == null:
		return pos_base
	var pos := pos_base
	var forma := _obter_forma_colisao_corpo()
	for _i in range(3):
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = forma
		params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, offset_y_colisao_corpo, 0.0))
		params.motion = Vector3.ZERO
		params.margin = 0.01
		params.collision_mask = mascara_colisao_ambiente
		params.collide_with_bodies = true
		params.collide_with_areas = false
		params.exclude = excl
		var rest := space.get_rest_info(params)
		if rest.is_empty():
			break
		var normal: Vector3 = rest.get("normal", Vector3.ZERO)
		if absf(normal.y) >= 0.75:
			break
		var n_xz := Vector3(normal.x, 0.0, normal.z)
		if n_xz.length_squared() < 0.0001:
			break
		n_xz = n_xz.normalized()
		var pts := space.collide_shape(params, 8)
		var profundidade := 0.0
		for j in range(0, pts.size() - 1, 2):
			var proj := (pts[j + 1] - pts[j]).dot(n_xz)
			if proj > profundidade:
				profundidade = proj
		if profundidade <= 0.0:
			profundidade = 0.02
		profundidade = minf(profundidade, 0.25)
		pos += n_xz * (profundidade + 0.005)
	return pos


func _obter_normal_parede_colisao(pos_base: Vector3, dir_mov: Vector3, dist_sobra: float, hit_ray: Dictionary, space: PhysicsDirectSpaceState3D, excl: Array[RID]) -> Vector3:
	var params_rest := PhysicsShapeQueryParameters3D.new()
	params_rest.shape = _obter_forma_colisao_corpo()
	params_rest.transform = Transform3D(
		Basis.IDENTITY,
		pos_base + Vector3(0.0, offset_y_colisao_corpo, 0.0) + dir_mov * minf(0.06, dist_sobra + 0.03)
	)
	params_rest.motion = Vector3.ZERO
	params_rest.margin = 0.04
	params_rest.collision_mask = mascara_colisao_ambiente
	params_rest.collide_with_bodies = true
	params_rest.collide_with_areas = false
	params_rest.exclude = excl
	var rest := space.get_rest_info(params_rest)
	if not rest.is_empty():
		var n_rest: Vector3 = rest.get("normal", Vector3.ZERO)
		if Vector3(n_rest.x, 0.0, n_rest.z).length_squared() >= 0.0001:
			return n_rest

	if not hit_ray.is_empty():
		var n_ray: Vector3 = hit_ray.get("normal", Vector3.ZERO)
		if Vector3(n_ray.x, 0.0, n_ray.z).length_squared() >= 0.0001:
			return n_ray

	var alcance_curto := maxf(0.15, raio_colisao_corpo + 0.25)
	for h in [1.0, 0.55]:
		var origem_c := pos_base + Vector3(0.0, h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(origem_c, origem_c + dir_mov * alcance_curto, mascara_colisao_ambiente, excl)
		q.hit_from_inside = true
		var hit_c := space.intersect_ray(q)
		if not hit_c.is_empty():
			var n_c: Vector3 = hit_c.get("normal", Vector3.ZERO)
			if Vector3(n_c.x, 0.0, n_c.z).length_squared() >= 0.0001:
				return n_c

	return Vector3.ZERO


func _mover_com_colisao(deslocamento_xz: Vector3) -> Vector3:
	var disp := Vector3(deslocamento_xz.x, 0.0, deslocamento_xz.z)
	if disp.length_squared() <= 0.0000001:
		return Vector3.ZERO
	if not usar_colisao_paredes:
		global_position += disp
		return disp
	var space := _obter_espaco_3d()
	if space == null:
		global_position += disp
		return disp

	var excl := _obter_excecoes_raycast(_obter_player())
	var pos_inicial := global_position
	var pos_atual := _despenetrar_horizontalmente(pos_inicial, space, excl)
	var forma := _obter_forma_colisao_corpo()
	var restante := disp

	for _iter in range(3):
		var len_rest := restante.length()
		if len_rest <= 0.001:
			break
		var dir_rest := restante / len_rest

		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = forma
		params.transform = Transform3D(Basis.IDENTITY, pos_atual + Vector3(0.0, offset_y_colisao_corpo, 0.0))
		params.motion = restante
		params.margin = 0.02
		params.collision_mask = mascara_colisao_ambiente
		params.collide_with_bodies = true
		params.collide_with_areas = false
		params.exclude = excl

		var origem_ray := pos_atual + Vector3(0.0, 1.0, 0.0)
		var q_ray := PhysicsRayQueryParameters3D.create(
			origem_ray,
			origem_ray + restante + dir_rest * raio_colisao_corpo,
			mascara_colisao_ambiente,
			excl
		)
		q_ray.hit_from_inside = true
		var hit_ray := space.intersect_ray(q_ray)
		var cast := space.cast_motion(params)

		var cast_livre := cast.is_empty() or (cast[0] >= 1.0 and cast[1] >= 1.0)
		if cast_livre and hit_ray.is_empty():
			pos_atual += restante
			break

		var f_segura := 1.0
		if not cast.is_empty():
			f_segura = maxf(0.0, cast[0] - 0.002)
		if not hit_ray.is_empty():
			var dist_hit := origem_ray.distance_to(hit_ray["position"] as Vector3)
			f_segura = minf(f_segura, maxf(0.0, (dist_hit - raio_colisao_corpo - 0.02) / len_rest))

		pos_atual += restante * f_segura
		var sobra := restante * (1.0 - f_segura)
		var normal := _obter_normal_parede_colisao(pos_atual, dir_rest, sobra.length(), hit_ray, space, excl)
		var n_xz := Vector3(normal.x, 0.0, normal.z)
		if n_xz.length_squared() < 0.0001:
			break
		n_xz = n_xz.normalized()
		if sobra.dot(n_xz) < 0.0:
			restante = sobra.slide(n_xz)
		else:
			break

	global_position.x = pos_atual.x
	global_position.z = pos_atual.z
	return Vector3(pos_atual.x - pos_inicial.x, 0.0, pos_atual.z - pos_inicial.z)


func _distancia_livre_direcao(dir_cand: Vector3, alcance: float, space: PhysicsDirectSpaceState3D, excl: Array[RID]) -> float:
	var d := Vector3(dir_cand.x, 0.0, dir_cand.z)
	if d.length_squared() < 0.0001:
		return 0.0
	d = d.normalized()
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _obter_forma_colisao_corpo()
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, offset_y_colisao_corpo, 0.0))
	params.motion = d * alcance
	params.margin = 0.02
	params.collision_mask = mascara_colisao_ambiente
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = excl
	var cast := space.cast_motion(params)
	var frac := 1.0 if cast.is_empty() else clampf(cast[0], 0.0, 1.0)

	var origem_ray := global_position + Vector3(0.0, 1.0, 0.0)
	var q_ray := PhysicsRayQueryParameters3D.create(
		origem_ray,
		origem_ray + d * (alcance + raio_colisao_corpo),
		mascara_colisao_ambiente,
		excl
	)
	q_ray.hit_from_inside = true
	var hit_ray := space.intersect_ray(q_ray)
	if not hit_ray.is_empty():
		var dist_hit := origem_ray.distance_to(hit_ray["position"] as Vector3)
		var frac_ray := clampf((dist_hit - raio_colisao_corpo - 0.02) / maxf(0.001, alcance), 0.0, 1.0)
		frac = minf(frac, frac_ray)

	return frac * alcance


func _ajustar_altura_chao(permitir_ajuste_amplo: bool = false) -> void:
	var space := _obter_espaco_3d()
	if space == null:
		return
	var alt_topo := 1.5 if permitir_ajuste_amplo else maxf(0.55, altura_max_degrau + 0.1)
	var alt_base := 3.0 if permitir_ajuste_amplo else 2.5
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, alt_topo, 0.0),
		global_position - Vector3(0.0, alt_base, 0.0),
		mascara_colisao_ambiente,
		_obter_excecoes_raycast(_obter_player())
	)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var normal_chao: Vector3 = hit.get("normal", Vector3.UP)
		if normal_chao.y < 0.55:
			return
		var hit_y: float = (hit["position"] as Vector3).y
		if permitir_ajuste_amplo:
			if absf(hit_y - global_position.y) <= 2.5:
				global_position.y = hit_y
		else:
			var diff_y := hit_y - global_position.y
			if diff_y <= altura_max_degrau and diff_y >= -1.8:
				global_position.y = hit_y


func _aplicar_desvio_obstaculo(dir: Vector3, delta: float = 0.016) -> Vector3:
	_timer_memoria_desvio = maxf(0.0, _timer_memoria_desvio - delta)
	if not usar_desvio_obstaculo_raycast:
		return dir
	var space := _obter_espaco_3d()
	if space == null:
		return dir

	var excl := _obter_excecoes_raycast(_obter_player())
	if _distancia_livre_direcao(dir, 1.5, space, excl) >= 1.48:
		return dir

	var alcance_teste := 1.6
	if _timer_memoria_desvio <= 0.0:
		var folga_pos := _distancia_livre_direcao(dir.rotated(Vector3.UP, deg_to_rad(35.0)), alcance_teste, space, excl)
		var folga_neg := _distancia_livre_direcao(dir.rotated(Vector3.UP, deg_to_rad(-35.0)), alcance_teste, space, excl)
		if absf(folga_pos - folga_neg) < 0.05:
			for ang_desempate in [65.0, 95.0]:
				var fp := _distancia_livre_direcao(dir.rotated(Vector3.UP, deg_to_rad(ang_desempate)), alcance_teste, space, excl)
				var fn := _distancia_livre_direcao(dir.rotated(Vector3.UP, deg_to_rad(-ang_desempate)), alcance_teste, space, excl)
				if absf(fp - fn) >= 0.05:
					folga_pos = fp
					folga_neg = fn
					break
		_sentido_desvio_preferido = 1.0 if folga_pos >= folga_neg else -1.0
		_timer_memoria_desvio = 0.85

	var melhor_dir := dir
	var melhor_folga := _distancia_livre_direcao(dir, alcance_teste, space, excl)
	for ang in [35.0, 65.0, 95.0, 130.0]:
		for sinal in [_sentido_desvio_preferido, -_sentido_desvio_preferido]:
			var cand := dir.rotated(Vector3.UP, deg_to_rad(ang * sinal)).normalized()
			var folga := _distancia_livre_direcao(cand, alcance_teste, space, excl)
			if folga >= 1.55:
				if sinal != _sentido_desvio_preferido:
					_sentido_desvio_preferido = sinal
					_timer_memoria_desvio = 0.85
				return cand
			if folga > melhor_folga:
				melhor_folga = folga
				melhor_dir = cand

	return melhor_dir


func _mover_para(destino: Vector3, velocidade: float, delta: float) -> void:
	var alvo_passo := destino
	var usando_navmesh := false
	if nav_agent != null and is_inside_tree():
		var nav_map := nav_agent.get_navigation_map()
		if nav_map.is_valid() and NavigationServer3D.map_get_regions(nav_map).size() > 0:
			usando_navmesh = true
			nav_agent.target_position = destino
			var next_pos := nav_agent.get_next_path_position()
			if _distancia_xz(global_position, next_pos) > 0.05:
				alvo_passo = next_pos

	var delta_xz := Vector3(alvo_passo.x - global_position.x, 0.0, alvo_passo.z - global_position.z)
	var dist_xz := delta_xz.length()
	if dist_xz <= 0.001:
		return

	var passo_max := velocidade * delta
	var dir_base := delta_xz / dist_xz
	var dir := dir_base
	if not usando_navmesh:
		dir = _aplicar_desvio_obstaculo(dir, delta)

	var passo := minf(passo_max, dist_xz) if dir.distance_squared_to(dir_base) < 0.0001 else passo_max
	var desloc_real := _mover_com_colisao(dir * passo)

	if passo > 0.003 and desloc_real.length() < passo * 0.20:
		var era_menor := _tempo_bloqueado_movimento < 0.9
		_tempo_bloqueado_movimento += delta
		if era_menor and _tempo_bloqueado_movimento >= 0.9:
			_sentido_desvio_preferido *= -1.0
			_timer_memoria_desvio = 1.0
	else:
		_tempo_bloqueado_movimento = maxf(0.0, _tempo_bloqueado_movimento - delta * 2.0)

	var dist_depois := _distancia_xz(global_position, alvo_passo)
	if _menor_dist_alvo_mov == INF or dist_depois < _menor_dist_alvo_mov - 0.15:
		_menor_dist_alvo_mov = dist_depois
		_tempo_sem_progresso_alvo = 0.0
	else:
		_tempo_sem_progresso_alvo += delta

	_ajustar_altura_chao(false)

	if dist_xz > 0.05:
		var vel_giro := velocidade_giro_cacada if estado_atual == Estado.CACADA else velocidade_giro_patrulha
		var dir_rot := desloc_real.normalized() if desloc_real.length_squared() > 0.00002 else dir
		_rotacionar_para_direcao(dir_rot, delta, vel_giro)


func _rotacionar_para_direcao(dir_xz: Vector3, delta: float, vel_giro: float) -> void:
	var d := Vector3(dir_xz.x, 0.0, dir_xz.z)
	if d.length_squared() < 0.0001:
		return
	d = d.normalized()
	var yaw_alvo := atan2(-d.x, -d.z)
	if delta <= 0.0:
		rotation.y = yaw_alvo
	else:
		rotation.y = lerp_angle(rotation.y, yaw_alvo, clampf(vel_giro * delta, 0.0, 1.0))


func _jogador_em_zona_breu(player: Player) -> bool:
	if player == null or get_tree() == null:
		return false
	for z in get_tree().get_nodes_in_group("zona_breu_noturno"):
		if z != null and is_instance_valid(z) and z.has_method("esta_jogador_dentro"):
			if z.esta_jogador_dentro(player):
				return true
	return false


func _obter_mult_visao_zona_breu() -> float:
	if get_tree() == null:
		return 1.25
	for z in get_tree().get_nodes_in_group("zona_breu_noturno"):
		if z != null and is_instance_valid(z) and ("multiplicador_visao_rondante" in z):
			return maxf(1.0, float(z.multiplicador_visao_rondante))
	return 1.25


func _gerar_waypoints_procedurais() -> Array[Vector3]:
	if not _waypoints_procedurais.is_empty():
		return _waypoints_procedurais
	var player := _obter_player()
	var centro := player.global_position if player != null else global_position
	var raios := [18.0, 24.0, 20.0, 26.0]
	var space := _obter_espaco_3d()
	var excl := _obter_excecoes_raycast(player)
	var candidatas_totais: Array[Vector3] = []
	for i in range(4):
		var ang := float(i) * (TAU / 4.0) + 0.4
		var r: float = raios[i]
		var pt := Vector3(centro.x + cos(ang) * r, global_position.y, centro.z + sin(ang) * r)
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(pt.x, centro.y + 8.0, pt.z),
				Vector3(pt.x, centro.y - 16.0, pt.z),
				mascara_colisao_ambiente,
				excl
			)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				pt.y = (hit["position"] as Vector3).y
		candidatas_totais.append(pt)
		if _posicao_livre_colisao(pt):
			_waypoints_procedurais.append(pt)
	if _waypoints_procedurais.is_empty():
		_waypoints_procedurais = candidatas_totais
	return _waypoints_procedurais


func obter_waypoints() -> Array[Vector3]:
	var lista: Array[Vector3] = []
	for p in pontos_patrulha:
		if p != null and is_instance_valid(p):
			lista.append(p.global_position)
	if not lista.is_empty():
		return lista

	if not _waypoints_path3d.is_empty():
		return _waypoints_path3d.duplicate()

	if is_inside_tree() and get_world_3d() != null:
		return _gerar_waypoints_procedurais()

	return posicoes_patrulha_fallback.duplicate()


func obter_waypoint_atual() -> Vector3:
	var lista := obter_waypoints()
	if lista.is_empty():
		return global_position
	var idx := posmod(indice_patrulha_atual, lista.size())
	return lista[idx]


func avancar_waypoint_patrulha() -> void:
	var lista := obter_waypoints()
	if lista.is_empty():
		return
	indice_patrulha_atual = (indice_patrulha_atual + 1) % lista.size()
	_tempo_sem_progresso_alvo = 0.0
	_menor_dist_alvo_mov = INF


func _distancia_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


func _esta_no_alcance_captura(player: Player) -> bool:
	if player == null:
		return false
	var diff := player.global_position - global_position
	var dist_3d := diff.length()
	var dist_xz := Vector2(diff.x, diff.z).length()
	if not (dist_3d <= distancia_captura or (dist_xz <= distancia_captura and absf(diff.y) <= 3.5)):
		return false
	return tem_linha_de_visao(player)


func realizar_captura(player: Player) -> void:
	jogador_capturado.emit(self, player)
	var cfg := _obter_config_efetiva()
	if cfg.modo_presenca_rondante == CriaturaConfig.ModoPresencaRondante.PRESSAO_DINAMICA:
		_iniciar_retirada()
	else:
		var lista := obter_waypoints()
		if not lista.is_empty() and player != null:
			var mais_distante := lista[0]
			var maior_d := -1.0
			for pt in lista:
				var d := pt.distance_to(player.global_position)
				if d > maior_d:
					maior_d = d
					mais_distante = pt
			global_position = Vector3(mais_distante.x, global_position.y, mais_distante.z)
		mudar_estado(Estado.PATRULHA)
	if GameManager.instance != null and GameManager.instance.has_method("registrar_captura_monstro"):
		GameManager.instance.registrar_captura_monstro(self, player)
