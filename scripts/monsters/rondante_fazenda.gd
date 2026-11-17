class_name RondanteFazenda
extends MonstroNoturnoBase

## 2º Monstro Noturno — O Rondante da Fazenda.
## Contraponto tático da Silhueta: pune barulho e movimento descuidado,
## patrulha as zonas da fazenda e hesita brevemente sob foco direto da lanterna.

enum Estado { INATIVO, PATRULHA, INVESTIGANDO, CACADA, ATORDOADO_LUZ }

signal estado_alterado(novo_estado: int, estado_anterior: int)
signal som_investigado(posicao: Vector3)
signal atordoado_por_luz(duracao: float)

@export_category("Patrulha e Navegação")
@export var pontos_patrulha: Array[Node3D] = []
@export var posicoes_patrulha_fallback: Array[Vector3] = [
	Vector3(-12.0, 0.5, 22.0),
	Vector3(0.0, 0.5, 26.0),
	Vector3(8.0, 0.5, 28.0),
	Vector3(-6.0, 0.5, 34.0),
	Vector3(-18.0, 0.5, 40.0)
]

@export_category("Temporizadores da IA")
@export var duracao_investigacao: float = 4.0
@export var tempo_foco_para_atordoar: float = 0.4
@export var duracao_atordoamento_luz: float = 2.5
@export var cooldown_atordoamento_max: float = 5.0

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

var visual_placeholder: MeshInstance3D = null
var nav_agent: NavigationAgent3D = null


func _ready() -> void:
	super._ready()
	if config == null:
		config = CriaturaConfig.criar_padrao_rondante()
	_garantir_estrutura_nos()
	_coletar_pontos_patrulha_grupo()
	desativar()


func _garantir_estrutura_nos() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		nav_agent.path_desired_distance = 0.8
		nav_agent.target_desired_distance = 1.0
		add_child(nav_agent)

	visual_placeholder = get_node_or_null("VisualPlaceholder") as MeshInstance3D
	if visual_placeholder == null:
		visual_placeholder = _criar_visual_placeholder()
		add_child(visual_placeholder)


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


func _coletar_pontos_patrulha_grupo() -> void:
	if not pontos_patrulha.is_empty() or get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("pontos_patrulha"):
		if node is Node3D:
			pontos_patrulha.append(node as Node3D)


func _obter_config_efetiva() -> CriaturaConfig:
	if config == null:
		config = CriaturaConfig.criar_padrao_rondante()
	return config


func mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return
	var anterior := estado_atual
	estado_atual = novo_estado
	if novo_estado == Estado.PATRULHA or novo_estado == Estado.INATIVO:
		viu_jogador_entrar_esconderijo = false
	estado_alterado.emit(int(novo_estado), int(anterior))


func ativar() -> void:
	_obter_config_efetiva()
	_garantir_estrutura_nos()
	_coletar_pontos_patrulha_grupo()
	super.ativar()
	set_physics_process(true)
	tempo_foco_lanterna_acumulado = 0.0
	tempo_atordoado_restante = 0.0
	cooldown_atordoamento_restante = 0.0
	viu_jogador_entrar_esconderijo = false
	mudar_estado(Estado.PATRULHA)


func desativar() -> void:
	super.desativar()
	set_physics_process(false)
	tempo_foco_lanterna_acumulado = 0.0
	tempo_atordoado_restante = 0.0
	tempo_investigacao_restante = 0.0
	tempo_tolerancia_esconderijo_restante = 0.0
	viu_jogador_entrar_esconderijo = false
	mudar_estado(Estado.INATIVO)


