class_name HUD
extends CanvasLayer

## Interface do Usuário (HUD).

const CENA_LANTERNA: PackedScene = preload("res://scenes/props/flashlight.tscn")

@onready var label_tarefas: Label = $LabelTarefas
@onready var reticula: ColorRect = $ColorRect

@export var player: Player

var _barra: Control
var _slots: Array[Dictionary] = []
var _temporizador: Timer
var _viewport_icone: SubViewport
var _estilo_normal: StyleBoxFlat
var _estilo_selecionado: StyleBoxFlat

func _ready() -> void:
	if GameManager.instance:
		GameManager.instance.tarefas_atualizadas.connect(_on_tarefas_atualizadas)
		GameManager.instance.status_temporario.connect(_on_status_temporario)
	_criar_hotbar()
	if player:
		player.hotbar_alterada.connect(_sincronizar_hotbar)
		player.hotbar_selecionada.connect(_ao_selecionar_slot)
		_sincronizar_hotbar()

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
	modelo.rotation_degrees = Vector3(-12.0, -28.0, -15.0)
	mundo_icone.add_child(modelo)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	luz.light_energy = 2.0
	mundo_icone.add_child(luz)

	var camera_icone := Camera3D.new()
	camera_icone.position = Vector3(3.2, 1.6, 4.2)
	camera_icone.fov = 35.0
	mundo_icone.add_child(camera_icone)
	camera_icone.look_at(Vector3(0.0, 0.25, 0.0))
	camera_icone.current = true

func _ocultar_hotbar() -> void:
	_barra.hide()

func _on_tarefas_atualizadas(_concluidas: int, _totais: int, mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem

func _on_status_temporario(mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem
