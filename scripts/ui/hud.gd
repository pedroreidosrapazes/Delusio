class_name HUD
extends CanvasLayer

## Interface do Usuário (HUD).

const CENA_LANTERNA: PackedScene = preload("res://scenes/props/flashlight.tscn")
const FILTRO_DELUSIO_CONTROLADOR := preload("res://scripts/visual/filtro_delusio_controlador.gd")
const MENU_ESCOLHA_MEDICAMENTOS := preload("res://scripts/ui/menu_escolha_medicamentos.gd")
const PAINEL_LISTA_TAREFAS := preload("res://scripts/ui/painel_lista_tarefas.gd")

@onready var label_tarefas: Label = $LabelTarefas
@onready var reticula: ColorRect = $ColorRect

@export var player: Player

var _barra: Control
var _slots: Array[Dictionary] = []
var _temporizador: Timer
var _viewport_icone: SubViewport
var _estilo_normal: StyleBoxFlat
var _estilo_selecionado: StyleBoxFlat

var _painel_sequencia: PainelSequenciaInteracao
var _painel_lista_tarefas: PainelListaTarefas
var _label_dica_lista_tarefas: Label
var _filtro_delusio: FiltroDelusioControlador
var _label_prompt_interacao: Label
var _alvo_focado_atual: Interactable = null
var menu_medicamentos: MenuEscolhaMedicamentos = null


func _ready() -> void:
	layer = 1

	_criar_filtro_delusio()
	_criar_menu_medicamentos()
	if GameManager.instance:
		GameManager.instance.tarefas_atualizadas.connect(_on_tarefas_atualizadas)
		GameManager.instance.status_temporario.connect(_on_status_temporario)
		GameManager.instance.horario_alterado.connect(_on_horario_alterado)
		GameManager.instance.dia_iniciado.connect(_on_dia_iniciado)
		if _filtro_delusio:
			_filtro_delusio.definir_estado_horario(GameManager.instance.horario_atual, true)
		if DisplayServer.get_name() != "headless":
			call_deferred("abrir_menu_medicamentos")

	_criar_painel_sequencia()
	_criar_painel_lista_tarefas()
	_criar_prompt_interacao()
	_criar_hotbar()

	if player:
		player.hotbar_alterada.connect(_sincronizar_hotbar)
		player.hotbar_selecionada.connect(_ao_selecionar_slot)
		player.interagivel_focado_alterado.connect(_ao_interagivel_focado_alterado)
		player.sequencia_interacao_iniciada.connect(_ao_sequencia_iniciada)
		player.sequencia_interacao_passo.connect(_ao_sequencia_passo)
		player.sequencia_interacao_erro.connect(_ao_sequencia_erro)
		player.sequencia_interacao_tempo.connect(_ao_sequencia_tempo)
		player.sequencia_interacao_finalizada.connect(_ao_sequencia_finalizada)
		_sincronizar_hotbar()


func obter_painel_sequencia() -> PainelSequenciaInteracao:
	return _painel_sequencia


func obter_filtro_delusio() -> FiltroDelusioControlador:
	return _filtro_delusio


func obter_menu_medicamentos() -> MenuEscolhaMedicamentos:
	return menu_medicamentos


func obter_painel_lista_tarefas() -> PainelListaTarefas:
	return _painel_lista_tarefas


func _criar_painel_lista_tarefas() -> void:
	if _painel_lista_tarefas == null:
		_painel_lista_tarefas = PAINEL_LISTA_TAREFAS.new()
		_painel_lista_tarefas.name = "PainelListaTarefas"
		add_child(_painel_lista_tarefas)

	if _label_dica_lista_tarefas == null:
		_label_dica_lista_tarefas = Label.new()
		_label_dica_lista_tarefas.name = "LabelDicaListaTarefas"
		_label_dica_lista_tarefas.position = Vector2(51.0, 68.0)
		_label_dica_lista_tarefas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label_dica_lista_tarefas.add_theme_font_size_override("font_size", 12)
		_label_dica_lista_tarefas.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
		_label_dica_lista_tarefas.text = "[X] Lista de Tarefas"
		add_child(_label_dica_lista_tarefas)


