class_name LegendaRadioUI
extends Control

## Interface de Legendas do Rádio sincronizada via sinais com Radio.gd.
## Posicionada na parte inferior central do HUD com ajuste automático ao texto,
## opacidade baseada em proximidade 3D e fade-out após o término do boletim.

@export var radio_alvo: Radio
@export var atraso_ocultar_fim_s: float = 2.0
@export var largura_maxima_px: float = 640.0

var _margem_inferior: MarginContainer
var _painel_legenda: PanelContainer
var _texto_legenda: RichTextLabel

var _radio_conectado: Radio = null
var _fator_proximidade: float = 1.0
var _alpha_estado: float = 0.0
var _transmissao_ativa: bool = false
var _timer_ocultar: Timer
var _tween_fade: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_garantir_hierarquia_ui()
	_garantir_timer_ocultar()
	_aplicar_visibilidade_imediata(0.0)

	call_deferred("_tentar_conectar_radio")


func _process(_delta: float) -> void:
	if _radio_conectado == null or not is_instance_valid(_radio_conectado):
		_tentar_conectar_radio()


func _garantir_hierarquia_ui() -> void:
	_margem_inferior = get_node_or_null("MargemInferior") as MarginContainer
	if _margem_inferior == null:
		_margem_inferior = MarginContainer.new()
		_margem_inferior.name = "MargemInferior"
		_margem_inferior.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_margem_inferior.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_margem_inferior.add_theme_constant_override("margin_left", 48)
		_margem_inferior.add_theme_constant_override("margin_right", 48)
		_margem_inferior.add_theme_constant_override("margin_bottom", 96)
		add_child(_margem_inferior)

	_painel_legenda = _margem_inferior.get_node_or_null("PainelLegenda") as PanelContainer
	if _painel_legenda == null:
		_painel_legenda = PanelContainer.new()
		_painel_legenda.name = "PainelLegenda"
		_painel_legenda.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_painel_legenda.size_flags_vertical = Control.SIZE_SHRINK_END
		_painel_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_margem_inferior.add_child(_painel_legenda)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.02, 0.02, 0.025, 0.65)
	estilo.border_width_left = 2
	estilo.border_width_top = 1
	estilo.border_width_right = 1
	estilo.border_width_bottom = 1
	estilo.border_color = Color(0.165, 0.165, 0.18, 0.85)
	estilo.content_margin_left = 22.0
	estilo.content_margin_right = 22.0
	estilo.content_margin_top = 12.0
	estilo.content_margin_bottom = 12.0
	_painel_legenda.add_theme_stylebox_override("panel", estilo)

	_texto_legenda = _painel_legenda.get_node_or_null("TextoLegenda") as RichTextLabel
	if _texto_legenda == null:
		_texto_legenda = RichTextLabel.new()
		_texto_legenda.name = "TextoLegenda"
		_painel_legenda.add_child(_texto_legenda)

	_texto_legenda.bbcode_enabled = true
	_texto_legenda.fit_content = true
	_texto_legenda.scroll_active = false
	_texto_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto_legenda.add_theme_font_size_override("normal_font_size", 18)
	_texto_legenda.add_theme_color_override("default_color", Color("#EAE8E3"))


func _garantir_timer_ocultar() -> void:
	if _timer_ocultar != null:
		return
	_timer_ocultar = Timer.new()
	_timer_ocultar.name = "TimerOcultarLegenda"
	_timer_ocultar.one_shot = true
	_timer_ocultar.wait_time = maxf(0.1, atraso_ocultar_fim_s)
	_timer_ocultar.timeout.connect(_ao_expirar_ocultar)
	add_child(_timer_ocultar)


func _tentar_conectar_radio() -> void:
	var candidato: Radio = radio_alvo
	if candidato == null and GameManager.instance != null and GameManager.instance.radio is Radio:
		candidato = GameManager.instance.radio as Radio
	if candidato == null and get_tree() != null:
		candidato = get_tree().get_first_node_in_group("radio") as Radio

	if candidato == null or candidato == _radio_conectado:
		return

	_desconectar_radio_atual()
	_radio_conectado = candidato

	_radio_conectado.transmissao_iniciada.connect(_ao_iniciar_transmissao)
	_radio_conectado.legenda_atualizada.connect(_ao_atualizar_legenda)
	_radio_conectado.proximidade_alterada.connect(_ao_alterar_proximidade)
	_radio_conectado.transmissao_finalizada.connect(_ao_finalizar_transmissao)
	_radio_conectado.radio_desligado.connect(_ao_desligar_radio)

	# Sincroniza imediatamente caso o rádio já tenha iniciado antes da conexão dos sinais
	if _radio_conectado.esta_transmitindo():
		_ao_iniciar_transmissao(1)
		_ao_alterar_proximidade(_radio_conectado.obter_fator_proximidade_atual())
		var txt := _radio_conectado.obter_texto_atual()
		if not txt.is_empty():
			_ao_atualizar_legenda(txt, _radio_conectado.obter_caracteres_visiveis())


