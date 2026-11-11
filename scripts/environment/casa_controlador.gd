class_name CasaControlador
extends Node3D

## Controlador dinâmico da Casa.
## Sincroniza automaticamente as portas com suas respectivas animações no AnimationPlayer,
## tornando-as interativas com o RayCast3D do Player, e inicializa o rádio 3D.

@export var animation_player: AnimationPlayer

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
