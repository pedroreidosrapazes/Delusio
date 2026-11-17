class_name TemaSurvivalHorror
extends RefCounted

## Utilitário de UI/UX inspirado em Resident Evil Clássico & RE7 para "Delusio".
## Aplica StyleBoxFlat, StyleBoxEmpty, sliders, separadores, checkboxes táticos
## e animações via Tween SEM alterar nenhuma fonte configurada no projeto.

const COR_FUNDO_ABSOLUTO := Color("#070708")
const COR_FUNDO_PAINEL := Color("#121215")
const COR_TEXTO_NORMAL := Color("#C8C6C1")
const COR_TEXTO_APAGADO := Color("#7A7873")
const COR_TEXTO_ATIVO := Color("#F2EFE9")
const COR_DESTAQUE_VERMELHO := Color("#A81414")
const COR_BORDA_VERMELHA := Color("#B81D1D")
const COR_FAIXA_HOVER := Color(0.55, 0.05, 0.05, 0.35)
const COR_FAIXA_PRESSIONADO := Color(0.65, 0.08, 0.08, 0.55)
const COR_STATUS_ERVA := Color("#4A6B53")
const COR_STATUS_AMBAR := Color("#B8863B")
const COR_DIVISORIA := Color("#2A2A2E")

const DESLOCAMENTO_HOVER_PX := 8.0
const DURACAO_HOVER_S := 0.14


## Percorre a subárvore de UI aplicando o estilo completo sem modificar fontes.
static func aplicar_tema_completo(raiz: Node) -> void:
	if raiz == null:
		return

	if raiz is CheckBox:
		aplicar_estilo_checkbox(raiz as CheckBox)
	elif raiz is Button:
		aplicar_estilo_botao(raiz as Button)
	elif raiz is HSlider:
		aplicar_estilo_slider(raiz as HSlider)
	elif raiz is HSeparator:
		aplicar_estilo_separador(raiz as HSeparator)
	elif raiz is PanelContainer:
		aplicar_estilo_painel(raiz as PanelContainer)

	for filho in raiz.get_children():
		aplicar_tema_completo(filho)


## Cria StyleBoxEmpty padrão mantendo margens internas idênticas para evitar pulos de layout.
static func criar_stylebox_vazio(margem_h: float = 16.0, margem_v: float = 8.0) -> StyleBoxEmpty:
	var vazio := StyleBoxEmpty.new()
	vazio.content_margin_left = margem_h
	vazio.content_margin_right = margem_h
	vazio.content_margin_top = margem_v
	vazio.content_margin_bottom = margem_v
	return vazio