func alternar_lista_tarefas() -> void:
	if _painel_lista_tarefas == null:
		_criar_painel_lista_tarefas()
	_painel_lista_tarefas.alternar()
	if _label_dica_lista_tarefas != null:
		_label_dica_lista_tarefas.text = "[X] Ocultar Tarefas" if _painel_lista_tarefas.esta_aberta() else "[X] Lista de Tarefas"


func _criar_menu_medicamentos() -> void:
	if menu_medicamentos != null:
		return
	menu_medicamentos = MENU_ESCOLHA_MEDICAMENTOS.new()
	menu_medicamentos.name = "MenuEscolhaMedicamentos"
	menu_medicamentos.filtro_delusio = _filtro_delusio
	if GameManager.instance:
		menu_medicamentos.gerenciador = GameManager.instance.gerenciador_medicamentos
	add_child(menu_medicamentos)


func abrir_menu_medicamentos(vidros: Dictionary = {}) -> void:
	if menu_medicamentos == null:
		_criar_menu_medicamentos()
	if menu_medicamentos != null:
		menu_medicamentos.filtro_delusio = _filtro_delusio
		if GameManager.instance and menu_medicamentos.gerenciador == null:
			menu_medicamentos.gerenciador = GameManager.instance.gerenciador_medicamentos
		menu_medicamentos.abrir(vidros)


func _criar_filtro_delusio() -> void:
	if _filtro_delusio != null:
		return
	_filtro_delusio = FILTRO_DELUSIO_CONTROLADOR.new()
	_filtro_delusio.name = "FiltroDelusio"
	add_child(_filtro_delusio)


func _on_horario_alterado(estado: int) -> void:
	if _filtro_delusio:
		_filtro_delusio.definir_estado_horario(estado, false)
	if _painel_lista_tarefas != null and _painel_lista_tarefas.esta_aberta():
		_painel_lista_tarefas.atualizar_lista()


func _criar_painel_sequencia() -> void:
	_painel_sequencia = PainelSequenciaInteracao.new()
	_painel_sequencia.name = "PainelSequenciaInteracao"
	add_child(_painel_sequencia)


func _criar_prompt_interacao() -> void:
	_label_prompt_interacao = Label.new()
	_label_prompt_interacao.name = "LabelPromptInteracao"
	_label_prompt_interacao.anchor_left = 0.5
	_label_prompt_interacao.anchor_right = 0.5
	_label_prompt_interacao.anchor_top = 0.5
	_label_prompt_interacao.anchor_bottom = 0.5
	_label_prompt_interacao.offset_left = -260.0
	_label_prompt_interacao.offset_right = 260.0
	_label_prompt_interacao.offset_top = 28.0
	_label_prompt_interacao.offset_bottom = 60.0
	_label_prompt_interacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_prompt_interacao.add_theme_font_size_override("font_size", 14)
	_label_prompt_interacao.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_label_prompt_interacao.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label_prompt_interacao.add_theme_constant_override("shadow_offset_x", 1)
	_label_prompt_interacao.add_theme_constant_override("shadow_offset_y", 1)
	_label_prompt_interacao.visible = false
	add_child(_label_prompt_interacao)


func _ao_interagivel_focado_alterado(alvo: Interactable) -> void:
	_alvo_focado_atual = alvo
	_atualizar_prompt_interacao()


func _atualizar_prompt_interacao() -> void:
	if _label_prompt_interacao == null:
		return

	if _alvo_focado_atual == null or not is_instance_valid(_alvo_focado_atual) or not _alvo_focado_atual.pode_interagir():
		_label_prompt_interacao.visible = false
		return

	if player != null and player.esta_em_interacao_sequencia():
		_label_prompt_interacao.visible = false
		return

	var prompt := _alvo_focado_atual.prompt_interacao
	if _alvo_focado_atual.exigir_sequencia_direcional:
		_label_prompt_interacao.text = "[E] %s (%d setas • %.1fs)" % [
			prompt,
			_alvo_focado_atual.tamanho_sequencia,
			_alvo_focado_atual.tempo_limite_sequencia
		]
	else:
		_label_prompt_interacao.text = "[E] %s" % prompt

	_label_prompt_interacao.visible = true


