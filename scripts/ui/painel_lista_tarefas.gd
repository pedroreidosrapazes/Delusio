class_name PainelListaTarefas
extends Control

## Painel retrátil de Lista de Tarefas do Dia (acionado pela tecla X).
## Segue a estética Survival Horror do projeto sem alterar fontes configuradas.

const POS_X_BASE := 51.0
const POS_Y_BASE := 94.0
const LARGURA_PAINEL := 350.0

var _painel: PanelContainer
var _label_titulo: Label
var _label_periodo: Label
var _lista_container: VBoxContainer
var _label_rodape: Label
var _tween_visibilidade: Tween
var _aberta: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_construir_interface()


func _construir_interface() -> void:
	_painel = PanelContainer.new()
	_painel.name = "PainelTarefasFundo"
	_painel.position = Vector2(POS_X_BASE, POS_Y_BASE)
	_painel.custom_minimum_size = Vector2(LARGURA_PAINEL, 0.0)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.027, 0.027, 0.031, 0.86)
	estilo.border_width_left = 3
	estilo.border_width_top = 1
	estilo.border_width_right = 1
	estilo.border_width_bottom = 1
	estilo.border_color = TemaSurvivalHorror.COR_DIVISORIA
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	estilo.shadow_size = 10
	estilo.content_margin_left = 18.0
	estilo.content_margin_right = 18.0
	estilo.content_margin_top = 14.0
	estilo.content_margin_bottom = 14.0
	_painel.add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.name = "Conteudo"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	_painel.add_child(vbox)

	var cabecalho := HBoxContainer.new()
	cabecalho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cabecalho)

	_label_titulo = Label.new()
	_label_titulo.text = "TAREFAS DO DIA 1"
	_label_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_titulo.add_theme_font_size_override("font_size", 16)
	_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
	cabecalho.add_child(_label_titulo)

	_label_periodo = Label.new()
	_label_periodo.text = "[ DIURNO ]"
	_label_periodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_periodo.add_theme_font_size_override("font_size", 12)
	_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_ERVA)
	cabecalho.add_child(_label_periodo)

	var sep_topo := HSeparator.new()
	sep_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TemaSurvivalHorror.aplicar_estilo_separador(sep_topo)
	vbox.add_child(sep_topo)

	_lista_container = VBoxContainer.new()
	_lista_container.name = "ItensTarefas"
	_lista_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_lista_container)

	var sep_rodape := HSeparator.new()
	sep_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TemaSurvivalHorror.aplicar_estilo_separador(sep_rodape)
	vbox.add_child(sep_rodape)

	_label_rodape = Label.new()
	_label_rodape.text = "[X] Ocultar lista"
	_label_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_rodape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_rodape.add_theme_font_size_override("font_size", 12)
	_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)
	vbox.add_child(_label_rodape)


func esta_aberta() -> bool:
	return _aberta


func alternar() -> void:
	if _aberta:
		fechar()
	else:
		abrir()


func abrir() -> void:
	atualizar_lista()
	_aberta = true
	visible = true

	if _tween_visibilidade and _tween_visibilidade.is_valid():
		_tween_visibilidade.kill()

	_painel.position.x = POS_X_BASE - 14.0
	_tween_visibilidade = create_tween().set_parallel(true)
	_tween_visibilidade.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_visibilidade.tween_property(_painel, "position:x", POS_X_BASE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func fechar() -> void:
	_aberta = false
	if _tween_visibilidade and _tween_visibilidade.is_valid():
		_tween_visibilidade.kill()

	_tween_visibilidade = create_tween().set_parallel(true)
	_tween_visibilidade.tween_property(self, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_visibilidade.tween_property(_painel, "position:x", POS_X_BASE - 10.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween_visibilidade.chain().tween_callback(func() -> void:
		if not _aberta:
			visible = false
	)


func atualizar_lista() -> void:
	if _lista_container == null:
		return

	for filho in _lista_container.get_children():
		filho.queue_free()

	var gerente := GameManager.instance
	var dia := gerente.dia_atual if gerente != null else 1
	var concluidas := gerente.tarefas_concluidas if gerente != null else 0
	var totais := gerente.tarefas_totais if gerente != null else 0
	var horario := gerente.horario_atual if gerente != null else 0

	_label_titulo.text = "TAREFAS DO DIA %d" % dia
	var hora_txt := gerente.obter_hora_formatada() if (gerente != null and gerente.has_method("obter_hora_formatada")) else "06:00"
	match horario:
		0:
			_label_periodo.text = "[ %s • DIURNO ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_ERVA)
		1:
			_label_periodo.text = "[ %s • VESPERTINO ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
		2:
			_label_periodo.text = "[ %s ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_DESTAQUE_VERMELHO)

	var itens := _coletar_tarefas_do_dia()
	if itens.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhuma tarefa registrada."
		vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vazio.add_theme_font_size_override("font_size", 14)
		vazio.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)
		_lista_container.add_child(vazio)
	else:
		for item in itens:
			_adicionar_linha_tarefa(item["nome"], item["concluida"])

	# Atualiza rodapé conforme conclusão das tarefas do dia e vigília
	if totais > 0 and concluidas >= totais:
		if gerente != null and gerente.exigir_conclusao_vigilia_para_dormir and gerente.modo_noturno == GameManager.ModoNoturno.VIGILIA_DOMESTICA and not gerente.vigilia_concluida:
			_label_rodape.text = "» Vigília (%ds): espione a janela, fusível ou rastros." % int(ceilf(gerente.tempo_vigilia_restante))
			_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
		else:
			_label_rodape.text = "» Todas concluídas! Volte para casa e durma na cama."
			_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_ERVA)
	else:
		var restantes := maxi(0, totais - concluidas)
		_label_rodape.text = "Pendentes: %d de %d   |   [X] Ocultar" % [restantes, totais]
		_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)


func _coletar_tarefas_do_dia() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var tree := get_tree()
	if tree == null:
		return resultado

	var nos := tree.get_nodes_in_group("tarefas")
	for no in nos:
		if not is_instance_valid(no):
			continue
		var nome := str(no.name)
		if "nome_exibicao" in no and not str(no.get("nome_exibicao")).is_empty():
			nome = str(no.get("nome_exibicao"))
		elif "prompt_interacao" in no and not str(no.get("prompt_interacao")).is_empty():
			nome = str(no.get("prompt_interacao"))

		var feita := false
		if "concluida" in no:
			feita = bool(no.get("concluida"))
		elif "ja_usado" in no:
			feita = bool(no.get("ja_usado"))

		resultado.append({"nome": nome, "concluida": feita})

	return resultado


func _adicionar_linha_tarefa(nome: String, concluida: bool) -> void:
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 8)
	_lista_container.add_child(linha)

	var marcador := Label.new()
	marcador.text = "[ X ]" if concluida else "[   ]"
	marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.add_theme_font_size_override("font_size", 14)
	marcador.add_theme_color_override(
		"font_color",
		TemaSurvivalHorror.COR_STATUS_ERVA if concluida else TemaSurvivalHorror.COR_BORDA_VERMELHA
	)
	linha.add_child(marcador)

	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override(
		"font_color",
		TemaSurvivalHorror.COR_TEXTO_APAGADO if concluida else TemaSurvivalHorror.COR_TEXTO_NORMAL
	)
	linha.add_child(rotulo)
