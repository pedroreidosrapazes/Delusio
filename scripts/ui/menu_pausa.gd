class_name MenuPausa
extends Control

## Menu de Pausa Tático sobre Diário 3D animado ("Delusio").
## Sobe na tela enquanto abre as páginas do Diário.blend, exibindo resumo/controles na página esquerda
## e ações/configurações persistentes na página direita em modo híbrido.

@export_group("Navegação de Cenas")
@export_file("*.tscn") var cena_menu: String = "res://scenes/ui/main_menu.tscn"

@export_group("Referências de Nós")
@onready var fundo_escuro: ColorRect = $FundoEscuro
@onready var palco_diario: AspectRatioContainer = $PalcoDiario
@onready var sub_viewport_diario: SubViewport = $PalcoDiario/DiarioViewportContainer/SubViewport
@onready var pivot_diario: Node3D = $PalcoDiario/DiarioViewportContainer/SubViewport/CenaDiario3D/PivotDiario
@onready var diario_modelo: Node = $PalcoDiario/DiarioViewportContainer/SubViewport/CenaDiario3D/PivotDiario/DiarioModelo
@onready var camada_paginas: Control = $PalcoDiario/CamadaPaginas
@onready var label_resumo_diario: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaEsquerda/VBoxEsquerda/LabelResumoDiario") as Label
@onready var label_controles: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaEsquerda/VBoxEsquerda/LabelControles") as Label
@onready var painel_pausa: PanelContainer = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelPausa
@onready var painel_configuracoes: PanelContainer = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes
@onready var label_status_dia: Label = get_node_or_null("StatusCanto/VBoxStatus/LabelStatusDia") as Label
@onready var label_status_tarefas: Label = get_node_or_null("StatusCanto/VBoxStatus/LabelStatusTarefas") as Label

@export_group("Botões do Menu de Pausa")
@onready var botao_continuar: Button = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelPausa/VBoxPausa/BotoesPausa/BotaoContinuar
@onready var botao_configuracoes: Button = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelPausa/VBoxPausa/BotoesPausa/BotaoConfiguracoes
@onready var botao_menu_principal: Button = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelPausa/VBoxPausa/BotoesPausa/BotaoMenuPrincipal

@export_group("Controles de Configurações")
@onready var slider_audio: HSlider = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxMaster/SliderAudio
@onready var label_audio: Label = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxMaster/LabelAudio
@onready var slider_musica: HSlider = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxMusica/SliderMusica") as HSlider
@onready var label_musica: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxMusica/LabelMusica") as Label
@onready var slider_ambiente: HSlider = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxAmbiente/SliderAmbiente") as HSlider
@onready var label_ambiente: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxAmbiente/LabelAmbiente") as Label
@onready var slider_sfx: HSlider = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxSFX/SliderSFX") as HSlider
@onready var label_sfx: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoAudio/BoxSFX/LabelSFX") as Label
@onready var check_tela_cheia: CheckBox = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoTela/CheckTelaCheia
@onready var check_vsync: CheckBox = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoTela/CheckVSync") as CheckBox
@onready var slider_brilho: HSlider = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoBrilho/BoxBrilho/SliderBrilho
@onready var label_brilho: Label = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoBrilho/BoxBrilho/LabelBrilho
@onready var slider_sensibilidade: HSlider = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoBrilho/BoxSens/SliderSensibilidade") as HSlider
@onready var label_sensibilidade: Label = get_node_or_null("PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/SecaoBrilho/BoxSens/LabelSensibilidade") as Label
@onready var botao_voltar_pausa: Button = $PalcoDiario/CamadaPaginas/PaginaDireita/PainelConfiguracoes/ScrollConfig/VBoxConfig/BotaoVoltarPausa

var caminho_config: String = ConfiguracoesUsuario.CAMINHO_PADRAO
var _anim_diario: AnimationPlayer = null
var _nome_anim_abrir: String = ""
var _tween_diario: Tween = null
var _fechando: bool = false
var _carregando_ui: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	TemaSurvivalHorror.aplicar_tema_papel(camada_paginas)
	_preparar_diario_3d()

	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false

	_conectar_sinais()
	_inicializar_controles(false)


func _preparar_diario_3d() -> void:
	if diario_modelo == null:
		return
	var encontrado := diario_modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if encontrado == null:
		for child in diario_modelo.get_children():
			if child is AnimationPlayer:
				encontrado = child as AnimationPlayer
				break
	_anim_diario = encontrado
	if _anim_diario == null:
		return

	_anim_diario.process_mode = Node.PROCESS_MODE_ALWAYS
	if _anim_diario.has_animation("Abrir"):
		_nome_anim_abrir = "Abrir"
	elif _anim_diario.has_animation("RIG_DiarioAction"):
		_nome_anim_abrir = "RIG_DiarioAction"
	else:
		for nome_anim in _anim_diario.get_animation_list():
			if nome_anim != "RESET":
				_nome_anim_abrir = nome_anim
				break


func _conectar_sinais() -> void:
	botao_continuar.pressed.connect(_on_botao_continuar_pressed)
	botao_configuracoes.pressed.connect(_on_botao_configuracoes_pressed)
	botao_menu_principal.pressed.connect(_on_botao_menu_principal_pressed)

	slider_audio.value_changed.connect(_on_slider_audio_value_changed)
	if slider_musica != null:
		slider_musica.value_changed.connect(_on_slider_musica_value_changed)
	if slider_ambiente != null:
		slider_ambiente.value_changed.connect(_on_slider_ambiente_value_changed)
	if slider_sfx != null:
		slider_sfx.value_changed.connect(_on_slider_sfx_value_changed)
	check_tela_cheia.toggled.connect(_on_check_tela_cheia_toggled)
	if check_vsync != null:
		check_vsync.toggled.connect(_on_check_vsync_toggled)
	slider_brilho.value_changed.connect(_on_slider_brilho_value_changed)
	if slider_sensibilidade != null:
		slider_sensibilidade.value_changed.connect(_on_slider_sensibilidade_value_changed)
	botao_voltar_pausa.pressed.connect(_on_botao_voltar_pausa_pressed)