func _ao_sequencia_iniciada(sequencia: Array[int], tempo_limite: float, titulo: String) -> void:
	if _label_prompt_interacao:
		_label_prompt_interacao.visible = false
	if _painel_sequencia:
		_painel_sequencia.mostrar_sequencia(sequencia, tempo_limite, titulo)


func _ao_sequencia_passo(indice: int, total: int) -> void:
	if _painel_sequencia:
		_painel_sequencia.atualizar_passo(indice, total)


func _ao_sequencia_erro(motivo: String, nova_sequencia: Array[int], tempo_restante: float) -> void:
	if _painel_sequencia:
		_painel_sequencia.registrar_erro(motivo, nova_sequencia, tempo_restante)
	if _filtro_delusio:
		_filtro_delusio.registrar_impulso_tensao(0.42)


func _ao_sequencia_tempo(restante: float, limite: float) -> void:
	if _painel_sequencia:
		_painel_sequencia.atualizar_tempo(restante, limite)


func _ao_sequencia_finalizada(sucesso: bool) -> void:
	if _painel_sequencia:
		_painel_sequencia.finalizar(sucesso)
	_atualizar_prompt_interacao()


func _criar_hotbar() -> void:
	_barra = MarginContainer.new()
	_barra.name = "Hotbar"
	_barra.anchor_left = 0.5
	_barra.anchor_right = 0.5
	_barra.anchor_top = 1.0
	_barra.anchor_bottom = 1.0
	_barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_barra.offset_left = -266.0
	_barra.offset_right = 266.0
	_barra.offset_top = -116.0
	_barra.offset_bottom = -16.0
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.visible = false
	add_child(_barra)

	var linha := HBoxContainer.new()
	linha.name = "Slots"
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.add_child(linha)

	_estilo_normal = _criar_estilo_slot(false)
	_estilo_selecionado = _criar_estilo_slot(true)
	for indice in Player.HOTBAR_SLOTS:
		var painel := PanelContainer.new()
		painel.name = "Slot%d" % (indice + 1)
		painel.custom_minimum_size = Vector2(82.0, 100.0)
		painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painel.add_theme_stylebox_override("panel", _estilo_normal)
		linha.add_child(painel)

		var conteudo := VBoxContainer.new()
		conteudo.add_theme_constant_override("separation", 0)
		conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painel.add_child(conteudo)

		var numero := Label.new()
		numero.text = str(indice + 1)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.add_theme_font_size_override("font_size", 14)
		conteudo.add_child(numero)

		var icone := TextureRect.new()
		icone.custom_minimum_size = Vector2(44.0, 44.0)
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		conteudo.add_child(icone)

		var nome_item := Label.new()
		nome_item.name = "Item"
		nome_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome_item.add_theme_font_size_override("font_size", 11)
		conteudo.add_child(nome_item)

		var quantidade := Label.new()
		quantidade.name = "Quantidade"
		quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantidade.add_theme_font_size_override("font_size", 14)
		conteudo.add_child(quantidade)
		_slots.append({"painel": painel, "icone": icone, "nome": nome_item, "quantidade": quantidade})

	_temporizador = Timer.new()
	_temporizador.name = "HotbarHideTimer"
	_temporizador.one_shot = true
	_temporizador.wait_time = 3.0
	_temporizador.timeout.connect(_ocultar_hotbar)
	add_child(_temporizador)


