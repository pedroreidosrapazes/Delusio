class_name DiretorEventosNoite
extends Node

## Diretor de Eventos Noturnos.
## Coordena eventos ambientais e de jogabilidade pela fazenda exclusivamente à noite,
## mantendo tensão dinâmica com cooldown controlado e coordenação justa entre os 2 monstros.

signal evento_disparado(tipo: StringName, dados: Dictionary)
signal estatica_radio_disparada(zona: String, origem: Vector3)
signal queda_fusivel_iniciada(duracao: float)
signal queda_fusivel_encerrada()
signal som_ambiental_disparado(nome_marcador: String, posicao: Vector3)

@export_category("Temporização e Cooldowns")
@export var intervalo_min_eventos: float = 10.0
@export var duracao_queda_fusivel: float = 6.0
@export var duracao_alivio_pos_susto: float = 6.0
@export var distancia_minima_entre_monstros_spawn: float = 14.0

@export_category("Zonas de Referência")
@export var posicoes_zonas_referencia: Dictionary = {
	"celeiro": Vector3(8.0, 0.5, 28.0),
	"horta": Vector3(0.0, 1.2, 25.9)
}

var ativo: bool = false
var nivel_tensao: float = 0.32
var tempo_desde_ultimo_evento: float = 0.0
var cooldown_restante: float = 0.0
var evento_em_andamento: bool = false
var queda_fusivel_ativa: bool = false
var tempo_queda_restante: float = 0.0
var janela_alivio_restante: float = 0.0

var marcadores_som: Dictionary = {}
var historico_eventos: Array[StringName] = []

var _vigilia_estava_ativa_antes_queda: bool = false
var _indice_rotacao_evento: int = 0


func _ready() -> void:
	set_process(false)


func ativar() -> void:
	var gerente := GameManager.instance
	if gerente != null and gerente.horario_atual != 2:
		return

	ativo = true
	tempo_desde_ultimo_evento = 0.0
	cooldown_restante = intervalo_min_eventos * 0.6
	evento_em_andamento = false
	queda_fusivel_ativa = false
	tempo_queda_restante = 0.0
	_vigilia_estava_ativa_antes_queda = false
	_garantir_marcadores_som()
	coordenar_spawn_inicial_monstros()
	set_process(true)


func desativar() -> void:
	if queda_fusivel_ativa:
		encerrar_queda_fusivel()
	ativo = false
	evento_em_andamento = false
	cooldown_restante = 0.0
	tempo_desde_ultimo_evento = 0.0
	janela_alivio_restante = 0.0
	set_process(false)


func _process(delta: float) -> void:
	processar_diretor(delta)


func processar_diretor(delta: float) -> void:
	if not ativo:
		return

	var gerente := GameManager.instance
	if gerente != null and gerente.horario_atual != 2:
		desativar()
		return

	_atualizar_nivel_tensao()
	tempo_desde_ultimo_evento += delta
	cooldown_restante = maxf(0.0, cooldown_restante - delta)
	janela_alivio_restante = maxf(0.0, janela_alivio_restante - delta)

	if queda_fusivel_ativa:
		tempo_queda_restante -= delta
		if tempo_queda_restante <= 0.0:
			encerrar_queda_fusivel()

	coordenar_monstros(delta)

	if not evento_em_andamento and cooldown_restante <= 0.0 and janela_alivio_restante <= 0.0:
		var limiar := maxf(intervalo_min_eventos, lerpf(20.0, intervalo_min_eventos, clampf(nivel_tensao, 0.0, 1.0)))
		if tempo_desde_ultimo_evento >= limiar:
			disparar_proximo_evento()


func pode_disparar_evento(forcar: bool = false) -> bool:
	if not ativo:
		return false
	if not forcar and (evento_em_andamento or cooldown_restante > 0.0):
		return false
	return true


func disparar_proximo_evento() -> Dictionary:
	if not pode_disparar_evento():
		return {}

	var gerente := GameManager.instance
	var opcoes: Array[String] = ["estatica_radio", "som_localizado"]
	if gerente != null and gerente.modo_noturno == GameManager.ModoNoturno.VIGILIA_DOMESTICA:
		opcoes.append("queda_fusivel")

	var escolha := opcoes[_indice_rotacao_evento % opcoes.size()]
	_indice_rotacao_evento += 1

	match escolha:
		"estatica_radio":
			return disparar_estatica_radio()
		"queda_fusivel":
			return disparar_queda_fusivel()
		_:
			return disparar_som_localizado()