func receber_estimulo_sonoro(pos: Vector3, raio: float) -> void:
	super.receber_estimulo_sonoro(pos, raio)
	if not ativa or estado_atual == Estado.INATIVO or estado_atual == Estado.ATORDOADO_LUZ:
		return

	var cfg := _obter_config_efetiva()
	var alcance_efetivo := maxf(raio, cfg.raio_audicao_passos)
	if global_position.distance_to(pos) > alcance_efetivo:
		return

	ultima_posicao_som = pos
	tempo_investigacao_restante = duracao_investigacao

	var player := _obter_player()
	if player != null and player.esta_escondido():
		if global_position.distance_to(pos) <= 8.0:
			viu_jogador_entrar_esconderijo = true
			if estado_atual != Estado.CACADA:
				ultima_posicao_vista_jogador = pos
				tempo_tolerancia_esconderijo_restante = cfg.tempo_tolerancia_esconderijo
				mudar_estado(Estado.CACADA)
			som_investigado.emit(pos)
			return

	if estado_atual == Estado.PATRULHA or estado_atual == Estado.INVESTIGANDO:
		mudar_estado(Estado.INVESTIGANDO)
		som_investigado.emit(pos)


func receber_foco_lanterna(delta: float) -> void:
	super.receber_foco_lanterna(delta)
	if not ativa:
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
		atordoado_por_luz.emit(duracao_atordoamento_luz)

		# Dilema tático: usar a lanterna contra o Rondante atrai a Silhueta
		var gerente := GameManager.instance
		if gerente != null and gerente.silhueta != null and is_instance_valid(gerente.silhueta):
			var sil := gerente.silhueta
			if ("ativa" in sil) and sil.ativa and sil.has_method("avancar_anel"):
				sil.avancar_anel()


func notificar_jogador_entrou_esconderijo(player: Player) -> void:
	if not ativa or player == null:
		return
	if estado_atual == Estado.CACADA and pode_ver_jogador_sem_esconderijo(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= 4.5:
			viu_jogador_entrar_esconderijo = true


func pode_ver_jogador_sem_esconderijo(player: Player) -> bool:
	if player == null or not ativa:
		return false
	var cfg := _obter_config_efetiva()
	var alcance := cfg.raio_visao * (1.25 if player.esta_com_lanterna_acesa() else 1.0)
	var diff := player.global_position - global_position
	var dist_xz := Vector2(diff.x, diff.z).length()
	if dist_xz > alcance or absf(diff.y) > 8.0:
		return false
	if dist_xz <= 2.2:
		return true

	var frente := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	if frente.length_squared() < 0.0001:
		frente = Vector3(0.0, 0.0, -1.0)
	else:
		frente = frente.normalized()

	var dir_p := Vector3(diff.x, 0.0, diff.z).normalized()
	var angulo := rad_to_deg(frente.angle_to(dir_p))
	return angulo <= cfg.angulo_visao_graus * 0.5


func pode_ver_jogador(player: Player) -> bool:
	if player == null or not ativa:
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

	var cfg := _obter_config_efetiva()
	cooldown_atordoamento_restante = maxf(0.0, cooldown_atordoamento_restante - delta)

	var player := _obter_player()
	_processar_foco_lanterna_jogador(player, delta)

	match estado_atual:
		Estado.PATRULHA:
			if pode_ver_jogador(player):
				ultima_posicao_vista_jogador = player.global_position
				tempo_tolerancia_esconderijo_restante = cfg.tempo_tolerancia_esconderijo
				mudar_estado(Estado.CACADA)
				return

			var alvo_patrulha := obter_waypoint_atual()
			_mover_para(alvo_patrulha, cfg.velocidade_patrulha, delta)
			if _distancia_xz(global_position, alvo_patrulha) <= 1.0:
				avancar_waypoint_patrulha()

		Estado.INVESTIGANDO:
			if pode_ver_jogador(player):
				ultima_posicao_vista_jogador = player.global_position
				tempo_tolerancia_esconderijo_restante = cfg.tempo_tolerancia_esconderijo
				mudar_estado(Estado.CACADA)
				return

			var vel_investigar := (cfg.velocidade_patrulha + cfg.velocidade_perseguicao) * 0.5
			if _distancia_xz(global_position, ultima_posicao_som) > 1.2:
				_mover_para(ultima_posicao_som, vel_investigar, delta)
			else:
				tempo_investigacao_restante -= delta
				if tempo_investigacao_restante <= 0.0:
					mudar_estado(Estado.PATRULHA)

		Estado.CACADA:
			if pode_ver_jogador(player):
				ultima_posicao_vista_jogador = player.global_position
				tempo_tolerancia_esconderijo_restante = cfg.tempo_tolerancia_esconderijo
				if _esta_no_alcance_captura(player):
					realizar_captura(player)
					return
				_mover_para(player.global_position, cfg.velocidade_perseguicao, delta)
				if _esta_no_alcance_captura(player):
					realizar_captura(player)
			else:
				if _distancia_xz(global_position, ultima_posicao_vista_jogador) > 1.2:
					_mover_para(ultima_posicao_vista_jogador, cfg.velocidade_perseguicao * 0.8, delta)
				tempo_tolerancia_esconderijo_restante -= delta
				if tempo_tolerancia_esconderijo_restante <= 0.0:
					mudar_estado(Estado.PATRULHA)

		Estado.ATORDOADO_LUZ:
			# Hesita brevemente movendo-se muito devagar sob o feixe da lanterna
			if player != null:
				var dir_recuo := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z)
				if dir_recuo.length_squared() > 0.001:
					global_position += dir_recuo.normalized() * (cfg.velocidade_patrulha * 0.12) * delta

			tempo_atordoado_restante -= delta
			if tempo_atordoado_restante <= 0.0:
				if player != null:
					ultima_posicao_som = player.global_position
					tempo_investigacao_restante = duracao_investigacao * 0.75
					mudar_estado(Estado.INVESTIGANDO)
				else:
					mudar_estado(Estado.PATRULHA)


