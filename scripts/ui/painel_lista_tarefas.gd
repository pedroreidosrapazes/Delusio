class_name PainelListaTarefas
extends Control

## Painel retrátil de Lista de Tarefas sobre o Caderno Dobrado 3D (acionado pela tecla X).
## Sobe a partir da borda inferior esquerda da tela com texto em tinta escura alinhado à página.

const CENA_CADERNO_DOBRADO: PackedScene = preload("res://assets/ui/caderno_dobrado_tasks.glb")
const POS_X_BASE := 30.0
const LARGURA_CADERNO := 316.0
const ALTURA_CADERNO := 440.0

var _painel: Control
var _cartao_caderno: Control
var _sub_viewport: SubViewport
var _pivot_caderno: Node3D
var _conteudo_folha: MarginContainer
var _label_titulo: Label
var _label_periodo: Label
var _lista_container: VBoxContainer
var _label_rodape: Label
var _tween_visibilidade: Tween
var _aberta: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_construir_interface()


func _construir_interface() -> void:
	_cartao_caderno = Control.new()
	_cartao_caderno.name = "PainelTarefasFundo"
	_cartao_caderno.size = Vector2(LARGURA_CADERNO, ALTURA_CADERNO)
	_cartao_caderno.pivot_offset = Vector2(LARGURA_CADERNO * 0.5, ALTURA_CADERNO)
	_cartao_caderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cartao_caderno)
	_painel = _cartao_caderno

	var vp_container := SubViewportContainer.new()
	vp_container.name = "CadernoViewportContainer"
	vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao_caderno.add_child(vp_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "SubViewportCaderno"
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_sub_viewport.msaa_3d = Viewport.MSAA_2X
	_sub_viewport.size = Vector2i(int(LARGURA_CADERNO), int(ALTURA_CADERNO))
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	vp_container.add_child(_sub_viewport)

	var cena_3d := Node3D.new()
	cena_3d.name = "CenaCaderno3D"
	_sub_viewport.add_child(cena_3d)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.81, 0.73, 1.0)
	env.ambient_light_energy = 0.56
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	cena_3d.add_child(world_env)

	var luz_frente := DirectionalLight3D.new()
	luz_frente.name = "LuzPrincipalCaderno"
	luz_frente.rotation_degrees = Vector3(-26.0, 18.0, 0.0)
	luz_frente.light_color = Color(1.0, 0.96, 0.89, 1.0)
	luz_frente.light_energy = 1.15
	luz_frente.shadow_enabled = false
	cena_3d.add_child(luz_frente)

	var luz_recorte := DirectionalLight3D.new()
	luz_recorte.name = "LuzRecorteCaderno"
	luz_recorte.rotation_degrees = Vector3(15.0, -140.0, 0.0)
	luz_recorte.light_color = Color(0.76, 0.84, 0.95, 1.0)
	luz_recorte.light_energy = 0.30
	luz_recorte.shadow_enabled = false
	cena_3d.add_child(luz_recorte)

	var cam := Camera3D.new()
	cam.name = "CameraCaderno"
	cam.fov = 30.0
	cam.near = 0.05
	cam.position = Vector3(0.06, 0.0, 3.65)
	cam.current = true
	cena_3d.add_child(cam)

	_pivot_caderno = Node3D.new()
	_pivot_caderno.name = "PivotCaderno"
	cena_3d.add_child(_pivot_caderno)

	var instancia := CENA_CADERNO_DOBRADO.instantiate() as Node3D
	if instancia != null:
		instancia.name = "CadernoDobradoModelo"
		_pivot_caderno.add_child(instancia)

	_conteudo_folha = MarginContainer.new()
	_conteudo_folha.name = "ConteudoFolha"
	_conteudo_folha.anchor_left = 0.135
	_conteudo_folha.anchor_top = 0.105
	_conteudo_folha.anchor_right = 0.715
	_conteudo_folha.anchor_bottom = 0.895
	_conteudo_folha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conteudo_folha.add_theme_constant_override("margin_left", 6)
	_conteudo_folha.add_theme_constant_override("margin_top", 6)
	_conteudo_folha.add_theme_constant_override("margin_right", 6)
	_conteudo_folha.add_theme_constant_override("margin_bottom", 6)
	_cartao_caderno.add_child(_conteudo_folha)

	var vbox := VBoxContainer.new()
	vbox.name = "Conteudo"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	_conteudo_folha.add_child(vbox)

	_label_titulo = Label.new()
	_label_titulo.text = "TAREFAS DO DIA 1"
	_label_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_titulo.add_theme_font_size_override("font_size", 15)
	_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_VERMELHO)
	vbox.add_child(_label_titulo)

	_label_periodo = Label.new()
	_label_periodo.text = "[ 06:00 • DIURNO ]"
	_label_periodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_periodo.add_theme_font_size_override("font_size", 11)
	_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_ERVA)
	vbox.add_child(_label_periodo)

	var sep_topo := HSeparator.new()
	sep_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TemaSurvivalHorror.aplicar_estilo_separador_papel(sep_topo)
	vbox.add_child(sep_topo)

	_lista_container = VBoxContainer.new()
	_lista_container.name = "ItensTarefas"
	_lista_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_container.add_theme_constant_override("separation", 7)
	vbox.add_child(_lista_container)

	var sep_rodape := HSeparator.new()
	sep_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TemaSurvivalHorror.aplicar_estilo_separador_papel(sep_rodape)
	vbox.add_child(sep_rodape)

	_label_rodape = Label.new()
	_label_rodape.text = "[X] Ocultar caderno"
	_label_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_rodape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_rodape.add_theme_font_size_override("font_size", 11)
	_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_TINTA_SUAVE)
	vbox.add_child(_label_rodape)


func _calcular_posicoes_caderno() -> Dictionary:
	var alt_vp: float = get_viewport_rect().size.y if is_inside_tree() else 648.0
	if alt_vp <= 10.0:
		alt_vp = 648.0
	var y_visivel: float = clampf(alt_vp - ALTURA_CADERNO - 118.0, 90.0, maxf(90.0, alt_vp - ALTURA_CADERNO - 24.0))
	var y_oculto: float = alt_vp + 36.0
	return {"x": POS_X_BASE, "y_visivel": y_visivel, "y_oculto": y_oculto}


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

	var pos_cfg: Dictionary = _calcular_posicoes_caderno()
	var pos_x: float = float(pos_cfg["x"])
	var y_visivel: float = float(pos_cfg["y_visivel"])
	var y_oculto: float = float(pos_cfg["y_oculto"])

	if DisplayServer.get_name() == "headless":
		_cartao_caderno.position = Vector2(pos_x, y_visivel)
		_cartao_caderno.rotation_degrees = 0.0
		if _pivot_caderno != null:
			_pivot_caderno.rotation_degrees = Vector3.ZERO
		modulate.a = 1.0
		return

	if is_inside_tree():
		BancoAudioDelusio.tocar_2d(self, &"papel_abrir", -7.0, 0.06)

	_cartao_caderno.position = Vector2(pos_x, y_oculto)
	_cartao_caderno.rotation_degrees = -3.5
	if _pivot_caderno != null:
		_pivot_caderno.rotation_degrees = Vector3(14.0, 0.0, 0.0)
	modulate.a = 0.0

	_tween_visibilidade = create_tween().set_parallel(true)
	_tween_visibilidade.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_visibilidade.tween_property(_cartao_caderno, "position:y", y_visivel, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_visibilidade.tween_property(_cartao_caderno, "rotation_degrees", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _pivot_caderno != null:
		_tween_visibilidade.tween_property(_pivot_caderno, "rotation_degrees:x", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func fechar() -> void:
	_aberta = false
	if _tween_visibilidade and _tween_visibilidade.is_valid():
		_tween_visibilidade.kill()

	if DisplayServer.get_name() == "headless":
		modulate.a = 0.0
		visible = false
		return

	if is_inside_tree():
		BancoAudioDelusio.tocar_2d(self, &"papel_fechar", -7.0, 0.06)

	var pos_cfg: Dictionary = _calcular_posicoes_caderno()
	var y_oculto: float = float(pos_cfg["y_oculto"])

	_tween_visibilidade = create_tween().set_parallel(true)
	_tween_visibilidade.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_visibilidade.tween_property(_cartao_caderno, "position:y", y_oculto, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween_visibilidade.tween_property(_cartao_caderno, "rotation_degrees", -3.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _pivot_caderno != null:
		_tween_visibilidade.tween_property(_pivot_caderno, "rotation_degrees:x", 12.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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
	var dia: int = gerente.dia_atual if gerente != null else 1
	var concluidas: int = gerente.tarefas_concluidas if gerente != null else 0
	var totais: int = gerente.tarefas_totais if gerente != null else 0
	var horario: int = gerente.horario_atual if gerente != null else 0

	_label_titulo.text = "TAREFAS DO DIA %d" % dia
	var hora_txt: String = gerente.obter_hora_formatada() if (gerente != null and gerente.has_method("obter_hora_formatada")) else "06:00"
	match horario:
		0:
			_label_periodo.text = "[ %s • DIURNO ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_ERVA)
		1:
			_label_periodo.text = "[ %s • VESPERTINO ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_AMBAR)
		2:
			_label_periodo.text = "[ %s • NOTURNO ]" % hora_txt
			_label_periodo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_VERMELHO)

	var itens := _coletar_tarefas_do_dia()
	if itens.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhuma tarefa registrada."
		vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vazio.add_theme_font_size_override("font_size", 12)
		vazio.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_TINTA_SUAVE)
		_lista_container.add_child(vazio)
	else:
		for item in itens:
			_adicionar_linha_tarefa(item["nome"], item["concluida"])

	if totais > 0 and concluidas >= totais:
		if gerente != null and gerente.exigir_conclusao_vigilia_para_dormir and gerente.modo_noturno == GameManager.ModoNoturno.VIGILIA_DOMESTICA and not gerente.vigilia_concluida:
			_label_rodape.text = "» Vigília (%ds): janela, fusível ou rastros." % int(ceilf(gerente.tempo_vigilia_restante))
			_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_AMBAR)
		else:
			_label_rodape.text = "» Tudo pronto! Volte e durma na cama."
			_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_ERVA)
	else:
		var restantes: int = maxi(0, totais - concluidas)
		_label_rodape.text = "Pendentes: %d de %d  |  [X] Ocultar" % [restantes, totais]
		_label_rodape.add_theme_color_override("font_color", TemaSurvivalHorror.COR_PAPEL_TINTA_SUAVE)


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
	linha.add_theme_constant_override("separation", 6)
	_lista_container.add_child(linha)

	var marcador := Label.new()
	marcador.text = "[ X ]" if concluida else "[   ]"
	marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.add_theme_font_size_override("font_size", 12)
	marcador.add_theme_color_override(
		"font_color",
		TemaSurvivalHorror.COR_PAPEL_ERVA if concluida else TemaSurvivalHorror.COR_PAPEL_VERMELHO
	)
	linha.add_child(marcador)

	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", 12)
	rotulo.add_theme_color_override(
		"font_color",
		TemaSurvivalHorror.COR_PAPEL_TINTA_SUAVE if concluida else TemaSurvivalHorror.COR_PAPEL_TINTA
	)
	linha.add_child(rotulo)