func disparar_estatica_radio(zona_preferida: String = "", forcar: bool = false) -> Dictionary:
	if not pode_disparar_evento(forcar):
		return {}

	var zona := zona_preferida
	if zona.is_empty():
		zona = _detectar_zona_atividade()

	var origem: Vector3 = posicoes_zonas_referencia.get(zona, Vector3.ZERO)
	var radio := _obter_radio()
	if radio != null and radio.has_method("tocar_estatica_direcional"):
		radio.tocar_estatica_direcional(zona)

	var gerente := GameManager.instance
	if gerente != null:
		gerente.status_temporario.emit("Estática no rádio... algo se move perto do %s." % zona)

	_registrar_disparo(&"estatica_radio", {"zona": zona, "origem": origem})
	estatica_radio_disparada.emit(zona, origem)
	return {"tipo": &"estatica_radio", "zona": zona, "origem": origem}


func disparar_queda_fusivel(duracao: float = -1.0, forcar: bool = false) -> Dictionary:
	if not pode_disparar_evento(forcar):
		return {}

	var d := duracao if duracao > 0.0 else duracao_queda_fusivel
	queda_fusivel_ativa = true
	evento_em_andamento = true
	tempo_queda_restante = d

	var gerente := GameManager.instance
	if gerente != null:
		_vigilia_estava_ativa_antes_queda = gerente.pontos_vigilia_ativos
		if gerente.pontos_vigilia_ativos:
			gerente.pontos_vigilia_ativos = false
		gerente.status_temporario.emit("Queda de fusível! As luzes da casa falharam temporariamente!")

	var casa := _obter_casa_controlador()
	if casa != null and casa.has_method("definir_queda_energia"):
		casa.definir_queda_energia(true)

	var filtro := _obter_filtro_delusio()
	if filtro != null and filtro.has_method("registrar_impulso_tensao"):
		filtro.registrar_impulso_tensao(0.24)

	_registrar_disparo(&"queda_fusivel", {"duracao": d})
	queda_fusivel_iniciada.emit(d)
	return {"tipo": &"queda_fusivel", "duracao": d}


func encerrar_queda_fusivel() -> void:
	if not queda_fusivel_ativa:
		return

	queda_fusivel_ativa = false
	tempo_queda_restante = 0.0
	evento_em_andamento = false

	var gerente := GameManager.instance
	if gerente != null and _vigilia_estava_ativa_antes_queda:
		gerente.pontos_vigilia_ativos = true
	_vigilia_estava_ativa_antes_queda = false

	var casa := _obter_casa_controlador()
	if casa != null and casa.has_method("definir_queda_energia"):
		casa.definir_queda_energia(false)

	queda_fusivel_encerrada.emit()


func disparar_som_localizado(nome_marcador: String = "", forcar: bool = false) -> Dictionary:
	if not pode_disparar_evento(forcar):
		return {}

	_garantir_marcadores_som()
	var nomes_disponiveis: Array[String] = ["PortaJanelaCasa", "MadeiraCeleiro", "GalhosAtrasJogador"]
	var nome_escolhido := nome_marcador
	if nome_escolhido.is_empty() or not marcadores_som.has(nome_escolhido):
		nome_escolhido = nomes_disponiveis[randi() % nomes_disponiveis.size()]

	var marcador := marcadores_som.get(nome_escolhido, null) as Marker3D
	var pos := Vector3.ZERO
	if marcador != null and is_instance_valid(marcador):
		if nome_escolhido == "GalhosAtrasJogador":
			var player := _obter_player()
			if player != null and player.camera != null:
				var frente := -player.camera.global_transform.basis.z
				var frente_xz := Vector3(frente.x, 0.0, frente.z)
				if frente_xz.length_squared() < 0.001:
					frente_xz = Vector3(0.0, 0.0, -1.0)
				else:
					frente_xz = frente_xz.normalized()
				marcador.global_position = player.global_position - frente_xz * 6.0 + Vector3(0.0, 0.5, 0.0)
		pos = marcador.global_position

		var player_3d := marcador.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
		if player_3d != null and player_3d.stream != null:
			player_3d.play()

	var filtro := _obter_filtro_delusio()
	if filtro != null and filtro.has_method("registrar_impulso_tensao"):
		filtro.registrar_impulso_tensao(0.18)

	# Estímulo ambiental na IA apenas para pontos fixos da fazenda quando o Rondante está em patrulha
	if nome_escolhido != "GalhosAtrasJogador":
		var rondante := _obter_rondante()
		if rondante != null and rondante.ativa and rondante.estado_atual == RondanteFazenda.Estado.PATRULHA:
			rondante.receber_estimulo_sonoro(pos, 14.0)

	_registrar_disparo(&"som_localizado", {"marcador": nome_escolhido, "posicao": pos})
	som_ambiental_disparado.emit(nome_escolhido, pos)
	return {"tipo": &"som_localizado", "marcador": nome_escolhido, "posicao": pos}


