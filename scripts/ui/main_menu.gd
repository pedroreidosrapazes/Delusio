class_name MainMenu
extends Control

## Menu Principal e Configurações para "Delusio" (Terror Psicológico Low-Poly).
## Gerencia transição para a cena da fazenda, áudio logarítmico, exibição de tela e brilho.

@export_group("Cenas")
## Caminho da cena 3D de Gameplay (Fazenda). Se não encontrar CenaPrincipal.tscn, tenta world.tscn.
@export_file("*.tscn") var cena_fazenda: String = "res://CenaPrincipal.tscn"

@export_group("Nós de Navegação")
@onready var menu_principal: MarginContainer = $MenuPrincipal
@onready var menu_configuracoes: MarginContainer = $MenuConfiguracoes

@export_group("Controles do Menu Principal")
@onready var botao_jogar: Button = $MenuPrincipal/VBoxContainer/BotoesContainer/BotaoJogar
@onready var botao_configuracoes: Button = $MenuPrincipal/VBoxContainer/BotoesContainer/BotaoConfiguracoes
@onready var botao_sair: Button = $MenuPrincipal/VBoxContainer/BotoesContainer/BotaoSair

@export_group("Controles de Configurações")
@onready var audio_slider: HSlider = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoAudio/AudioSlider
@onready var audio_label: Label = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoAudio/AudioLabel
@onready var tela_cheia_check_box: CheckBox = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoTela/TelaCheiaCheckBox
@onready var vsync_check_box: CheckBox = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoTela/VSyncCheckBox
@onready var brilho_slider: HSlider = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoBrilho/BrilhoSlider
@onready var brilho_label: Label = $MenuConfiguracoes/VBoxContainer/PainelConfig/SecaoBrilho/BrilhoLabel
@onready var botao_voltar: Button = $MenuConfiguracoes/VBoxContainer/BotaoVoltar

@export_group("Ajuste Visual de Brilho")
## Overlay opcional para pré-visualizar ou aplicar brilho global via CanvasLayer/ColorRect
@onready var brilho_overlay: ColorRect = $BrilhoOverlay

var _master_bus_idx: int = 0

func _ready() -> void:
	# Garante que o cursor do mouse esteja livre e visível no menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Localiza o barramento de áudio Master
	_master_bus_idx = AudioServer.get_bus_index("Master")
	
	_conectar_sinais()
	_inicializar_valores_ui()
	_mostrar_menu_principal()

## Conexão explícita de sinais via código (garante funcionamento sem depender apenas do editor)
func _conectar_sinais() -> void:
	# Menu Principal
	botao_jogar.pressed.connect(_on_botao_jogar_pressed)
	botao_configuracoes.pressed.connect(_on_botao_configuracoes_pressed)
	botao_sair.pressed.connect(_on_botao_sair_pressed)
	
	# Menu de Configurações
	audio_slider.value_changed.connect(_on_audio_slider_value_changed)
	tela_cheia_check_box.toggled.connect(_on_tela_cheia_toggled)
	vsync_check_box.toggled.connect(_on_vsync_toggled)
	brilho_slider.value_changed.connect(_on_brilho_slider_value_changed)
	botao_voltar.pressed.connect(_on_botao_voltar_pressed)

## Carrega o estado atual da aplicação nos componentes de UI
func _inicializar_valores_ui() -> void:
	# Inicialização de Áudio
	var volume_db: float = AudioServer.get_bus_volume_db(_master_bus_idx)
	var volume_linear: float = db_to_linear(volume_db)
	audio_slider.value = volume_linear
	_atualizar_label_audio(volume_linear)
	
	# Inicialização de Tela Cheia
	var modo_atual: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var esta_tela_cheia: bool = (modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN or modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	tela_cheia_check_box.set_pressed_no_signal(esta_tela_cheia)
	
	# Inicialização de V-Sync
	var vsync_atual: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	vsync_check_box.set_pressed_no_signal(vsync_atual == DisplayServer.VSYNC_ENABLED)
	
	# Inicialização de Brilho
	brilho_slider.value = 1.0
	_atualizar_label_brilho(1.0)
	_aplicar_brilho(1.0)

# ==============================================================================
# TRANSIÇÕES DE INTERFACE
# ==============================================================================

func _mostrar_menu_principal() -> void:
	menu_principal.visible = true
	menu_configuracoes.visible = false
	botao_jogar.grab_focus()

func _mostrar_configuracoes() -> void:
	menu_principal.visible = false
	menu_configuracoes.visible = true
	botao_voltar.grab_focus()

# ==============================================================================
# CALLBACKS - MENU PRINCIPAL
# ==============================================================================

func _on_botao_jogar_pressed() -> void:
	var destino: String = cena_fazenda
	
	# Fallback seguro para o projeto Delusio caso o arquivo CenaPrincipal.tscn não exista
	if not ResourceLoader.exists(destino) and ResourceLoader.exists("res://scenes/world.tscn"):
		destino = "res://scenes/world.tscn"
		
	if destino.is_empty():
		push_error("MainMenu: Nenhuma cena de gameplay atribuída em 'cena_fazenda'.")
		return
	
	if ResourceLoader.exists(destino):
		get_tree().change_scene_to_file(destino)
	else:
		push_error("MainMenu: A cena da fazenda não foi encontrada no caminho: " + destino)

func _on_botao_configuracoes_pressed() -> void:
	_mostrar_configuracoes()

func _on_botao_sair_pressed() -> void:
	get_tree().quit()

# ==============================================================================
# CALLBACKS - CONFIGURAÇÕES
# ==============================================================================

func _on_audio_slider_value_changed(value: float) -> void:
	# Mapeamento logarítmico correto de volume (linear_to_db)
	if value <= 0.001:
		AudioServer.set_bus_mute(_master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(_master_bus_idx, false)
		var db: float = linear_to_db(value)
		AudioServer.set_bus_volume_db(_master_bus_idx, db)
	
	_atualizar_label_audio(value)

func _atualizar_label_audio(valor_linear: float) -> void:
	var porcentagem: int = int(round(valor_linear * 100.0))
	audio_label.text = "Volume Geral: %d%%" % porcentagem

func _on_tela_cheia_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(toggled_on: bool) -> void:
	var modo: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(modo)

func _on_brilho_slider_value_changed(value: float) -> void:
	_atualizar_label_brilho(value)
	_aplicar_brilho(value)

func _atualizar_label_brilho(valor: float) -> void:
	brilho_label.text = "Gama / Brilho: %.2f" % valor

func _aplicar_brilho(valor: float) -> void:
	# Calibragem sutil de gama/exposição visual:
	# Se brilho_overlay existir, usamos a modulação alfa para reforço ou clareamento
	if is_instance_valid(brilho_overlay):
		if valor < 1.0:
			# Escurece (adiciona sombra preta gradual)
			brilho_overlay.color = Color(0.0, 0.0, 0.0, clampf((1.0 - valor) * 0.8, 0.0, 0.85))
		else:
			# Clareia sutilmente
			brilho_overlay.color = Color(1.0, 1.0, 1.0, clampf((valor - 1.0) * 0.35, 0.0, 0.5))

func _on_botao_voltar_pressed() -> void:
	_mostrar_menu_principal()