func _sincronizar_hotbar() -> void:
	if not player:
		return
	for indice in Player.HOTBAR_SLOTS:
		var item: Dictionary = player.obter_slot(indice)
		var id: StringName = item.get("id", &"")
		var quantidade: int = item.get("quantidade", 0)
		var rotulo: Label = _slots[indice]["quantidade"]
		rotulo.text = str(quantidade) if quantidade > 0 else ""
		var nome_item: Label = _slots[indice]["nome"]
		nome_item.text = _nome_item_legivel(id) if id != &"lanterna" else ""
		nome_item.tooltip_text = str(id)
		if id == &"lanterna":
			_preparar_icone_lanterna()
			(_slots[indice]["icone"] as TextureRect).texture = _viewport_icone.get_texture()
		else:
			(_slots[indice]["icone"] as TextureRect).texture = null
	_atualizar_destaque()


func _ao_selecionar_slot(indice: int) -> void:
	if indice < 0 or indice >= Player.HOTBAR_SLOTS:
		return
	_atualizar_destaque()
	_barra.show()
	_temporizador.start()


func _atualizar_destaque() -> void:
	for indice in Player.HOTBAR_SLOTS:
		var painel: PanelContainer = _slots[indice]["painel"]
		painel.add_theme_stylebox_override("panel", _estilo_selecionado if indice == player.indice_slot_selecionado else _estilo_normal)


func _criar_estilo_slot(selecionado: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.05, 0.07, 0.78)
	var largura_borda := 3 if selecionado else 1
	estilo.set_border_width_all(largura_borda)
	estilo.border_color = Color(1.0, 0.82, 0.34, 1.0) if selecionado else Color(0.7, 0.75, 0.82, 0.7)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 4.0
	estilo.content_margin_right = 4.0
	estilo.content_margin_top = 3.0
	estilo.content_margin_bottom = 3.0
	return estilo


func _nome_item_legivel(id: StringName) -> String:
	var nome := str(id).replace("_", " ")
	if nome.length() > 10:
		nome = nome.substr(0, 9) + "…"
	return nome.capitalize()


func _preparar_icone_lanterna() -> void:
	if _viewport_icone:
		return
	_viewport_icone = SubViewport.new()
	_viewport_icone.name = "LanternaIconViewport"
	_viewport_icone.size = Vector2i(128, 128)
	_viewport_icone.transparent_bg = true
	_viewport_icone.own_world_3d = true
	_viewport_icone.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport_icone)

	var mundo_icone := Node3D.new()
	_viewport_icone.add_child(mundo_icone)
	var modelo := CENA_LANTERNA.instantiate() as Node3D
	modelo.rotation_degrees = Vector3(14.0, -35.0, -12.0)
	mundo_icone.add_child(modelo)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	luz.light_energy = 2.0
	mundo_icone.add_child(luz)

	var camera_icone := Camera3D.new()
	camera_icone.position = Vector3(0.22, 0.14, -0.22)
	camera_icone.fov = 35.0
	mundo_icone.add_child(camera_icone)
	camera_icone.look_at(Vector3(0.0, 0.0, -0.01))
	camera_icone.current = true


func _ocultar_hotbar() -> void:
	_barra.hide()


func _on_tarefas_atualizadas(_concluidas: int, _totais: int, mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem
	if _painel_lista_tarefas != null and _painel_lista_tarefas.esta_aberta():
		_painel_lista_tarefas.atualizar_lista()


func _on_status_temporario(mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem


func _on_dia_iniciado(_dia: int) -> void:
	if _painel_lista_tarefas != null and _painel_lista_tarefas.esta_aberta():
		_painel_lista_tarefas.atualizar_lista()
	if DisplayServer.get_name() != "headless":
		abrir_menu_medicamentos()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			if (menu_medicamentos and menu_medicamentos.visible) or (_painel_sequencia and _painel_sequencia.visible):
				return
			alternar_lista_tarefas()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:
			if menu_medicamentos and menu_medicamentos.visible:
				menu_medicamentos.fechar()
			else:
				abrir_menu_medicamentos()
		elif event.keycode == KEY_N and GameManager.instance:
			if GameManager.instance.horario_atual != 2:
				GameManager.instance.iniciar_evento_terror()
			else:
				GameManager.instance.iniciar_novo_dia()