## Cria StyleBoxFlat de destaque Survival Horror (faixa vermelha translúcida + borda esquerda 3px).
static func criar_stylebox_destaque(cor_fundo: Color = COR_FAIXA_HOVER, margem_h: float = 16.0, margem_v: float = 8.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = cor_fundo
	box.border_width_left = 3
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = 0
	box.border_color = COR_BORDA_VERMELHA
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.shadow_color = Color(0.66, 0.08, 0.08, 0.22)
	box.shadow_size = 4
	box.content_margin_left = margem_h
	box.content_margin_right = margem_h
	box.content_margin_top = margem_v
	box.content_margin_bottom = margem_v
	return box


## Aplica estilo RE clássico/RE7 a um Button e conecta animação suave de +8px via Tween.
static func aplicar_estilo_botao(botao: Button) -> void:
	if botao == null:
		return

	var estilo_normal := criar_stylebox_vazio(16.0, 8.0)
	var estilo_hover := criar_stylebox_destaque(COR_FAIXA_HOVER, 16.0, 8.0)
	var estilo_pressed := criar_stylebox_destaque(COR_FAIXA_PRESSIONADO, 16.0, 8.0)

	botao.add_theme_stylebox_override("normal", estilo_normal)
	botao.add_theme_stylebox_override("disabled", criar_stylebox_vazio(16.0, 8.0))
	botao.add_theme_stylebox_override("hover", estilo_hover)
	botao.add_theme_stylebox_override("focus", estilo_hover)
	botao.add_theme_stylebox_override("pressed", estilo_pressed)
	botao.add_theme_stylebox_override("hover_pressed", estilo_pressed)

	botao.add_theme_color_override("font_color", COR_TEXTO_NORMAL)
	botao.add_theme_color_override("font_hover_color", COR_TEXTO_ATIVO)
	botao.add_theme_color_override("font_focus_color", COR_TEXTO_ATIVO)
	botao.add_theme_color_override("font_pressed_color", COR_DESTAQUE_VERMELHO)
	botao.add_theme_color_override("font_hover_pressed_color", COR_TEXTO_ATIVO)
	botao.add_theme_color_override("font_disabled_color", COR_TEXTO_APAGADO)
	botao.add_theme_color_override("font_outline_color", Color(0.66, 0.08, 0.08, 0.45))
	botao.add_theme_constant_override("outline_size", 1)

	_vincular_animacao_deslocamento(botao)


## Aplica estilo tático a um CheckBox sem caixas padrão, indicando [ LIGADO ] / [ DESLIGADO ].
static func aplicar_estilo_checkbox(check: CheckBox) -> void:
	if check == null:
		return

	if not check.has_meta("re_titulo_base"):
		var texto_limpo := check.text
		for sufixo in ["  —  [ LIGADO ]", "  —  [ DESLIGADO ]", " [ LIGADO ]", " [ DESLIGADO ]"]:
			texto_limpo = texto_limpo.replace(sufixo, "")
		check.set_meta("re_titulo_base", texto_limpo.strip_edges())

	# Remove o ícone padrão arredondado do CheckBox do Godot
	var icone_vazio := ImageTexture.new()
	for nome_icone in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "radio_checked", "radio_unchecked"]:
		check.add_theme_icon_override(nome_icone, icone_vazio)
	check.add_theme_constant_override("h_separation", 0)
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var estilo_normal := criar_stylebox_vazio(14.0, 6.0)
	var estilo_hover := criar_stylebox_destaque(COR_FAIXA_HOVER, 14.0, 6.0)
	var estilo_pressed := criar_stylebox_destaque(COR_FAIXA_PRESSIONADO, 14.0, 6.0)

	check.add_theme_stylebox_override("normal", estilo_normal)
	check.add_theme_stylebox_override("hover", estilo_hover)
	check.add_theme_stylebox_override("focus", estilo_hover)
	check.add_theme_stylebox_override("pressed", estilo_pressed)
	check.add_theme_stylebox_override("hover_pressed", estilo_pressed)
	check.add_theme_stylebox_override("disabled", criar_stylebox_vazio(14.0, 6.0))

	check.add_theme_color_override("font_hover_color", COR_TEXTO_ATIVO)
	check.add_theme_color_override("font_focus_color", COR_TEXTO_ATIVO)
	check.add_theme_color_override("font_pressed_color", COR_TEXTO_ATIVO)
	check.add_theme_color_override("font_hover_pressed_color", COR_TEXTO_ATIVO)

	atualizar_visual_checkbox(check)

	if not check.has_meta("re_checkbox_conectado"):
		check.set_meta("re_checkbox_conectado", true)
		check.toggled.connect(func(_ligado: bool) -> void:
			atualizar_visual_checkbox(check)
		)

	_vincular_animacao_deslocamento(check)


## Atualiza o texto tático [ LIGADO ] / [ DESLIGADO ] e cor do CheckBox conforme seu estado.
static func atualizar_visual_checkbox(check: CheckBox) -> void:
	if check == null:
		return
	var base: String = str(check.get_meta("re_titulo_base", check.text))
	if check.button_pressed:
		check.text = "%s  —  [ LIGADO ]" % base
		check.add_theme_color_override("font_color", COR_TEXTO_NORMAL)
		check.add_theme_color_override("font_pressed_color", COR_TEXTO_ATIVO)
	else:
		check.text = "%s  —  [ DESLIGADO ]" % base
		check.add_theme_color_override("font_color", COR_TEXTO_APAGADO)
		check.add_theme_color_override("font_pressed_color", COR_TEXTO_APAGADO)


