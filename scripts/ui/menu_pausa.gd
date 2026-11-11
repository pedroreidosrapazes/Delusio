class_name MenuPausa
extends Control

## Menu de Pausa para o jogo "Delusio" (Godot 4).
## Gerencia suspensão do jogo, liberação/captura do mouse e configurações in-game.

@export_group("Navegação de Cenas")
@export_file("*.tscn") var cena_menu: String = "res://scenes/main_menu.tscn"

@export_group("Referências de Nós")
@onready var fundo_escuro: ColorRect = $FundoEscuro
@onready var painel_pausa: VBoxContainer = $PainelPausa
@onready var painel_configuracoes: VBoxContainer = $PainelConfiguracoes

@export_group("Botões do Menu de Pausa")
@onready var botao_continuar: Button = $PainelPausa/BotaoContinuar
@onready var botao_configuracoes: Button = $PainelPausa/BotaoConfiguracoes
@onready var botao_menu_principal: Button = $PainelPausa/BotaoMenuPrincipal

@export_group("Controles de Configurações")
@onready var slider_audio: HSlider = $PainelConfiguracoes/SecaoAudio/SliderAudio
@onready var label_audio: Label = $PainelConfiguracoes/SecaoAudio/LabelAudio
@onready var check_tela_cheia: CheckBox = $PainelConfiguracoes/SecaoTela/CheckTelaCheia
@onready var slider_brilho: HSlider = $PainelConfiguracoes/SecaoBrilho/SliderBrilho
@onready var label_brilho: Label = $PainelConfiguracoes/SecaoBrilho/LabelBrilho
@onready var botao_voltar_pausa: Button = $PainelConfiguracoes/BotaoVoltarPausa

var _master_bus_idx: int = 0

func _ready() -> void:
	# Garante que este nó e seus filhos continuem executando quando get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_master_bus_idx = AudioServer.get_bus_index("Master")
	
	# Inicia oculto e despausado
	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false
	
	_conectar_sinais()
	_inicializar_controles()

func _conectar_sinais() -> void:
	# Painel de Pausa
	botao_continuar.pressed.connect(_on_botao_continuar_pressed)
	botao_configuracoes.pressed.connect(_on_botao_configuracoes_pressed)
	botao_menu_principal.pressed.connect(_on_botao_menu_principal_pressed)
	
	# Painel de Configurações
	slider_audio.value_changed.connect(_on_slider_audio_value_changed)
	check_tela_cheia.toggled.connect(_on_check_tela_cheia_toggled)
	slider_brilho.value_changed.connect(_on_slider_brilho_value_changed)
	botao_voltar_pausa.pressed.connect(_on_botao_voltar_pausa_pressed)

func _inicializar_controles() -> void:
	# 1. Volume Master
	var volume_db: float = AudioServer.get_bus_volume_db(_master_bus_idx)
	var volume_linear: float = db_to_linear(volume_db) * 100.0
	slider_audio.value = clampf(volume_linear, 0.0, 100.0)
	label_audio.text = "Volume Geral: %d%%" % int(slider_audio.value)
	
	# 2. Tela Cheia
	var modo_atual: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var esta_fullscreen: bool = (
		modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN or 
		modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	check_tela_cheia.set_pressed_no_signal(esta_fullscreen)
	
	# 3. Brilho
	slider_brilho.min_value = 0.5
	slider_brilho.max_value = 1.5
	slider_brilho.step = 0.05
	slider_brilho.value = 1.0
	label_brilho.text = "Brilho: 1.00"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if not get_tree().paused:
			pausar_jogo()
		else:
			# Se estiver no submenu de configurações, volta para a tela de pausa
			if painel_configuracoes.visible:
				_on_botao_voltar_pausa_pressed()
			else:
				retomar_jogo()
		
		# Consome o evento para não passar para o Player ou outros scripts
		get_viewport().set_input_as_handled()

# ==============================================================================
# CONTROLE DO ESTADO DE PAUSA
# ==============================================================================

func pausar_jogo() -> void:
	get_tree().paused = true
	visible = true
	painel_pausa.visible = true
	painel_configuracoes.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	botao_continuar.grab_focus()

func retomar_jogo() -> void:
	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ==============================================================================
# SINAIS - PAINEL PRINCIPAL DE PAUSA
# ==============================================================================

func _on_botao_continuar_pressed() -> void:
	retomar_jogo()

func _on_botao_configuracoes_pressed() -> void:
	painel_pausa.visible = false
	painel_configuracoes.visible = true
	botao_voltar_pausa.grab_focus()

func _on_botao_menu_principal_pressed() -> void:
	# IMPORTANTE: Despausar a árvore antes de mudar de cena para evitar que o Menu fique congelado!
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var caminho_final: String = cena_menu
	if not ResourceLoader.exists(caminho_final):
		var alternativas: Array[String] = [
			"res://scenes/main_menu.tscn",
			"res://main_menu.tscn",
			"res://scenes/menu_principal.tscn",
			"res://scenes/ui/main_menu.tscn"
		]
		for alt in alternativas:
			if ResourceLoader.exists(alt):
				caminho_final = alt
				break
	
	if ResourceLoader.exists(caminho_final):
		get_tree().change_scene_to_file(caminho_final)
	else:
		push_error("MenuPausa: Cena do Menu Principal não encontrada em: " + cena_menu)

# ==============================================================================
# SINAIS - CONFIGURAÇÕES
# ==============================================================================

func _on_slider_audio_value_changed(value: float) -> void:
	if value <= 0.0:
		AudioServer.set_bus_mute(_master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(_master_bus_idx, false)
		var db: float = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(_master_bus_idx, db)
	
	label_audio.text = "Volume Geral: %d%%" % int(value)

func _on_check_tela_cheia_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_slider_brilho_value_changed(value: float) -> void:
	label_brilho.text = "Brilho: %.2f" % value
	_aplicar_brilho(value)

func _aplicar_brilho(valor: float) -> void:
	# 1. Se houver shader global registrado no projeto:
	RenderingServer.global_shader_parameter_set("ajuste_brilho", valor)
	
	# 2. Ajuste direto em WorldEnvironment (se presente na cena da fazenda):
	var env_node: WorldEnvironment = get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node and env_node.environment:
		env_node.environment.tonemap_exposure = valor

func _on_botao_voltar_pausa_pressed() -> void:
	painel_configuracoes.visible = false
	painel_pausa.visible = true
	botao_configuracoes.grab_focus()