func registrar_alivio_pos_susto(duracao: float = -1.0) -> void:
	janela_alivio_restante = duracao if duracao > 0.0 else duracao_alivio_pos_susto


func coordenar_spawn_inicial_monstros() -> void:
	var player := _obter_player()
	var silhueta := _obter_silhueta()
	var rondante := _obter_rondante()

	if rondante != null and player != null:
		if rondante.global_position.distance_to(player.global_position) < distancia_minima_entre_monstros_spawn:
			var waypoints := rondante.obter_waypoints()
			if not waypoints.is_empty():
				var melhor := waypoints[0]
				var max_d := -1.0
				for wp in waypoints:
					var d := wp.distance_to(player.global_position)
					if d > max_d:
						max_d = d
						melhor = wp
				rondante.global_position = Vector3(melhor.x, rondante.global_position.y, melhor.z)

	if silhueta != null and player != null:
		var em_intro_passiva := ("estado_atual" in silhueta) and int(silhueta.estado_atual) == Silhueta.Estado.INTRODUCAO_ESPREITA
		if not em_intro_passiva:
			var perto_player := silhueta.global_position.distance_to(player.global_position) < distancia_minima_entre_monstros_spawn
			var perto_rondante := rondante != null and silhueta.global_position.distance_to(rondante.global_position) < distancia_minima_entre_monstros_spawn
			if (perto_player or perto_rondante) and silhueta.has_method("mover_para_novo_local"):
				silhueta.mover_para_novo_local()


func coordenar_monstros(_delta: float) -> void:
	var player := _obter_player()
	var silhueta := _obter_silhueta()
	var rondante := _obter_rondante()

	if janela_alivio_restante > 0.0:
		if silhueta != null and ("ativa" in silhueta) and silhueta.ativa:
			if ("em_investida" in silhueta) and silhueta.em_investida:
				if silhueta.has_method("parar_investida"):
					silhueta.parar_investida()
				if silhueta.has_method("recuar_anel"):
					silhueta.recuar_anel()
				if silhueta.has_method("mover_para_novo_local"):
					silhueta.mover_para_novo_local()
		if rondante != null and rondante.ativa and rondante.estado_atual == RondanteFazenda.Estado.CACADA:
			rondante.mudar_estado(RondanteFazenda.Estado.PATRULHA)
		return

	if rondante != null and rondante.ativa and silhueta != null and ("ativa" in silhueta) and silhueta.ativa and player != null:
		var rondante_cacando_perto := (
			rondante.estado_atual == RondanteFazenda.Estado.CACADA
			and rondante.global_position.distance_to(player.global_position) <= 10.0
		)
		if rondante_cacando_perto:
			if ("em_investida" in silhueta) and silhueta.em_investida:
				silhueta.parar_investida()
				silhueta.recuar_anel()
				silhueta.mover_para_novo_local()
			elif ("anel_atual" in silhueta) and silhueta.anel_atual <= 1 and silhueta.global_position.distance_to(player.global_position) <= 8.0:
				silhueta.recuar_anel()
				silhueta.mover_para_novo_local()


func _registrar_disparo(tipo: StringName, dados: Dictionary) -> void:
	tempo_desde_ultimo_evento = 0.0
	cooldown_restante = intervalo_min_eventos
	historico_eventos.append(tipo)
	evento_disparado.emit(tipo, dados)


func _atualizar_nivel_tensao() -> void:
	var filtro := _obter_filtro_delusio()
	if filtro != null and ("nivel_tensao_atual" in filtro):
		nivel_tensao = float(filtro.nivel_tensao_atual)
		return

	var base := 0.32
	var player := _obter_player()
	var rondante := _obter_rondante()
	if player != null and rondante != null and rondante.ativa:
		var dist := player.global_position.distance_to(rondante.global_position)
		if dist < 24.0:
			base += (1.0 - clampf(dist / 24.0, 0.0, 1.0)) * 0.35
	nivel_tensao = clampf(base, 0.0, 1.0)


