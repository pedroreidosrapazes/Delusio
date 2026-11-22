class_name MainMenu
extends Control

## Menu Principal e Configurações para "Delusio" (Estética Survival Horror / Resident Evil).
## Gerencia cenário 3D atmosférico em câmera fixa, transições via Tween, áudio logarítmico,
## exibição de tela, V-Sync e calibragem de brilho/exposição.

@export_group("Cenas")
## Caminho da cena 3D de Gameplay (Fazenda).
@export_file("*.tscn") var cena_jogo: String = "res://scenes/levels/world.tscn"
@export_file("*.tscn") var cena_historia: String = "res://scenes/levels/world.tscn"
@export var modo_historia_disponivel: bool = false

@export_group("Atmosfera 3D da Tela Título")
@export var amplitude_respiracao_pos: float = 0.014
@export var amplitude_respiracao_rot: float = 0.008
@export var energia_base_lampada: float = 2.4

@onready var menu_principal: MarginContainer = $MenuPrincipal
@onready var menu_configuracoes: MarginContainer = $MenuConfiguracoes

@onready var botao_modo_endless: Button = $MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoModoEndless
@onready var botao_modo_historia: Button = $MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoModoHistoria
@onready var botao_configuracoes: Button = $MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoConfiguracoes
@onready var botao_sair: Button = $MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoSair
@onready var label_descricao_modo: Label = get_node_or_null("MenuPrincipal/ColunaEsquerda/LabelDescricaoModo") as Label
@onready var label_recorde_endless: Label = get_node_or_null("MenuPrincipal/ColunaEsquerda/LabelRecordeEndless") as Label

@onready var audio_slider: HSlider = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoAudio/AudioSlider
@onready var audio_label: Label = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoAudio/AudioLabel
@onready var tela_cheia_check_box: CheckBox = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoTela/TelaCheiaCheckBox
@onready var vsync_check_box: CheckBox = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoTela/VSyncCheckBox
@onready var brilho_slider: HSlider = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoBrilho/BrilhoSlider
@onready var brilho_label: Label = $MenuConfiguracoes/PainelFundo/VBoxContainer/PainelConfig/SecaoBrilho/BrilhoLabel
@onready var botao_voltar: Button = $MenuConfiguracoes/PainelFundo/VBoxContainer/BotaoVoltar

@onready var brilho_overlay: ColorRect = $BrilhoOverlay
@onready var musica_menu: AudioStreamPlayer = get_node_or_null("MusicaMenu") as AudioStreamPlayer
@onready var camera_titulo: Camera3D = get_node_or_null("Cenario3DContainer/SubViewport/CenaTitulo3D/CameraTitulo") as Camera3D
@onready var luz_lampada: Light3D = get_node_or_null("Cenario3DContainer/SubViewport/CenaTitulo3D/LuzLampada") as Light3D
@onready var world_env_titulo: WorldEnvironment = get_node_or_null("Cenario3DContainer/SubViewport/CenaTitulo3D/WorldEnvironment") as WorldEnvironment

var caminho_config: String = ConfiguracoesUsuario.CAMINHO_PADRAO
var _master_bus_idx: int = 0
var _tempo_menu: float = 0.0
var _pos_base_camera: Vector3 = Vector3.ZERO
var _rot_base_camera: Vector3 = Vector3.ZERO
var _fator_oscilacao_luz: float = 1.0
var _carregando_ui: bool = false


func _ready() -> void:
	# Garante que o cursor do mouse esteja livre e visível no menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_master_bus_idx = AudioServer.get_bus_index("Master")

	if camera_titulo != null:
		_pos_base_camera = camera_titulo.position
		_rot_base_camera = camera_titulo.rotation
	if luz_lampada != null:
		energia_base_lampada = luz_lampada.light_energy

	# Aplica identidade visual Survival Horror sem alterar nenhuma fonte existente
	TemaSurvivalHorror.aplicar_tema_completo(self)
	if not modo_historia_disponivel and botao_modo_historia != null:
		botao_modo_historia.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)

	_conectar_sinais()
	_inicializar_valores_ui()
	atualizar_recorde_endless()
	_mostrar_menu_principal(false)
	if musica_menu != null and not musica_menu.finished.is_connected(_ao_terminar_musica_menu):
		musica_menu.finished.connect(_ao_terminar_musica_menu)


func _exit_tree() -> void:
	if musica_menu != null:
		musica_menu.stop()
	BancoAudioDelusio.limpar_cache()


func _ao_terminar_musica_menu() -> void:
	if musica_menu != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		musica_menu.play()


func atualizar_recorde_endless(caminho_save: String = RegistroEndless.CAMINHO_PADRAO) -> void:
	if label_recorde_endless == null:
		return
	# Linha de melhor marca ocultada por decisão do projeto (Debug Mode).
	label_recorde_endless.visible = false
	var reg: Dictionary = RegistroEndless.carregar(caminho_save)
	var rec_dias: int = int(reg.get("recorde_dias", 0))
	var rec_tarefas: int = int(reg.get("recorde_tarefas", 0))
	if rec_dias > 0 or rec_tarefas > 0:
		label_recorde_endless.text = "DEBUG MODE: %d NOITE(S)  |  %d TAREFA(S)" % [rec_dias, rec_tarefas]
	else:
		label_recorde_endless.text = "DEBUG MODE: NENHUMA NOITE SOBREVIVIDA AINDA"


