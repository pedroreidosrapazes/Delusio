class_name MenuPausa
extends Control

## Menu de Pausa Tático estilo Survival Horror (Resident Evil) para "Delusio".
## Gerencia suspensão do jogo, indicador de status da fazenda, liberação/captura do mouse
## e configurações in-game sincronizadas com Tween compatível com árvore pausada.

@export_group("Navegação de Cenas")
@export_file("*.tscn") var cena_menu: String = "res://scenes/ui/main_menu.tscn"

@export_group("Referências de Nós")
@onready var fundo_escuro: ColorRect = $FundoEscuro
@onready var painel_pausa: PanelContainer = $PainelPausa
@onready var painel_configuracoes: PanelContainer = $PainelConfiguracoes
@onready var label_status_dia: Label = get_node_or_null("StatusCanto/VBoxStatus/LabelStatusDia") as Label
@onready var label_status_tarefas: Label = get_node_or_null("StatusCanto/VBoxStatus/LabelStatusTarefas") as Label

@export_group("Botões do Menu de Pausa")
@onready var botao_continuar: Button = $PainelPausa/VBoxPausa/BotoesPausa/BotaoContinuar
@onready var botao_configuracoes: Button = $PainelPausa/VBoxPausa/BotoesPausa/BotaoConfiguracoes
@onready var botao_menu_principal: Button = $PainelPausa/VBoxPausa/BotoesPausa/BotaoMenuPrincipal

@export_group("Controles de Configurações")
@onready var slider_audio: HSlider = $PainelConfiguracoes/VBoxConfig/SecaoAudio/SliderAudio
@onready var label_audio: Label = $PainelConfiguracoes/VBoxConfig/SecaoAudio/LabelAudio
@onready var check_tela_cheia: CheckBox = $PainelConfiguracoes/VBoxConfig/SecaoTela/CheckTelaCheia
@onready var check_vsync: CheckBox = get_node_or_null("PainelConfiguracoes/VBoxConfig/SecaoTela/CheckVSync") as CheckBox
@onready var slider_brilho: HSlider = $PainelConfiguracoes/VBoxConfig/SecaoBrilho/SliderBrilho
@onready var label_brilho: Label = $PainelConfiguracoes/VBoxConfig/SecaoBrilho/LabelBrilho
@onready var botao_voltar_pausa: Button = $PainelConfiguracoes/VBoxConfig/BotaoVoltarPausa

var _master_bus_idx: int = 0


func _ready() -> void:
	# Garante que este nó e seus filhos continuem executando quando get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	_master_bus_idx = AudioServer.get_bus_index("Master")

	# Aplica exatamente a mesma identidade visual do Menu Principal sem alterar fontes
	TemaSurvivalHorror.aplicar_tema_completo(self)

	# Inicia oculto e despausado
	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false

	_conectar_sinais()
	_inicializar_controles()


func _conectar_sinais() -> void:
	botao_continuar.pressed.connect(_on_botao_continuar_pressed)
	botao_configuracoes.pressed.connect(_on_botao_configuracoes_pressed)
	botao_menu_principal.pressed.connect(_on_botao_menu_principal_pressed)

	slider_audio.value_changed.connect(_on_slider_audio_value_changed)
	check_tela_cheia.toggled.connect(_on_check_tela_cheia_toggled)
	if check_vsync != null:
		check_vsync.toggled.connect(_on_check_vsync_toggled)
	slider_brilho.value_changed.connect(_on_slider_brilho_value_changed)
	botao_voltar_pausa.pressed.connect(_on_botao_voltar_pausa_pressed)