func _desconectar_radio_atual() -> void:
	if _radio_conectado == null or not is_instance_valid(_radio_conectado):
		_radio_conectado = null
		return
	if _radio_conectado.transmissao_iniciada.is_connected(_ao_iniciar_transmissao):
		_radio_conectado.transmissao_iniciada.disconnect(_ao_iniciar_transmissao)
	if _radio_conectado.legenda_atualizada.is_connected(_ao_atualizar_legenda):
		_radio_conectado.legenda_atualizada.disconnect(_ao_atualizar_legenda)
	if _radio_conectado.proximidade_alterada.is_connected(_ao_alterar_proximidade):
		_radio_conectado.proximidade_alterada.disconnect(_ao_alterar_proximidade)
	if _radio_conectado.transmissao_finalizada.is_connected(_ao_finalizar_transmissao):
		_radio_conectado.transmissao_finalizada.disconnect(_ao_finalizar_transmissao)
	if _radio_conectado.radio_desligado.is_connected(_ao_desligar_radio):
		_radio_conectado.radio_desligado.disconnect(_ao_desligar_radio)
	_radio_conectado = null


func _ao_iniciar_transmissao(_dia: int) -> void:
	_transmissao_ativa = true
	if _timer_ocultar:
		_timer_ocultar.stop()
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	_alpha_estado = 1.0
	_atualizar_opacidade_final()


func _ao_atualizar_legenda(texto_completo: String, caracteres_visiveis: int) -> void:
	if _texto_legenda == null:
		return

	_ajustar_largura_caixa(texto_completo)
	var bbcode := _formatar_bbcode(texto_completo)
	if _texto_legenda.text != bbcode:
		_texto_legenda.text = bbcode

	_texto_legenda.visible_characters = caracteres_visiveis

	if _transmissao_ativa and _alpha_estado < 1.0:
		_alpha_estado = 1.0
		_atualizar_opacidade_final()


func _ao_alterar_proximidade(fator_visibilidade: float) -> void:
	_fator_proximidade = clampf(fator_visibilidade, 0.0, 1.0)
	_atualizar_opacidade_final()


func _ao_finalizar_transmissao() -> void:
	_transmissao_ativa = false
	if _timer_ocultar:
		_timer_ocultar.wait_time = maxf(0.1, atraso_ocultar_fim_s)
		_timer_ocultar.start()


func _ao_expirar_ocultar() -> void:
	if _transmissao_ativa:
		return
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	_tween_fade = create_tween()
	_tween_fade.tween_method(_definir_alpha_estado, _alpha_estado, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_fade.tween_callback(func() -> void:
		if not _transmissao_ativa:
			_aplicar_visibilidade_imediata(0.0)
	)


func _ao_desligar_radio() -> void:
	_transmissao_ativa = false
	if _timer_ocultar:
		_timer_ocultar.stop()
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	_aplicar_visibilidade_imediata(0.0)


func _definir_alpha_estado(valor: float) -> void:
	_alpha_estado = clampf(valor, 0.0, 1.0)
	_atualizar_opacidade_final()


func _aplicar_visibilidade_imediata(alpha: float) -> void:
	_alpha_estado = clampf(alpha, 0.0, 1.0)
	_atualizar_opacidade_final()


func _atualizar_opacidade_final() -> void:
	if _painel_legenda == null:
		return
	var opacidade := clampf(_alpha_estado * _fator_proximidade, 0.0, 1.0)
	_painel_legenda.modulate.a = opacidade
	_painel_legenda.visible = opacidade > 0.01


func _ajustar_largura_caixa(texto_puro: String) -> void:
	var fonte := _texto_legenda.get_theme_font("normal_font")
	var tam := _texto_legenda.get_theme_font_size("normal_font_size")
	var largura_medida := 0.0
	if fonte != null:
		largura_medida = fonte.get_string_size(texto_puro, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 16.0
	else:
		largura_medida = float(texto_puro.length()) * 9.5 + 16.0

	if largura_medida > largura_maxima_px:
		_texto_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_texto_legenda.custom_minimum_size.x = largura_maxima_px
	else:
		_texto_legenda.autowrap_mode = TextServer.AUTOWRAP_OFF
		_texto_legenda.custom_minimum_size.x = maxf(240.0, largura_medida)


func _formatar_bbcode(texto: String) -> String:
	var seguro := texto.replace("[", "[lb]").replace("]", "[rb]")
	# Destaca prefixo [RÁDIO]: em âmbar mantendo o restante legível
	if texto.begins_with("[RÁDIO]:"):
		var resto := texto.substr(8).strip_edges().replace("[", "[lb]").replace("]", "[rb]")
		return "[center][color=#b8863b][lb]RÁDIO[rb]:[/color] %s[/center]" % resto
	return "[center]%s[/center]" % seguro