func _process(delta: float) -> void:
	_tempo_menu += delta

	# Movimento sutil de respiração/oscilação na câmera fixa
	if camera_titulo != null:
		var respiracao_y := sin(_tempo_menu * 0.72) * amplitude_respiracao_pos
		var balanco_x := sin(_tempo_menu * 0.43) * amplitude_respiracao_rot
		var balanco_y := cos(_tempo_menu * 0.35) * amplitude_respiracao_rot
		camera_titulo.position = _pos_base_camera + Vector3(0.0, respiracao_y, 0.0)
		camera_titulo.rotation = _rot_base_camera + Vector3(balanco_x, balanco_y, 0.0)

	# Oscilação de lâmpada velha / filamento instável
	if luz_lampada != null:
		var ruido_suave := sin(_tempo_menu * 5.7) * 0.04 + sin(_tempo_menu * 13.3) * 0.03
		if randf() < 0.025:
			_fator_oscilacao_luz = randf_range(0.55, 0.85)
		else:
			_fator_oscilacao_luz = move_toward(_fator_oscilacao_luz, 1.0 + ruido_suave, delta * 6.5)
		luz_lampada.light_energy = maxf(0.2, energia_base_lampada * _fator_oscilacao_luz)


func _atualizar_descricao_modo(texto: String, cor: Color) -> void:
	if label_descricao_modo == null:
		return
	label_descricao_modo.text = texto
	label_descricao_modo.add_theme_color_override("font_color", cor)


func _conectar_sinais() -> void:
	botao_modo_endless.pressed.connect(_on_botao_modo_endless_pressed)
	botao_modo_historia.pressed.connect(_on_botao_modo_historia_pressed)
	botao_configuracoes.pressed.connect(_on_botao_configuracoes_pressed)
	botao_sair.pressed.connect(_on_botao_sair_pressed)

	var descricoes: Array[Dictionary] = [
		{
			"botao": botao_modo_endless,
			"texto": "Debug Mode: modo temporário de validação contínua das mecânicas do jogo.",
			"cor": TemaSurvivalHorror.COR_TEXTO_NORMAL
		},
		{
			"botao": botao_modo_historia,
			"texto": "Modo História (em desenvolvimento): será construído depois sobre a base validada no Debug Mode.",
			"cor": TemaSurvivalHorror.COR_STATUS_AMBAR
		},
		{
			"botao": botao_configuracoes,
			"texto": "Ajuste volume, vídeo e calibragem de brilho.",
			"cor": TemaSurvivalHorror.COR_TEXTO_APAGADO
		},
		{
			"botao": botao_sair,
			"texto": "Encerrar Delusio e voltar para a área de trabalho.",
			"cor": TemaSurvivalHorror.COR_TEXTO_APAGADO
		}
	]
	for item: Dictionary in descricoes:
		var botao: Button = item["botao"] as Button
		var texto: String = str(item["texto"])
		var cor: Color = item["cor"] as Color
		if botao == null:
			continue
		botao.mouse_entered.connect(func() -> void: _atualizar_descricao_modo(texto, cor))
		botao.focus_entered.connect(func() -> void: _atualizar_descricao_modo(texto, cor))

	audio_slider.value_changed.connect(_on_audio_slider_value_changed)
	tela_cheia_check_box.toggled.connect(_on_tela_cheia_toggled)
	vsync_check_box.toggled.connect(_on_vsync_toggled)
	brilho_slider.value_changed.connect(_on_brilho_slider_value_changed)
	botao_voltar.pressed.connect(_on_botao_voltar_pressed)