func _processar_foco_lanterna_jogador(player: Player, delta: float) -> void:
	if player == null or not player.esta_com_lanterna_acesa() or player.camera == null:
		tempo_foco_lanterna_acumulado = maxf(0.0, tempo_foco_lanterna_acumulado - delta * 0.5)
		return

	var cam := player.camera
	var alvo_cabeca := global_position + Vector3(0.0, 1.3, 0.0)
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


func _mover_para(destino: Vector3, velocidade: float, delta: float) -> void:
	var alvo_passo := destino
	if nav_agent != null and is_inside_tree():
		var nav_map := nav_agent.get_navigation_map()
		if nav_map.is_valid() and NavigationServer3D.map_get_regions(nav_map).size() > 0:
			nav_agent.target_position = destino
			var next_pos := nav_agent.get_next_path_position()
			if _distancia_xz(global_position, next_pos) > 0.05:
				alvo_passo = next_pos

	var delta_xz := Vector3(alvo_passo.x - global_position.x, 0.0, alvo_passo.z - global_position.z)
	var dist_xz := delta_xz.length()
	if dist_xz <= 0.001:
		return

	var passo_max := velocidade * delta
	var dir := delta_xz / dist_xz
	if passo_max >= dist_xz:
		global_position.x = alvo_passo.x
		global_position.z = alvo_passo.z
	else:
		global_position += dir * passo_max

	if is_inside_tree() and dist_xz > 0.05:
		var alvo_olhar := Vector3(global_position.x + dir.x, global_position.y, global_position.z + dir.z)
		if global_position.distance_squared_to(alvo_olhar) > 0.001:
			look_at(alvo_olhar, Vector3.UP)


func obter_waypoints() -> Array[Vector3]:
	var lista: Array[Vector3] = []
	for p in pontos_patrulha:
		if p != null and is_instance_valid(p):
			lista.append(p.global_position)
	if lista.is_empty():
		return posicoes_patrulha_fallback.duplicate()
	return lista


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


func _distancia_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


func _esta_no_alcance_captura(player: Player) -> bool:
	if player == null:
		return false
	var diff := player.global_position - global_position
	var dist_3d := diff.length()
	var dist_xz := Vector2(diff.x, diff.z).length()
	return dist_3d <= distancia_captura or (dist_xz <= distancia_captura and absf(diff.y) <= 3.5)


func realizar_captura(player: Player) -> void:
	jogador_capturado.emit(self, player)
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