func _inicializar_controles(aplicar_janela: bool = false) -> void:
	_carregando_ui = true
	var dados: Dictionary = ConfiguracoesUsuario.carregar(caminho_config)
	ConfiguracoesUsuario.aplicar_todas(dados, get_tree(), aplicar_janela)

	var v_master: float = float(dados.get("volume_master", 100.0))
	slider_audio.set_value_no_signal(v_master)
	label_audio.text = "VOLUME GERAL: %d%%" % int(round(v_master))

	if slider_musica != null and label_musica != null:
		var v_musica: float = float(dados.get("volume_musica", 100.0))
		slider_musica.set_value_no_signal(v_musica)
		label_musica.text = "MÚSICA: %d%%" % int(round(v_musica))

	if slider_ambiente != null and label_ambiente != null:
		var v_amb: float = float(dados.get("volume_ambiente", 100.0))
		slider_ambiente.set_value_no_signal(v_amb)
		label_ambiente.text = "AMBIENTE: %d%%" % int(round(v_amb))

	if slider_sfx != null and label_sfx != null:
		var v_sfx: float = float(dados.get("volume_sfx", 100.0))
		slider_sfx.set_value_no_signal(v_sfx)
		label_sfx.text = "EFEITOS (SFX): %d%%" % int(round(v_sfx))

	var modo_atual: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var esta_fullscreen: bool = (
		modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN
		or modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	check_tela_cheia.set_pressed_no_signal(esta_fullscreen)
	TemaSurvivalHorror.atualizar_visual_checkbox(check_tela_cheia)

	if check_vsync != null:
		var vsync_atual: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
		check_vsync.set_pressed_no_signal(vsync_atual == DisplayServer.VSYNC_ENABLED)
		TemaSurvivalHorror.atualizar_visual_checkbox(check_vsync)

	slider_brilho.min_value = 0.5
	slider_brilho.max_value = 1.5
	slider_brilho.step = 0.05
	var v_brilho: float = float(dados.get("brilho", 1.0))
	slider_brilho.set_value_no_signal(v_brilho)
	label_brilho.text = "BRILHO: %.2f" % v_brilho

	if slider_sensibilidade != null and label_sensibilidade != null:
		var v_sens: float = float(dados.get("sensibilidade_mouse", 0.002))
		slider_sensibilidade.set_value_no_signal(v_sens)
		label_sensibilidade.text = "MOUSE: %.2fx" % (v_sens / 0.002)

	_carregando_ui = false


func _coletar_config_atual() -> Dictionary:
	return {
		"volume_master": slider_audio.value,
		"volume_musica": slider_musica.value if slider_musica != null else 100.0,
		"volume_ambiente": slider_ambiente.value if slider_ambiente != null else 100.0,
		"volume_sfx": slider_sfx.value if slider_sfx != null else 100.0,
		"tela_cheia": check_tela_cheia.button_pressed,
		"vsync": check_vsync.button_pressed if check_vsync != null else true,
		"brilho": slider_brilho.value,
		"sensibilidade_mouse": slider_sensibilidade.value if slider_sensibilidade != null else 0.002
	}


func _salvar_config_atual() -> void:
	if _carregando_ui:
		return
	ConfiguracoesUsuario.salvar(_coletar_config_atual(), caminho_config)


func _input(event: InputEvent) -> void:
	if GameManager.instance != null and GameManager.instance.jogo_encerrado:
		return
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
# CONTROLE DO ESTADO DE PAUSA E ANIMAÇÃO DO DIÁRIO 3D
# ==============================================================================

func pausar_jogo() -> void:
	_fechando = false
	if _tween_diario and _tween_diario.is_valid():
		_tween_diario.kill()

	get_tree().paused = true
	_atualizar_status_fazenda()
	_inicializar_controles(false)

	painel_pausa.visible = true
	painel_configuracoes.visible = false
	painel_pausa.modulate.a = 1.0
	visible = true

	if DisplayServer.get_name() == "headless":
		if pivot_diario != null:
			pivot_diario.position = Vector3.ZERO
			pivot_diario.rotation_degrees = Vector3.ZERO
		if _anim_diario != null and not _nome_anim_abrir.is_empty():
			var anim := _anim_diario.get_animation(_nome_anim_abrir)
			if anim != null:
				_anim_diario.play(_nome_anim_abrir)
				_anim_diario.seek(anim.length, true)
				_anim_diario.stop()
		fundo_escuro.modulate.a = 1.0
		camada_paginas.modulate.a = 1.0
		modulate.a = 1.0
	else:
		BancoAudioDelusio.tocar_2d(self, &"papel_abrir", -4.0, 0.04)
		modulate.a = 1.0
		fundo_escuro.modulate.a = 0.0
		camada_paginas.modulate.a = 0.0

		if pivot_diario != null:
			pivot_diario.position = Vector3(0.0, -3.2, 0.0)
			pivot_diario.rotation_degrees = Vector3(16.0, 0.0, 0.0)
		if _anim_diario != null and not _nome_anim_abrir.is_empty():
			_anim_diario.play(_nome_anim_abrir, -1.0, 0.90)
			_anim_diario.seek(0.0, true)

		_tween_diario = create_tween().set_parallel(true)
		_tween_diario.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween_diario.tween_property(fundo_escuro, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if pivot_diario != null:
			_tween_diario.tween_property(pivot_diario, "position:y", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween_diario.tween_property(pivot_diario, "rotation_degrees:x", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween_diario.tween_property(camada_paginas, "modulate:a", 1.0, 0.16).set_delay(0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	botao_continuar.call_deferred("grab_focus")


func _atualizar_status_fazenda() -> void:
	var gerente := GameManager.instance
	var dia: int = 1
	var concluidas: int = 0
	var totais: int = 3
	var texto_periodo: String = "DIURNO"
	var texto_hora: String = "06:00"
	var protecao_ativa: bool = false

	if gerente != null:
		dia = gerente.dia_atual
		concluidas = gerente.tarefas_concluidas
		totais = gerente.tarefas_totais
		if gerente.has_method("obter_hora_formatada"):
			texto_hora = gerente.obter_hora_formatada()
		if gerente.has_method("possui_protecao_captura_ativa"):
			protecao_ativa = gerente.possui_protecao_captura_ativa()
		match gerente.horario_atual:
			0:
				texto_periodo = "DIURNO"
			1:
				texto_periodo = "VESPERTINO"
			2:
				texto_periodo = "NOTURNO"

	var nome_modo: String = gerente.obter_nome_modo_jogo() if (gerente != null and gerente.has_method("obter_nome_modo_jogo")) else "DEBUG MODE"
	if label_status_dia != null:
		label_status_dia.text = "DIA %d  //  PERÍODO: %s" % [dia, texto_periodo]
	if label_status_tarefas != null:
		label_status_tarefas.text = "%s  |  TAREFAS: %d / %d" % [nome_modo, concluidas, totais]

	if label_resumo_diario != null:
		var linha_pilula: String = "Proteção: Drágea de 2ª Chance ativa" if protecao_ativa else "Proteção: Sem 2ª chance (1ª captura fatal)"
		label_resumo_diario.text = (
			"DIA %d  •  %s (%s)\n%s\nTarefas concluídas: %d / %d\n%s"
			% [dia, texto_periodo, texto_hora, nome_modo, concluidas, totais, linha_pilula]
		)

	if label_controles != null:
		var texto_base: String = "[WASD] Mover    [Shift] Correr\n[E] Interagir / Esconder\n[F] Lanterna    [Q] Olhar atrás\n[X] Caderno de Tarefas\n[1-6] Hotbar    [Esc] Pausar"
		var em_debug: bool = gerente.esta_em_modo_debug() if (gerente != null and gerente.has_method("esta_em_modo_debug")) else true
		if em_debug:
			label_controles.text = texto_base + "\n[N] Dia/Noite    [P] Pílulas (Debug)"
		else:
			label_controles.text = texto_base


func _tem_menu_modal_cursor_ativo() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("modal_cursor_ui"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func retomar_jogo(imediato: bool = false) -> void:
	if not visible and not get_tree().paused:
		return
	if DisplayServer.get_name() == "headless" or imediato:
		if _tween_diario and _tween_diario.is_valid():
			_tween_diario.kill()
		_concluir_retomada()
		return

	if _fechando:
		return
	_fechando = true
	if _tween_diario and _tween_diario.is_valid():
		_tween_diario.kill()

	BancoAudioDelusio.tocar_2d(self, &"papel_fechar", -5.0, 0.04)
	if _anim_diario != null and not _nome_anim_abrir.is_empty():
		_anim_diario.play_backwards(_nome_anim_abrir)

	_tween_diario = create_tween().set_parallel(true)
	_tween_diario.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_diario.tween_property(camada_paginas, "modulate:a", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_diario.tween_property(fundo_escuro, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if pivot_diario != null:
		_tween_diario.tween_property(pivot_diario, "position:y", -3.2, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween_diario.tween_property(pivot_diario, "rotation_degrees:x", 16.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween_diario.chain().tween_callback(func() -> void:
		if _fechando:
			_concluir_retomada()
	)


func _concluir_retomada() -> void:
	_fechando = false
	visible = false
	painel_pausa.visible = true
	painel_configuracoes.visible = false
	camada_paginas.modulate.a = 1.0
	fundo_escuro.modulate.a = 1.0
	if get_tree() != null:
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
	if _tween_diario and _tween_diario.is_valid():
		_tween_diario.kill()
	_fechando = false
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
	ConfiguracoesUsuario.aplicar_audio_bus(&"Master", value)
	label_audio.text = "VOLUME GERAL: %d%%" % int(round(value))
	_salvar_config_atual()


func _on_slider_musica_value_changed(value: float) -> void:
	ConfiguracoesUsuario.aplicar_audio_bus(&"Musica", value)
	if label_musica != null:
		label_musica.text = "MÚSICA: %d%%" % int(round(value))
	_salvar_config_atual()


func _on_slider_ambiente_value_changed(value: float) -> void:
	ConfiguracoesUsuario.aplicar_audio_bus(&"Ambiente", value)
	if label_ambiente != null:
		label_ambiente.text = "AMBIENTE: %d%%" % int(round(value))
	_salvar_config_atual()


func _on_slider_sfx_value_changed(value: float) -> void:
	ConfiguracoesUsuario.aplicar_audio_bus(&"SFX", value)
	if label_sfx != null:
		label_sfx.text = "EFEITOS (SFX): %d%%" % int(round(value))
	_salvar_config_atual()


func _on_check_tela_cheia_toggled(toggled_on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_salvar_config_atual()


func _on_check_vsync_toggled(toggled_on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		var modo: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(modo)
	_salvar_config_atual()


func _on_slider_brilho_value_changed(value: float) -> void:
	label_brilho.text = "BRILHO: %.2f" % value
	ConfiguracoesUsuario.aplicar_brilho(value, get_tree())
	_salvar_config_atual()


func _on_slider_sensibilidade_value_changed(value: float) -> void:
	if label_sensibilidade != null:
		label_sensibilidade.text = "MOUSE: %.2fx" % (value / 0.002)
	ConfiguracoesUsuario.aplicar_sensibilidade_mouse(value, get_tree())
	_salvar_config_atual()


func _on_botao_voltar_pausa_pressed() -> void:
	TemaSurvivalHorror.animar_troca_paineis(painel_configuracoes, painel_pausa, botao_configuracoes)