## Aplica estilo retangular de calibragem ao HSlider (trilho fino + preenchimento vermelho-sangue).
static func aplicar_estilo_slider(slider: HSlider) -> void:
	if slider == null:
		return

	var trilho := StyleBoxFlat.new()
	trilho.bg_color = COR_FUNDO_PAINEL
	trilho.border_width_left = 1
	trilho.border_width_top = 1
	trilho.border_width_right = 1
	trilho.border_width_bottom = 1
	trilho.border_color = COR_DIVISORIA
	trilho.content_margin_top = 3.0
	trilho.content_margin_bottom = 3.0

	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = COR_DESTAQUE_VERMELHO
	preenchimento.content_margin_top = 3.0
	preenchimento.content_margin_bottom = 3.0

	var preenchimento_destaque := StyleBoxFlat.new()
	preenchimento_destaque.bg_color = Color("#C91E1E")
	preenchimento_destaque.content_margin_top = 3.0
	preenchimento_destaque.content_margin_bottom = 3.0

	slider.add_theme_stylebox_override("slider", trilho)
	slider.add_theme_stylebox_override("grabber_area", preenchimento)
	slider.add_theme_stylebox_override("grabber_area_highlight", preenchimento_destaque)

	var marcador_normal := _criar_textura_retangular(4, 16, COR_TEXTO_NORMAL)
	var marcador_highlight := _criar_textura_retangular(5, 18, COR_TEXTO_ATIVO)
	slider.add_theme_icon_override("grabber", marcador_normal)
	slider.add_theme_icon_override("grabber_highlight", marcador_highlight)


## Aplica linha divisória fina em #2A2A2E ao HSeparator.
static func aplicar_estilo_separador(sep: HSeparator) -> void:
	if sep == null:
		return
	var linha := StyleBoxLine.new()
	linha.color = COR_DIVISORIA
	linha.thickness = 1
	linha.grow_begin = 0.0
	linha.grow_end = 0.0
	sep.add_theme_stylebox_override("separator", linha)
	sep.add_theme_constant_override("separation", 6)


## Aplica moldura escura tática a um PanelContainer.
static func aplicar_estilo_painel(painel: PanelContainer) -> void:
	if painel == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.035, 0.042, 0.88)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = COR_DIVISORIA
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	box.shadow_size = 14
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 24.0
	box.content_margin_bottom = 24.0
	painel.add_theme_stylebox_override("panel", box)


## Anima transição suave de opacidade e entrada entre painéis (compatível com árvore pausada).
static func animar_troca_paineis(painel_ocultar: CanvasItem, painel_mostrar: CanvasItem, foco_inicial: Control = null) -> void:
	if painel_ocultar and is_instance_valid(painel_ocultar):
		painel_ocultar.visible = false

	if painel_mostrar and is_instance_valid(painel_mostrar):
		painel_mostrar.modulate.a = 0.0
		painel_mostrar.visible = true
		var tween := painel_mostrar.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(painel_mostrar, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if foco_inicial and is_instance_valid(foco_inicial):
		foco_inicial.call_deferred("grab_focus")


static func _vincular_animacao_deslocamento(controle: BaseButton) -> void:
	if controle.has_meta("re_hover_conectado"):
		return
	controle.set_meta("re_hover_conectado", true)

	var pai := controle.get_parent()
	if pai is Container and not pai.has_meta("re_sort_observado"):
		pai.set_meta("re_sort_observado", true)
		(pai as Container).sort_children.connect(func() -> void:
			for c in pai.get_children():
				if c is BaseButton and not (c as BaseButton).is_hovered() and not (c as BaseButton).has_focus():
					c.set_meta("re_base_x", (c as Control).position.x)
		)

	controle.mouse_entered.connect(func() -> void:
		_atualizar_deslocamento_botao(controle, true)
	)
	controle.mouse_exited.connect(func() -> void:
		_atualizar_deslocamento_botao(controle, controle.has_focus())
	)
	controle.focus_entered.connect(func() -> void:
		_atualizar_deslocamento_botao(controle, true)
	)
	controle.focus_exited.connect(func() -> void:
		_atualizar_deslocamento_botao(controle, controle.is_hovered())
	)


static func _atualizar_deslocamento_botao(controle: BaseButton, destacado: bool) -> void:
	if not is_instance_valid(controle) or not controle.is_inside_tree():
		return

	if not controle.has_meta("re_base_x"):
		controle.set_meta("re_base_x", controle.position.x)

	var base_x: float = float(controle.get_meta("re_base_x", 0.0))
	var destino_x: float = base_x + (DESLOCAMENTO_HOVER_PX if destacado else 0.0)

	if controle.has_meta("re_tween_hover"):
		var tw_antigo = controle.get_meta("re_tween_hover")
		if tw_antigo is Tween and (tw_antigo as Tween).is_valid():
			(tw_antigo as Tween).kill()

	var tween := controle.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(controle, "position:x", destino_x, DURACAO_HOVER_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	controle.set_meta("re_tween_hover", tween)


static func _criar_textura_retangular(largura: int, altura: int, cor: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = largura
	tex.height = altura
	var grad := Gradient.new()
	grad.colors = PackedColorArray([cor, cor])
	tex.gradient = grad
	return tex
