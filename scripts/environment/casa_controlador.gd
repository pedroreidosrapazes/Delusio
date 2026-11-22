class_name CasaControlador
extends Node3D

## Controlador dinâmico da Casa.
## Sincroniza automaticamente as portas com suas respectivas animações no AnimationPlayer,
## tornando-as interativas com o RayCast3D do Player, inicializa o rádio 3D e gerencia a iluminação interna.

signal jogador_zona_casa_alterada(dentro: bool)

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
var queda_energia_ativa: bool = false
var jogador_dentro_casa: bool = false
var _zona_interna: Area3D = null


func _ready() -> void:
	add_to_group("casa_controlador")
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player == null:
			for filho in get_children():
				if filho is AnimationPlayer:
					animation_player = filho
					break

	_criar_zona_interna_casa()
	_sincronizar_portas()
	_sincronizar_radio()
	_sincronizar_cama()
	_sincronizar_esconderijo_armario()
	_sincronizar_caixa_fusiveis()
	_criar_luzes_internas()
	_conectar_progresso_tarefas()


func _exit_tree() -> void:
	_restaurar_estilo_cama()
	_restaurar_glow_cama()


func _process(delta: float) -> void:
	if queda_energia_ativa:
		return
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

	if queda_energia_ativa:
		return

	for luz in _luzes_internas:
		if luz != null and is_instance_valid(luz):
			luz.light_energy = _energia_base_luzes


func definir_queda_energia(ativa_queda: bool) -> void:
	queda_energia_ativa = ativa_queda
	if queda_energia_ativa:
		for luz in _luzes_internas:
			if luz != null and is_instance_valid(luz):
				luz.light_energy = 0.08
	else:
		atualizar_iluminacao_horario(_horario_atual)


func _criar_luzes_internas() -> void:
	if not _luzes_internas.is_empty():
		return

	var specs: Array[Dictionary] = [
		{
			"name": "LuzInterna_Quarto",
			"pos": Vector3(2.1, 1.15, 1.5),
			"range": 4.6,
			"cor": Color("#ffbe6b")
		},
		{
			"name": "LuzInterna_Sala",
			"pos": Vector3(-1.6, 1.15, -0.9),
			"range": 5.0,
			"cor": Color("#ffbe6b")
		},
		{
			"name": "LuzInterna_Cozinha",
			"pos": Vector3(2.1, 1.15, -1.0),
			"range": 4.8,
			"cor": Color("#ffbe6b")
		},
		{
			"name": "LuzInterna_Banheiro",
			"pos": Vector3(-2.1, 1.15, 1.3),
			"range": 3.8,
			"cor": Color("#ffd9a8")
		},
		{
			"name": "LuzInterna_Entrada",
			"pos": Vector3(0.0, 1.15, -1.2),
			"range": 4.2,
			"cor": Color("#ffb347")
		}
	]

	for spec in specs:
		var nome_luz: String = str(spec["name"])
		var luz := get_node_or_null(nome_luz) as OmniLight3D
		if luz == null:
			luz = OmniLight3D.new()
			luz.name = nome_luz
			add_child(luz)
		luz.position = spec["pos"]
		luz.light_color = spec["cor"]
		luz.omni_range = float(spec["range"])
		luz.omni_attenuation = 1.2
		luz.light_energy = _energia_base_luzes
		luz.shadow_enabled = false
		_luzes_internas.append(luz)


func _criar_zona_interna_casa() -> void:
	_zona_interna = get_node_or_null("ZonaInternaCasa") as Area3D
	if _zona_interna == null:
		_zona_interna = Area3D.new()
		_zona_interna.name = "ZonaInternaCasa"
		_zona_interna.position = Vector3(0.0, 1.1, 0.1)
		_zona_interna.monitoring = true
		_zona_interna.monitorable = false

		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(6.8, 2.2, 4.4)
		col.shape = box
		_zona_interna.add_child(col)
		add_child(_zona_interna)

	if not _zona_interna.body_entered.is_connected(_ao_entrar_zona_interna):
		_zona_interna.body_entered.connect(_ao_entrar_zona_interna)
	if not _zona_interna.body_exited.is_connected(_ao_sair_zona_interna):
		_zona_interna.body_exited.connect(_ao_sair_zona_interna)


