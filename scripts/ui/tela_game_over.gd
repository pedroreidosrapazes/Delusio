class_name TelaGameOver
extends Control

## Tela de Game Over do Modo Endless (estética Survival Horror).
## Integrada ao grupo 'modal_cursor_ui' para liberar cursor e travar câmera/movimento do Player.

const GRUPO_MODAL_CURSOR := "modal_cursor_ui"
const CENA_MENU_PRINCIPAL := "res://scenes/ui/main_menu.tscn"

var _fundo: ColorRect
var _painel: PanelContainer
var _label_titulo: Label
var _label_causa: Label
var _label_selo_recorde: Label
var _label_resumo: Label
var _botao_tentar: Button
var _botao_menu: Button


func _ready() -> void:
	add_to_group(GRUPO_MODAL_CURSOR)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir_interface()
	TemaSurvivalHorror.aplicar_tema_completo(self)
	if _label_titulo != null:
		_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_DESTAQUE_VERMELHO)
	if _label_selo_recorde != null:
		_label_selo_recorde.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)


func _construir_interface() -> void:
	_fundo = ColorRect.new()
	_fundo.name = "FundoEscuroGameOver"
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.color = Color(0.02, 0.015, 0.018, 0.90)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	var centro := CenterContainer.new()
	centro.name = "CentroGameOver"
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_painel = PanelContainer.new()
	_painel.name = "PainelGameOver"
	_painel.custom_minimum_size = Vector2(540.0, 0.0)
	centro.add_child(_painel)

	var vbox := VBoxContainer.new()
	vbox.name = "ConteudoGameOver"
	vbox.add_theme_constant_override("separation", 12)
	_painel.add_child(vbox)

	var tag := Label.new()
	tag.name = "TagSistemaGameOver"
	tag.text = "REGISTRO DE ÓBITO  //  FAZENDA ISOLADA"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
	vbox.add_child(tag)

	_label_titulo = Label.new()
	_label_titulo.name = "LabelTituloGameOver"
	_label_titulo.text = "VOCÊ FOI ALCANÇADO"
	_label_titulo.add_theme_font_size_override("font_size", 34)
	_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_DESTAQUE_VERMELHO)
	vbox.add_child(_label_titulo)

	_label_causa = Label.new()
	_label_causa.name = "LabelCausaGameOver"
	_label_causa.text = "Capturado por: Criatura Noturna"
	_label_causa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_causa.add_theme_font_size_override("font_size", 16)
	_label_causa.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_ATIVO)
	vbox.add_child(_label_causa)

	_label_selo_recorde = Label.new()
	_label_selo_recorde.name = "LabelSeloRecorde"
	_label_selo_recorde.text = ""
	_label_selo_recorde.visible = false
	_label_selo_recorde.add_theme_font_size_override("font_size", 13)
	_label_selo_recorde.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
	vbox.add_child(_label_selo_recorde)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	_label_resumo = Label.new()
	_label_resumo.name = "LabelResumoRodada"
	_label_resumo.text = ""
	_label_resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_resumo.add_theme_font_size_override("font_size", 15)
	_label_resumo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_NORMAL)
	vbox.add_child(_label_resumo)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var botoes := VBoxContainer.new()
	botoes.name = "BotoesGameOver"
	botoes.add_theme_constant_override("separation", 8)
	vbox.add_child(botoes)

	_botao_tentar = Button.new()
	_botao_tentar.name = "BotaoTentarNovamente"
	_botao_tentar.text = "TENTAR NOVAMENTE"
	_botao_tentar.custom_minimum_size = Vector2(320.0, 42.0)
	_botao_tentar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_botao_tentar.add_theme_font_size_override("font_size", 18)
	_botao_tentar.pressed.connect(_on_tentar_novamente_pressed)
	botoes.add_child(_botao_tentar)

	_botao_menu = Button.new()
	_botao_menu.name = "BotaoMenuPrincipalGameOver"
	_botao_menu.text = "MENU PRINCIPAL"
	_botao_menu.custom_minimum_size = Vector2(320.0, 42.0)
	_botao_menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_botao_menu.add_theme_font_size_override("font_size", 18)
	_botao_menu.pressed.connect(_on_menu_principal_pressed)
	botoes.add_child(_botao_menu)


func abrir(resumo: Dictionary) -> void:
	var causa: String = str(resumo.get("causa", "Criatura Noturna"))
	var dia_alcancado: int = int(resumo.get("dia_atual", 1))
	var dias_sobr: int = int(resumo.get("dias_sobrevividos", 0))
	var tarefas_rod: int = int(resumo.get("tarefas_rodada", 0))

	if _label_causa != null:
		_label_causa.text = "Capturado por: %s" % causa

	if _label_selo_recorde != null:
		_label_selo_recorde.visible = false

	if _label_resumo != null:
		_label_resumo.text = (
			"Dia alcançado: %d\nNoites sobrevividas: %d\nTarefas concluídas na rodada: %d"
			% [dia_alcancado, dias_sobr, tarefas_rod]
		)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true

	if DisplayServer.get_name() == "headless":
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _botao_tentar != null:
		_botao_tentar.call_deferred("grab_focus")


func fechar() -> void:
	visible = false
	modulate.a = 1.0


func _on_tentar_novamente_pressed() -> void:
	fechar()
	if GameManager.instance != null and GameManager.instance.has_method("reiniciar_rodada_endless"):
		GameManager.instance.reiniciar_rodada_endless()
	elif get_tree() != null:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_menu_principal_pressed() -> void:
	fechar()
	if get_tree() != null:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if ResourceLoader.exists(CENA_MENU_PRINCIPAL):
			get_tree().change_scene_to_file(CENA_MENU_PRINCIPAL)
