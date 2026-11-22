class_name PainelLeituraDocumento
extends Control

## Painel modal de leitura de documentos e jornais no estilo Survival Horror ("Delusio").

signal leitura_aberta(titulo: String)
signal leitura_fechada()

const GRUPO_PAINEL := "painel_leitura_documento"
const GRUPO_MODAL_CURSOR := "modal_cursor_ui"

var filtro_delusio: FiltroDelusioControlador = null

var _painel_cartao: PanelContainer = null
var _label_titulo: Label = null
var _label_subtitulo: Label = null
var _label_texto: Label = null
var _scroll: ScrollContainer = null
var _botao_fechar: Button = null


func _ready() -> void:
	add_to_group(GRUPO_PAINEL)
	add_to_group(GRUPO_MODAL_CURSOR)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir_interface()


func _construir_interface() -> void:
	var fundo := ColorRect.new()
	fundo.name = "FundoEscuro"
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.03, 0.03, 0.04, 0.74)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	_painel_cartao = PanelContainer.new()
	_painel_cartao.name = "PainelCartaoDocumento"
	_painel_cartao.custom_minimum_size = Vector2(640.0, 440.0)
	var estilo_painel := StyleBoxFlat.new()
	estilo_painel.bg_color = TemaSurvivalHorror.COR_FUNDO_PAINEL
	estilo_painel.border_width_left = 2
	estilo_painel.border_width_top = 1
	estilo_painel.border_width_right = 1
	estilo_painel.border_width_bottom = 1
	estilo_painel.border_color = Color(0.58, 0.14, 0.14, 0.85)
	estilo_painel.content_margin_left = 28.0
	estilo_painel.content_margin_right = 28.0
	estilo_painel.content_margin_top = 24.0
	estilo_painel.content_margin_bottom = 22.0
	_painel_cartao.add_theme_stylebox_override("panel", estilo_painel)
	centro.add_child(_painel_cartao)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxConteudo"
	vbox.add_theme_constant_override("separation", 14)
	_painel_cartao.add_child(vbox)

	_label_titulo = Label.new()
	_label_titulo.name = "LabelTituloDocumento"
	_label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_titulo.add_theme_font_size_override("font_size", 24)
	_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_ATIVO)
	vbox.add_child(_label_titulo)

	_label_subtitulo = Label.new()
	_label_subtitulo.name = "LabelSubtituloDocumento"
	_label_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_subtitulo.add_theme_font_size_override("font_size", 13)
	_label_subtitulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)
	_label_subtitulo.visible = false
	vbox.add_child(_label_subtitulo)

	var sep := HSeparator.new()
	sep.name = "Separador"
	TemaSurvivalHorror.aplicar_estilo_separador(sep)
	vbox.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollTexto"
	_scroll.custom_minimum_size = Vector2(580.0, 270.0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_label_texto = Label.new()
	_label_texto.name = "LabelTextoDocumento"
	_label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_texto.add_theme_font_size_override("font_size", 16)
	_label_texto.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_NORMAL)
	_scroll.add_child(_label_texto)

	var hbox_rodape := HBoxContainer.new()
	hbox_rodape.name = "Rodape"
	hbox_rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox_rodape)

	_botao_fechar = Button.new()
	_botao_fechar.name = "BotaoFechar"
	_botao_fechar.text = "Fechar [E / Esc]"
	_botao_fechar.custom_minimum_size = Vector2(210.0, 40.0)
	TemaSurvivalHorror.aplicar_estilo_botao(_botao_fechar)
	_botao_fechar.pressed.connect(fechar)
	hbox_rodape.add_child(_botao_fechar)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			fechar()
			get_viewport().set_input_as_handled()


func abrir(titulo: String, texto: String, subtitulo: String = "") -> void:
	if _label_titulo != null:
		_label_titulo.text = titulo
	if _label_subtitulo != null:
		_label_subtitulo.text = subtitulo
		_label_subtitulo.visible = not subtitulo.strip_edges().is_empty()
	if _label_texto != null:
		_label_texto.text = texto
	if _scroll != null:
		_scroll.scroll_vertical = 0

	visible = true
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(0.75, false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	leitura_aberta.emit(titulo)


func fechar() -> void:
	if not visible:
		return
	BancoAudioDelusio.tocar_2d(self, &"papel_fechar", -6.0, 0.05)
	visible = false
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(0.0, false)
	if DisplayServer.get_name() != "headless":
		var outro_modal := false
		var tree := get_tree()
		if tree != null:
			if tree.paused:
				outro_modal = true
			else:
				for node in tree.get_nodes_in_group(GRUPO_MODAL_CURSOR):
					if node != self and node is CanvasItem and (node as CanvasItem).visible:
						outro_modal = true
						break
		if not outro_modal:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	leitura_fechada.emit()