func _ao_entrar_zona_interna(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		if not jogador_dentro_casa:
			jogador_dentro_casa = true
			jogador_zona_casa_alterada.emit(true)


func _ao_sair_zona_interna(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		if jogador_dentro_casa:
			jogador_dentro_casa = false
			jogador_zona_casa_alterada.emit(false)


func contem_ponto_interno(pos_global: Vector3) -> bool:
	var p: Vector3 = to_local(pos_global)
	return p.x >= -3.5 and p.x <= 3.6 and p.y >= -0.2 and p.y <= 2.2 and p.z >= -2.25 and p.z <= 2.45


func esta_area_iluminada_interna(alvo: Node3D = null) -> bool:
	if queda_energia_ativa:
		return false
	if alvo != null:
		if is_ancestor_of(alvo):
			return true
		if alvo.is_inside_tree() and contem_ponto_interno(alvo.global_position):
			return true
		if _zona_interna != null and alvo is PhysicsBody3D and _zona_interna.overlaps_body(alvo):
			return true
		return false
	return jogador_dentro_casa


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
		corpo_colisao.set("exigir_lanterna_a_noite", false)


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

	corpo_radio.set("exigir_lanterna_a_noite", false)
	# Inicializa explicitamente pois set_script em nó já na árvore não dispara _ready()
	if corpo_radio.has_method("inicializar_radio"):
		corpo_radio.inicializar_radio()
	corpo_radio.set_process(true)

	# Carrega o novo áudio de voz sintética do rádio se ainda não atribuído
	var sons_atuais = corpo_radio.get("sons_jornal")
	if sons_atuais == null or (sons_atuais is Array and sons_atuais.is_empty()):
		var clipes_sinteticos: Array[AudioStream] = []
		for caminho_som in [
			"res://assets/audio/sfx/audioJornal (2).mp3"
		]:
			if ResourceLoader.exists(caminho_som):
				var clipe := load(caminho_som) as AudioStream
				if clipe != null:
					clipes_sinteticos.append(clipe)
		if not clipes_sinteticos.is_empty():
			corpo_radio.set("sons_jornal", clipes_sinteticos)

	# Carrega áudio longo legado da transmissão diária como fallback
	var caminho_legado := "res://assets/audio/sfx/radio_noticia_dia1.mp3"
	var stream_noticia: AudioStream = null
	if ResourceLoader.exists(caminho_legado):
		stream_noticia = load(caminho_legado) as AudioStream
	if stream_noticia != null:
		corpo_radio.set("audios_dias", [stream_noticia])

	# Vincula ao GameManager caso esteja vazio e inicia transmissão do dia se pendente
	if GameManager.instance != null:
		if GameManager.instance.radio == null:
			GameManager.instance.radio = corpo_radio
		if GameManager.instance.horario_atual == 0 and corpo_radio.has_method("esta_transmitindo"):
			if not corpo_radio.esta_transmitindo():
				corpo_radio.call_deferred("tocar_noticia", GameManager.instance.dia_atual)


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
	corpo_cama.set("exigir_lanterna_a_noite", false)


func _sincronizar_esconderijo_armario() -> void:
	var no_armario: Node3D = find_child("armario", true, false) as Node3D
	if no_armario == null:
		return

	var corpo_armario: StaticBody3D = null
	for filho in no_armario.get_children():
		if filho is StaticBody3D:
			corpo_armario = filho
			break

	if corpo_armario == null:
		corpo_armario = StaticBody3D.new()
		corpo_armario.name = "StaticBody3D"
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 12.0, 6.5)
		col.shape = box
		corpo_armario.add_child(col)
		no_armario.add_child(corpo_armario)

	var script_esconderijo: Script = load("res://scripts/interactables/esconderijo.gd")
	if corpo_armario.get_script() != script_esconderijo:
		corpo_armario.set_script(script_esconderijo)

	corpo_armario.set("nome_esconderijo", "Armário do Quarto")
	corpo_armario.set("prompt_interacao", "Esconder-se em Armário do Quarto")
	corpo_armario.set("exigir_lanterna_a_noite", false)
	corpo_armario.set("exigir_sequencia_direcional", false)
	if not corpo_armario.is_in_group("esconderijos"):
		corpo_armario.add_to_group("esconderijos")
	corpo_armario.set_process(true)


func _sincronizar_caixa_fusiveis() -> void:
	var no_caixa: Node3D = find_child("caixa_de_luz", true, false) as Node3D
	if no_caixa == null:
		return

	var corpo_caixa: StaticBody3D = null
	for filho in no_caixa.get_children():
		if filho is StaticBody3D:
			corpo_caixa = filho
			break

	if corpo_caixa == null:
		corpo_caixa = StaticBody3D.new()
		corpo_caixa.name = "StaticBody3D"
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 1.4, 1.4)
		col.shape = box
		corpo_caixa.add_child(col)
		no_caixa.add_child(corpo_caixa)

	var script_caixa: Script = load("res://scripts/interactables/caixa_fusiveis.gd")
	if corpo_caixa.get_script() != script_caixa:
		corpo_caixa.set_script(script_caixa)

	if corpo_caixa.has_method("inicializar_caixa_fusiveis"):
		corpo_caixa.inicializar_caixa_fusiveis()


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