func _inicializar_controles() -> void:
	# 1. Volume Master
	var volume_db: float = AudioServer.get_bus_volume_db(_master_bus_idx)
	var volume_linear: float = 0.0 if AudioServer.is_bus_mute(_master_bus_idx) else db_to_linear(volume_db) * 100.0
	slider_audio.set_value_no_signal(clampf(volume_linear, 0.0, 100.0))
	label_audio.text = "VOLUME GERAL: %d%%" % int(round(slider_audio.value))

	# 2. Tela Cheia
	var modo_atual: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var esta_fullscreen: bool = (
		modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN or
		modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	check_tela_cheia.set_pressed_no_signal(esta_fullscreen)
	TemaSurvivalHorror.atualizar_visual_checkbox(check_tela_cheia)

	# 3. V-Sync
	if check_vsync != null:
		var vsync_atual: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
		check_vsync.set_pressed_no_signal(vsync_atual == DisplayServer.VSYNC_ENABLED)
		TemaSurvivalHorror.atualizar_visual_checkbox(check_vsync)

	# 4. Brilho
	slider_brilho.min_value = 0.5
	slider_brilho.max_value = 1.5
	slider_brilho.step = 0.05
	slider_brilho.set_value_no_signal(1.0)
	label_brilho.text = "BRILHO / EXPOSIÇÃO: 1.00"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if not get_tree().paused:
			for painel in get_tree().get_nodes_in_group("painel_leitura_documento"):
				if painel is CanvasItem and (painel as CanvasItem).visible and painel.has_method("fechar"):
					painel.fechar()
					get_viewport().set_input_as_handled()
					return
			pausar_jogo()
		else:
			if painel_configuracoes.visible:
				_on_botao_voltar_pausa_pressed()
			else:
				retomar_jogo()

		get_viewport().set_input_as_handled()


# ==============================================================================
# CONTROLE DO ESTADO DE PAUSA
# ==============================================================================

func pausar_jogo() -> void:
	get_tree().paused = true
	_atualizar_status_fazenda()
	_inicializar_controles()

	painel_pausa.visible = true
	painel_configuracoes.visible = false
	modulate.a = 0.0
	visible = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	botao_continuar.call_deferred("grab_focus")


func _atualizar_status_fazenda() -> void:
	var gerente := GameManager.instance
	var dia: int = 1
	var concluidas: int = 0
	var totais: int = 3
	var texto_periodo: String = "DIURNO"

	if gerente != null:
		dia = gerente.dia_atual
		concluidas = gerente.tarefas_concluidas
		totais = gerente.tarefas_totais
		match gerente.horario_atual:
			0:
				texto_periodo = "DIURNO"
			1:
				texto_periodo = "VESPERTINO"
			2:
				texto_periodo = "NOTURNO"

	var nome_modo: String = gerente.obter_nome_modo_jogo() if (gerente != null and gerente.has_method("obter_nome_modo_jogo")) else "MODO ENDLESS"
	if label_status_dia != null:
		label_status_dia.text = "DIA %d  //  PERÍODO: %s" % [dia, texto_periodo]
	if label_status_tarefas != null:
		label_status_tarefas.text = "%s  |  TAREFAS: %d / %d" % [nome_modo, concluidas, totais]


func _tem_menu_modal_cursor_ativo() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("modal_cursor_ui"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func retomar_jogo() -> void:
	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false
	get_tree().paused = false
	if _tem_menu_modal_cursor_ativo():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ==============================================================================
# SINAIS - PAINEL PRINCIPAL DE PAUSA
# ==============================================================================

func _on_botao_continuar_pressed() -> void:
	retomar_jogo()


func _on_botao_configuracoes_pressed() -> void:
	TemaSurvivalHorror.animar_troca_paineis(painel_pausa, painel_configuracoes, botao_voltar_pausa)


func _on_botao_menu_principal_pressed() -> void:
	# Despausa obrigatoriamente antes de trocar de cena
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var caminho_final: String = cena_menu
	if not ResourceLoader.exists(caminho_final):
		var alternativas: Array[String] = [
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
		AudioServer.set_bus_volume_db(_master_bus_idx, linear_to_db(value / 100.0))

	label_audio.text = "VOLUME GERAL: %d%%" % int(round(value))


func _on_check_tela_cheia_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_check_vsync_toggled(toggled_on: bool) -> void:
	var modo: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(modo)


func _on_slider_brilho_value_changed(value: float) -> void:
	label_brilho.text = "BRILHO / EXPOSIÇÃO: %.2f" % value
	_aplicar_brilho(value)


func _aplicar_brilho(valor: float) -> void:
	RenderingServer.global_shader_parameter_set("ajuste_brilho", valor)

	if get_tree().current_scene != null:
		var env_node := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if env_node and env_node.environment:
			env_node.environment.tonemap_exposure = valor


func _on_botao_voltar_pausa_pressed() -> void:
	TemaSurvivalHorror.animar_troca_paineis(painel_configuracoes, painel_pausa, botao_configuracoes)