func _detectar_zona_atividade() -> String:
	var rondante := _obter_rondante()
	var alvo_pos := Vector3.ZERO
	var tem_alvo := false
	if rondante != null and rondante.ativa:
		alvo_pos = rondante.global_position
		tem_alvo = true
	else:
		var sil := _obter_silhueta()
		if sil != null and ("ativa" in sil) and sil.ativa:
			alvo_pos = sil.global_position
			tem_alvo = true

	if not tem_alvo:
		return "celeiro"

	var pos_celeiro: Vector3 = posicoes_zonas_referencia.get("celeiro", Vector3(8.0, 0.5, 28.0))
	var pos_horta: Vector3 = posicoes_zonas_referencia.get("horta", Vector3(0.0, 1.2, 25.9))
	if alvo_pos.distance_to(pos_celeiro) <= alvo_pos.distance_to(pos_horta):
		return "celeiro"
	return "horta"


func _garantir_marcadores_som() -> void:
	var specs := {
		"PortaJanelaCasa": Vector3(-17.0, 1.5, 33.2),
		"MadeiraCeleiro": Vector3(8.5, 2.0, 28.0),
		"GalhosAtrasJogador": Vector3(0.0, 1.0, 30.0)
	}

	if get_tree() != null:
		for node in get_tree().get_nodes_in_group("marcadores_som_noite"):
			if node is Marker3D and specs.has(node.name):
				marcadores_som[node.name] = node

	var pai_alvo: Node = self
	if GameManager.instance != null and GameManager.instance.get_parent() != null:
		pai_alvo = GameManager.instance.get_parent()
	elif get_parent() != null:
		pai_alvo = get_parent()

	for nome_m in specs.keys():
		var m := marcadores_som.get(nome_m, null) as Marker3D
		if m == null or not is_instance_valid(m):
			m = pai_alvo.get_node_or_null(nome_m) as Marker3D
		if m == null:
			m = Marker3D.new()
			m.name = nome_m
			m.position = specs[nome_m]
			m.add_to_group("marcadores_som_noite")
			var audio := AudioStreamPlayer3D.new()
			audio.name = "AudioStreamPlayer3D"
			audio.max_distance = 30.0
			m.add_child(audio)
			pai_alvo.add_child(m)
		else:
			if not m.is_in_group("marcadores_som_noite"):
				m.add_to_group("marcadores_som_noite")
			if m.get_node_or_null("AudioStreamPlayer3D") == null:
				var audio := AudioStreamPlayer3D.new()
				audio.name = "AudioStreamPlayer3D"
				audio.max_distance = 30.0
				m.add_child(audio)
		marcadores_som[nome_m] = m


func _obter_player() -> Player:
	if get_tree() != null:
		return get_tree().get_first_node_in_group("player") as Player
	return null


func _obter_silhueta() -> Node3D:
	if GameManager.instance != null and GameManager.instance.silhueta != null and is_instance_valid(GameManager.instance.silhueta):
		return GameManager.instance.silhueta
	return null


func _obter_rondante() -> RondanteFazenda:
	if GameManager.instance != null and ("rondante" in GameManager.instance) and GameManager.instance.rondante is RondanteFazenda:
		return GameManager.instance.rondante as RondanteFazenda
	if get_tree() != null:
		for m in get_tree().get_nodes_in_group("monstros_noturnos"):
			if m is RondanteFazenda:
				return m as RondanteFazenda
	return null


func _obter_radio() -> Node:
	if GameManager.instance != null and GameManager.instance.radio != null and is_instance_valid(GameManager.instance.radio):
		return GameManager.instance.radio
	if get_tree() != null:
		return get_tree().get_first_node_in_group("radio")
	return null


func _obter_casa_controlador() -> Node:
	if get_tree() == null:
		return null
	var raiz := get_tree().current_scene
	if raiz == null and GameManager.instance != null:
		raiz = GameManager.instance.get_parent()
	if raiz == null:
		return null
	for n in raiz.find_children("*", "Node", true, false):
		if n.has_method("definir_queda_energia"):
			return n
	return null


func _obter_filtro_delusio() -> Node:
	if get_tree() == null:
		return null
	var raiz := get_tree().current_scene
	if raiz == null and GameManager.instance != null:
		raiz = GameManager.instance.get_parent()
	if raiz == null:
		return null
	for n in raiz.find_children("*", "Node", true, false):
		if n is FiltroDelusioControlador:
			return n
	return null