func _inicializar_valores_ui() -> void:
	_carregando_ui = true
	var dados: Dictionary = ConfiguracoesUsuario.carregar(caminho_config)
	ConfiguracoesUsuario.aplicar_todas(dados, get_tree(), DisplayServer.get_name() != "headless", world_env_titulo)

	# Áudio Master (slider em escala 0..1 convertido para 0..100%)
	var volume_pct: float = float(dados.get("volume_master", 100.0))
	var volume_linear: float = clampf(volume_pct / 100.0, 0.0, 1.0)
	audio_slider.set_value_no_signal(volume_linear)
	_atualizar_label_audio(volume_linear)

	# Tela Cheia
	var modo_atual: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var esta_tela_cheia: bool = bool(dados.get("tela_cheia", false)) if DisplayServer.get_name() == "headless" else (
		modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN or
		modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	tela_cheia_check_box.set_pressed_no_signal(esta_tela_cheia)
	TemaSurvivalHorror.atualizar_visual_checkbox(tela_cheia_check_box)

	# V-Sync
	var vsync_ativo: bool = bool(dados.get("vsync", true)) if DisplayServer.get_name() == "headless" else (
		DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	)
	vsync_check_box.set_pressed_no_signal(vsync_ativo)
	TemaSurvivalHorror.atualizar_visual_checkbox(vsync_check_box)

	# Brilho / Exposição
	var v_brilho: float = float(dados.get("brilho", 1.0))
	brilho_slider.set_value_no_signal(v_brilho)
	_atualizar_label_brilho(v_brilho)
	_aplicar_brilho(v_brilho)
	_carregando_ui = false


func _salvar_parcial_config(chave: String, valor: Variant) -> void:
	if _carregando_ui:
		return
	var dados: Dictionary = ConfiguracoesUsuario.carregar(caminho_config)
	dados[chave] = valor
	ConfiguracoesUsuario.salvar(dados, caminho_config)


# ==============================================================================
# TRANSIÇÕES DE INTERFACE
# ==============================================================================

func _mostrar_menu_principal(animar: bool = true) -> void:
	if animar:
		TemaSurvivalHorror.animar_troca_paineis(menu_configuracoes, menu_principal, botao_modo_endless)
	else:
		menu_principal.visible = true
		menu_configuracoes.visible = false
		botao_modo_endless.grab_focus()


func _mostrar_configuracoes() -> void:
	TemaSurvivalHorror.animar_troca_paineis(menu_principal, menu_configuracoes, botao_voltar)


# ==============================================================================
# CALLBACKS - MENU PRINCIPAL
# ==============================================================================

func _carregar_cena_modo(caminho_preferido: String, contexto_erro: String) -> bool:
	var destino: String = caminho_preferido

	if not ResourceLoader.exists(destino) and ResourceLoader.exists("res://scenes/levels/world.tscn"):
		destino = "res://scenes/levels/world.tscn"

	if destino.is_empty():
		push_error("MainMenu: Nenhuma cena de gameplay atribuída para %s." % contexto_erro)
		return false

	if ResourceLoader.exists(destino):
		get_tree().change_scene_to_file(destino)
		return true

	push_error("MainMenu: A cena de %s não foi encontrada no caminho: %s" % [contexto_erro, destino])
	return false


func iniciar_modo_endless() -> bool:
	GameManager.definir_modo_jogo(GameManager.ModoJogo.ENDLESS)
	return _carregar_cena_modo(cena_jogo, "Debug Mode")


func iniciar_modo_historia() -> bool:
	if not modo_historia_disponivel:
		_atualizar_descricao_modo(
			"Modo História ainda em desenvolvimento — use o Debug Mode para validar as mecânicas.",
			TemaSurvivalHorror.COR_STATUS_AMBAR
		)
		return false

	GameManager.definir_modo_jogo(GameManager.ModoJogo.HISTORIA)
	return _carregar_cena_modo(cena_historia, "Modo História")


func _on_botao_modo_endless_pressed() -> void:
	iniciar_modo_endless()


func _on_botao_modo_historia_pressed() -> void:
	iniciar_modo_historia()


func _on_botao_configuracoes_pressed() -> void:
	_mostrar_configuracoes()


func _on_botao_sair_pressed() -> void:
	get_tree().quit()


# ==============================================================================
# CALLBACKS - CONFIGURAÇÕES
# ==============================================================================

func _on_audio_slider_value_changed(value: float) -> void:
	var pct: float = clampf(value * 100.0, 0.0, 100.0)
	ConfiguracoesUsuario.aplicar_audio_bus(&"Master", pct)
	_atualizar_label_audio(value)
	_salvar_parcial_config("volume_master", pct)


func _atualizar_label_audio(valor_linear: float) -> void:
	var porcentagem: int = int(round(valor_linear * 100.0))
	audio_label.text = "VOLUME GERAL: %d%%" % porcentagem


func _on_tela_cheia_toggled(toggled_on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_salvar_parcial_config("tela_cheia", toggled_on)


func _on_vsync_toggled(toggled_on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		var modo: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(modo)
	_salvar_parcial_config("vsync", toggled_on)


func _on_brilho_slider_value_changed(value: float) -> void:
	_atualizar_label_brilho(value)
	_aplicar_brilho(value)
	_salvar_parcial_config("brilho", value)


func _atualizar_label_brilho(valor: float) -> void:
	brilho_label.text = "CALIBRAGEM DE GAMA / BRILHO: %.2f" % valor


func _aplicar_brilho(valor: float) -> void:
	ConfiguracoesUsuario.aplicar_brilho(valor, get_tree(), world_env_titulo)

	if is_instance_valid(brilho_overlay):
		if valor < 1.0:
			brilho_overlay.color = Color(0.0, 0.0, 0.0, clampf((1.0 - valor) * 0.8, 0.0, 0.85))
		else:
			brilho_overlay.color = Color(1.0, 1.0, 1.0, clampf((valor - 1.0) * 0.35, 0.0, 0.5))


func _on_botao_voltar_pressed() -> void:
	_mostrar_menu_principal(true)
