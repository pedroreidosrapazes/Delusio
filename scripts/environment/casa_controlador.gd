class_name CasaControlador
extends Node3D

## Controlador dinâmico da Casa.
## Sincroniza automaticamente as portas com suas respectivas animações no AnimationPlayer,
## tornando-as interativas com o RayCast3D do Player, inicializa o rádio 3D e gerencia a iluminação interna.

@export var animation_player: AnimationPlayer

const APLICADOR_ESTILO_PB := preload("res://scripts/visual/estilo_pb/aplicador_estilo_pb.gd")
const PARAMETROS_ESTILO_CAMA := {
	"usar_extracao_automatica": true,
	"intensidade_rim": 1.0,
	"largura_rim": 0.12,
	"espessura_contorno": 0.05,
	"velocidade_faixa": 0.45,
	"intensidade_faixa": 2.5,
}

var _aplicador_estilo_pb: RefCounted = APLICADOR_ESTILO_PB.new()
var _no_cama_estilizado: Node3D
var _ambiente_glow: Environment
var _glow_estava_ativo := false
var _ativou_glow_para_cama := false

var _luzes_internas: Array[OmniLight3D] = []
var _energia_base_luzes: float = 0.25
var _horario_atual: int = 0
var _tempo_flicker: float = 0.0


func _ready() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player == null:
			for filho in get_children():
				if filho is AnimationPlayer:
					animation_player = filho
					break

	_sincronizar_portas()
	_sincronizar_radio()
	_sincronizar_cama()
	_criar_luzes_internas()
	_conectar_progresso_tarefas()


func _exit_tree() -> void:
	_restaurar_estilo_cama()
	_restaurar_glow_cama()


func _process(delta: float) -> void:
	if _horario_atual >= 1 and not _luzes_internas.is_empty():
		_tempo_flicker += delta * 7.5
		# Candle flicker sutil senoidal
		for i in range(_luzes_internas.size()):
			var luz := _luzes_internas[i]
			if luz != null and is_instance_valid(luz):
				var oscilacao := sin(_tempo_flicker + float(i) * 2.1) * 0.05 + sin(_tempo_flicker * 2.3 + float(i) * 1.7) * 0.03
				luz.light_energy = clampf(_energia_base_luzes * (1.0 + oscilacao), 0.05, 3.0)
	elif _horario_atual == 0:
		for luz in _luzes_internas:
			if luz != null and is_instance_valid(luz) and luz.light_energy != _energia_base_luzes:
				luz.light_energy = _energia_base_luzes


func obter_luzes_internas() -> Array[OmniLight3D]:
	return _luzes_internas


func obter_energia_base_luzes() -> float:
	return _energia_base_luzes


func atualizar_iluminacao_horario(estado: int) -> void:
	_horario_atual = estado
	match estado:
		0: # DIA
			_energia_base_luzes = 0.25
		1: # TARDE
			_energia_base_luzes = 0.85
		2: # NOITE
			_energia_base_luzes = 1.45
		_:
			_energia_base_luzes = 0.25

	for luz in _luzes_internas:
		if luz != null and is_instance_valid(luz):
			luz.light_energy = _energia_base_luzes


func _criar_luzes_internas() -> void:
	if not _luzes_internas.is_empty():
		return

	var cor_quente := Color("#ffb347")

	# Luz 1: Quarto (perto da cama)
	var luz_quarto := OmniLight3D.new()
	luz_quarto.name = "LuzInterna_Quarto"
	luz_quarto.light_color = cor_quente
	luz_quarto.omni_range = 6.0
	luz_quarto.omni_attenuation = 1.35
	luz_quarto.light_energy = _energia_base_luzes
	var no_cama := find_child("cama", true, false) as Node3D
	if no_cama:
		no_cama.add_child(luz_quarto)
		luz_quarto.position = Vector3(0.0, 1.2, 0.0)
	else:
		add_child(luz_quarto)
		luz_quarto.position = Vector3(2.5, 1.8, 2.0)
	_luzes_internas.append(luz_quarto)

	# Luz 2: Sala (perto do rádio)
	var luz_sala := OmniLight3D.new()
	luz_sala.name = "LuzInterna_Sala"
	luz_sala.light_color = cor_quente
	luz_sala.omni_range = 6.0
	luz_sala.omni_attenuation = 1.35
	luz_sala.light_energy = _energia_base_luzes
	var no_radio := find_child("radio", true, false) as Node3D
	if no_radio:
		no_radio.add_child(luz_sala)
		luz_sala.position = Vector3(0.0, 1.0, 0.0)
	else:
		add_child(luz_sala)
		luz_sala.position = Vector3(-1.5, 1.8, 1.0)
	_luzes_internas.append(luz_sala)

	# Luz 3: Cozinha / Área interna
	var luz_cozinha := OmniLight3D.new()
	luz_cozinha.name = "LuzInterna_Cozinha"
	luz_cozinha.light_color = cor_quente
	luz_cozinha.omni_range = 6.0
	luz_cozinha.omni_attenuation = 1.35
	luz_cozinha.light_energy = _energia_base_luzes
	add_child(luz_cozinha)
	luz_cozinha.position = Vector3(-0.5, 1.8, -2.5)
	_luzes_internas.append(luz_cozinha)


func _sincronizar_portas() -> void:
	if animation_player == null:
		push_warning("CasaControlador: AnimationPlayer não encontrado no elemento Casa.")
		return

	# Mapa com as portas e suas respectivas animações no AnimationPlayer
	var configs_portas: Dictionary = {
		"portaEntrada": {
			"abrir": "AbrirPortaEntrada",
			"fechar": "" # Vazio toca reverso
		},
		"portaEntrada_001": {
			"abrir": "abrirPortaBanheiro",
			"fechar": "" # Vazio toca reverso
		},
		"portaQuarto": {
			"abrir": "abrirPortaQuarto",
			"fechar": "fecharPortaQuarto"
		}
	}

	for nome_porta in configs_portas.keys():
		var no_porta: Node3D = find_child(nome_porta, true, false) as Node3D
		if no_porta == null:
			continue

		# Localiza o StaticBody3D de colisão (onde o raycast do jogador colide)
		var corpo_colisao: StaticBody3D = null
		for filho in no_porta.get_children():
			if filho is StaticBody3D:
				corpo_colisao = filho
				break

		if corpo_colisao == null:
			continue

		var config: Dictionary = configs_portas[nome_porta]
		var script_porta: Script = load("res://scripts/interactables/porta_entrada.gd")

		# Se o StaticBody3D ainda não tem o script de PortaEntrada, aplica dinamicamente
		if corpo_colisao.get_script() != script_porta:
			corpo_colisao.set_script(script_porta)

		# Configura as propriedades de animação
		corpo_colisao.set("animation_player", animation_player)
		corpo_colisao.set("animacao_abrir", config["abrir"])
		corpo_colisao.set("animacao_fechar", config["fechar"])
		corpo_colisao.set("prompt_interacao", "Abrir Porta")


func _sincronizar_radio() -> void:
	var no_radio: Node3D = find_child("radio", true, false) as Node3D
	if no_radio == null:
		return

	var corpo_radio: StaticBody3D = null
	for filho in no_radio.get_children():
		if filho is StaticBody3D:
			corpo_radio = filho
			break

	if corpo_radio == null:
		return

	var script_radio: Script = load("res://scripts/interactables/radio.gd")
	if corpo_radio.get_script() != script_radio:
		corpo_radio.set_script(script_radio)

	# Carrega áudio da transmissão diária se disponível
	var stream_noticia := load("res://assets/audio/radio_noticia_dia1.mp3") as AudioStream
	if stream_noticia != null:
		corpo_radio.set("audios_dias", [stream_noticia])

	# Vincula ao GameManager caso esteja vazio
	if GameManager.instance != null and GameManager.instance.radio == null:
		GameManager.instance.radio = corpo_radio


func _sincronizar_cama() -> void:
	var no_cama: Node3D = find_child("cama", true, false) as Node3D
	if no_cama == null:
		return
	_no_cama_estilizado = no_cama

	var corpo_cama: StaticBody3D = null
	for filho in no_cama.get_children():
		if filho is StaticBody3D:
			corpo_cama = filho
			break

	if corpo_cama == null:
		return

	var script_cama: Script = load("res://scripts/interactables/cama.gd")
	if corpo_cama.get_script() != script_cama:
		corpo_cama.set_script(script_cama)

	corpo_cama.set("prompt_interacao", "Dormir")
	corpo_cama.set("interacao_ativa", true)


func _conectar_progresso_tarefas() -> void:
	var gerente := GameManager.instance
	if gerente == null:
		return
	if not gerente.tarefas_atualizadas.is_connected(_ao_atualizar_tarefas):
		gerente.tarefas_atualizadas.connect(_ao_atualizar_tarefas)
	if not gerente.horario_alterado.is_connected(atualizar_iluminacao_horario):
		gerente.horario_alterado.connect(atualizar_iluminacao_horario)
	_ao_atualizar_tarefas(gerente.tarefas_concluidas, gerente.tarefas_totais, "")
	atualizar_iluminacao_horario(gerente.horario_atual)


func _ao_atualizar_tarefas(concluidas: int, totais: int, _mensagem: String) -> void:
	if _no_cama_estilizado == null:
		return
	if totais > 0 and concluidas >= totais:
		_aplicar_estilo_cama()
	else:
		_restaurar_estilo_cama()
		_restaurar_glow_cama()


func _aplicar_estilo_cama() -> void:
	if _no_cama_estilizado == null:
		return
	if _aplicador_estilo_pb.aplicar_arvore(_no_cama_estilizado, PARAMETROS_ESTILO_CAMA):
		_ativar_glow_cama()


func _restaurar_estilo_cama() -> void:
	if _no_cama_estilizado != null and is_instance_valid(_no_cama_estilizado):
		_aplicador_estilo_pb.restaurar_arvore(_no_cama_estilizado)


func _ativar_glow_cama() -> void:
	if _ativou_glow_para_cama:
		return
	var gerente := GameManager.instance
	if gerente == null or gerente.environment_noite == null or gerente.environment_noite.environment == null:
		return
	_ambiente_glow = gerente.environment_noite.environment
	_glow_estava_ativo = _ambiente_glow.glow_enabled
	if not _glow_estava_ativo:
		_ambiente_glow.glow_enabled = true
		_ativou_glow_para_cama = true


func _restaurar_glow_cama() -> void:
	if not _ativou_glow_para_cama:
		return
	if is_instance_valid(_ambiente_glow) and _ambiente_glow.glow_enabled:
		_ambiente_glow.glow_enabled = _glow_estava_ativo
	_ambiente_glow = null
	_ativou_glow_para_cama = false
