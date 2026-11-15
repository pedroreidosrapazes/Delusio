class_name PainelSequenciaInteracao
extends Control

## UI e feedback sonoro/visual para o minigame de sequência direcional.

class SlotDirecao extends Control:
	var direcao: int = 0
	var estado: int = 0 # 0 = pendente, 1 = atual, 2 = acertado, 3 = erro

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg_col := Color(0.08, 0.1, 0.14, 0.85)
		var border_col := Color(0.3, 0.35, 0.42, 0.8)
		var arrow_col := Color(0.5, 0.55, 0.62, 0.5)
		var borda_espessura := 1.5

		if estado == 2: # Acertado
			bg_col = Color(0.08, 0.25, 0.12, 0.9)
			border_col = Color(0.2, 0.85, 0.35, 1.0)
			arrow_col = Color(0.3, 0.95, 0.45, 1.0)
			borda_espessura = 2.0
		elif estado == 1: # Atual
			bg_col = Color(0.24, 0.2, 0.06, 0.95)
			border_col = Color(1.0, 0.82, 0.25, 1.0)
			arrow_col = Color(1.0, 0.9, 0.35, 1.0)
			borda_espessura = 2.5
		elif estado == 3: # Erro
			bg_col = Color(0.35, 0.08, 0.08, 0.95)
			border_col = Color(1.0, 0.25, 0.25, 1.0)
			arrow_col = Color(1.0, 0.35, 0.35, 1.0)
			borda_espessura = 2.5

		draw_rect(r, bg_col, true)
		draw_rect(r, border_col, false, borda_espessura)

		_desenhar_seta(size * 0.5, size.x * 0.28, direcao, arrow_col)

	func _desenhar_seta(centro: Vector2, raio: float, dir: int, cor: Color) -> void:
		var h := raio
		var w := raio * 0.75
		var p_stem := w * 0.4
		var p_neck := -h * 0.15

		var pts_up := PackedVector2Array([
			Vector2(0, -h),
			Vector2(w, p_neck),
			Vector2(p_stem, p_neck),
			Vector2(p_stem, h),
			Vector2(-p_stem, h),
			Vector2(-p_stem, p_neck),
			Vector2(-w, p_neck)
		])

		var angulo := 0.0
		match dir:
			SequenciaDirecionalDesafio.Direcao.CIMA:
				angulo = 0.0
			SequenciaDirecionalDesafio.Direcao.DIREITA:
				angulo = PI * 0.5
			SequenciaDirecionalDesafio.Direcao.BAIXO:
				angulo = PI
			SequenciaDirecionalDesafio.Direcao.ESQUERDA:
				angulo = -PI * 0.5

		var rotacionados := PackedVector2Array()
		for p in pts_up:
			rotacionados.append(centro + p.rotated(angulo))

		draw_colored_polygon(rotacionados, cor)


var _painel_container: PanelContainer
var _estilo_painel: StyleBoxFlat
var _label_titulo: Label
var _label_contador: Label
var _label_status: Label
var _barra_tempo: ProgressBar
var _label_tempo: Label
var _container_slots: HBoxContainer
var _label_dica: Label
var _audio_player: AudioStreamPlayer

var _sequencia_atual: Array[int] = []
var _indice_atual: int = 0
var _tempo_limite: float = 6.0
var _slots_ui: Array[SlotDirecao] = []

var _tremor_tempo: float = 0.0
var _flash_vermelho_tempo: float = 0.0
var _flash_estava_ativo: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE

	_criar_ui()
	_criar_audio()


func _criar_ui() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.68
	anchor_bottom = 0.68
	offset_left = -230.0
	offset_right = 230.0
	offset_top = -95.0
	offset_bottom = 95.0
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH

	_painel_container = PanelContainer.new()
	_painel_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_painel_container.mouse_filter = MOUSE_FILTER_IGNORE

	_estilo_painel = StyleBoxFlat.new()
	_estilo_painel.bg_color = Color(0.04, 0.05, 0.08, 0.90)
	_estilo_painel.set_border_width_all(2)
	_estilo_painel.border_color = Color(0.35, 0.4, 0.48, 0.8)
	_estilo_painel.set_corner_radius_all(8)
	_estilo_painel.content_margin_left = 16.0
	_estilo_painel.content_margin_right = 16.0
	_estilo_painel.content_margin_top = 10.0
	_estilo_painel.content_margin_bottom = 10.0
	_painel_container.add_theme_stylebox_override("panel", _estilo_painel)
	add_child(_painel_container)

	var raiz_vbox := VBoxContainer.new()
	raiz_vbox.add_theme_constant_override("separation", 6)
	raiz_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	_painel_container.add_child(raiz_vbox)

	# Linha Superior (Título + Contador)
	var linha_topo := HBoxContainer.new()
	linha_topo.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(linha_topo)

	_label_titulo = Label.new()
	_label_titulo.text = "Tarefa"
	_label_titulo.size_flags_horizontal = SIZE_EXPAND_FILL
	_label_titulo.add_theme_font_size_override("font_size", 15)
	_label_titulo.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	linha_topo.add_child(_label_titulo)

	_label_contador = Label.new()
	_label_contador.text = "0 / 4"
	_label_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_contador.add_theme_font_size_override("font_size", 15)
	_label_contador.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	linha_topo.add_child(_label_contador)

	# Linha de Status / Feedback de Erro
	_label_status = Label.new()
	_label_status.text = "Pressione as direções indicadas"
	_label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_status.add_theme_font_size_override("font_size", 12)
	_label_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	raiz_vbox.add_child(_label_status)

	# Linha de Tempo (Barra + Label numérico)
	var linha_tempo := HBoxContainer.new()
	linha_tempo.add_theme_constant_override("separation", 8)
	linha_tempo.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(linha_tempo)

	_barra_tempo = ProgressBar.new()
	_barra_tempo.custom_minimum_size = Vector2(0, 8.0)
	_barra_tempo.size_flags_horizontal = SIZE_EXPAND_FILL
	_barra_tempo.size_flags_vertical = SIZE_SHRINK_CENTER
	_barra_tempo.show_percentage = false
	_barra_tempo.max_value = 1.0
	_barra_tempo.value = 1.0
	linha_tempo.add_child(_barra_tempo)

	_label_tempo = Label.new()
	_label_tempo.text = "6.0s"
	_label_tempo.custom_minimum_size = Vector2(40.0, 0)
	_label_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_tempo.add_theme_font_size_override("font_size", 12)
	_label_tempo.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	linha_tempo.add_child(_label_tempo)

	# Container dos Slots de Direção
	_container_slots = HBoxContainer.new()
	_container_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_container_slots.add_theme_constant_override("separation", 8)
	_container_slots.custom_minimum_size = Vector2(0, 44.0)
	_container_slots.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(_container_slots)

	# Rodapé de Dicas
	_label_dica = Label.new()
	_label_dica.text = "WASD ou Setas: Direção  |  Botão Direito / Backspace: Cancelar"
	_label_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_dica.add_theme_font_size_override("font_size", 11)
	_label_dica.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68, 0.8))
	raiz_vbox.add_child(_label_dica)


func _criar_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioDesafio"
	add_child(_audio_player)


func mostrar_sequencia(sequencia: Array[int], tempo_limite: float, titulo: String) -> void:
	_sequencia_atual = sequencia.duplicate()
	_tempo_limite = tempo_limite
	_indice_atual = 0

	_label_titulo.text = titulo if titulo != "" else "Desafio Direcional"
	_label_contador.text = "0 / %d" % _sequencia_atual.size()
	_label_status.text = "Pressione as direções indicadas"
	_label_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))

	_reconstruir_slots()
	atualizar_tempo(tempo_limite, tempo_limite)

	_tremor_tempo = 0.0
	_flash_vermelho_tempo = 0.0
	_flash_estava_ativo = false
	if _painel_container:
		_painel_container.position.x = 0.0
	_aplicar_estilo_borda(false)

	visible = true


func atualizar_passo(indice: int, total: int) -> void:
	_indice_atual = indice
	_label_contador.text = "%d / %d" % [indice, total]
	_atualizar_estados_slots()
	_tocar_som_acerto(indice)


func registrar_erro(motivo: String, nova_sequencia: Array[int], tempo_restante: float) -> void:
	_indice_atual = 0
	_sequencia_atual = nova_sequencia.duplicate()

	if motivo == "tempo_esgotado":
		_label_status.text = "Tempo esgotado! Sequência reiniciada"
	else:
		_label_status.text = "Tecla errada! Sequência alterada"
	_label_status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

	_label_contador.text = "0 / %d" % _sequencia_atual.size()

	_reconstruir_slots()
	for slot in _slots_ui:
		slot.estado = 3
		slot.queue_redraw()

	atualizar_tempo(tempo_restante, _tempo_limite)
	_disparar_tremor_e_flash()
	_tocar_som_erro()


func atualizar_tempo(restante: float, limite: float) -> void:
	var pct := clampf(restante / limite, 0.0, 1.0) if limite > 0.0 else 1.0
	_barra_tempo.value = pct
	_label_tempo.text = "%.1fs" % maxf(0.0, restante)

	var cor_tempo := Color(0.3, 0.9, 0.45)
	if pct < 0.25:
		cor_tempo = Color(1.0, 0.25, 0.25)
	elif pct < 0.5:
		cor_tempo = Color(1.0, 0.65, 0.2)
	_label_tempo.add_theme_color_override("font_color", cor_tempo)


func finalizar(sucesso: bool) -> void:
	if sucesso:
		_tocar_som_conclusao()
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	if _tremor_tempo > 0.0:
		_tremor_tempo = maxf(0.0, _tremor_tempo - delta)
		var desloc := sin(_tremor_tempo * 50.0) * 8.0 * (_tremor_tempo / 0.25)
		if _painel_container:
			_painel_container.position.x = desloc
	elif _painel_container:
		_painel_container.position.x = 0.0

	if _flash_vermelho_tempo > 0.0:
		_flash_vermelho_tempo = maxf(0.0, _flash_vermelho_tempo - delta)
		_flash_estava_ativo = true
		_aplicar_estilo_borda(true)
	else:
		_aplicar_estilo_borda(false)
		if _flash_estava_ativo:
			_flash_estava_ativo = false
			_atualizar_estados_slots()


func _disparar_tremor_e_flash() -> void:
	_tremor_tempo = 0.25
	_flash_vermelho_tempo = 0.25
	_flash_estava_ativo = true


func _aplicar_estilo_borda(vermelho: bool) -> void:
	if _estilo_painel == null:
		return
	if vermelho:
		_estilo_painel.border_color = Color(1.0, 0.25, 0.25, 1.0)
	else:
		_estilo_painel.border_color = Color(0.35, 0.4, 0.48, 0.8)


func _reconstruir_slots() -> void:
	for slot in _slots_ui:
		slot.queue_free()
	_slots_ui.clear()

	for i in range(_sequencia_atual.size()):
		var slot := SlotDirecao.new()
		slot.custom_minimum_size = Vector2(42.0, 42.0)
		slot.direcao = _sequencia_atual[i]
		slot.estado = 1 if i == 0 else 0
		slot.mouse_filter = MOUSE_FILTER_IGNORE
		_container_slots.add_child(slot)
		_slots_ui.append(slot)


func _atualizar_estados_slots() -> void:
	for i in range(_slots_ui.size()):
		var slot := _slots_ui[i]
		if i < _indice_atual:
			slot.estado = 2 # Acertado
		elif i == _indice_atual:
			slot.estado = 1 # Atual
		else:
			slot.estado = 0 # Pendente
		slot.queue_redraw()


# Sons Procedurais em AudioStreamWAV gerados em memória
func _gerar_audio_stream(frequencias: Array[float], duracao: float, decaimento: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var total_amostras := int(duracao * mix_rate)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false

	var dados := PackedByteArray()
	dados.resize(total_amostras * 2)

	for i in range(total_amostras):
		var t := float(i) / mix_rate
		var envelope := exp(-decaimento * t)
		var val := 0.0
		for freq in frequencias:
			val += sin(TAU * freq * t)
		val = (val / float(maxi(1, frequencias.size()))) * envelope * 0.35
		var int_val := int(clampf(val, -1.0, 1.0) * 32767.0)
		dados.encode_s16(i * 2, int_val)

	stream.data = dados
	return stream


func _tocar_som_acerto(passo: int) -> void:
	if _audio_player == null:
		return
	var freq := 440.0 * pow(1.08, float(passo))
	var stream := _gerar_audio_stream([freq], 0.12, 12.0)
	_audio_player.stream = stream
	_audio_player.play()


func _tocar_som_erro() -> void:
	if _audio_player == null:
		return
	var stream := _gerar_audio_stream([140.0, 148.0], 0.28, 6.0)
	_audio_player.stream = stream
	_audio_player.play()


func _tocar_som_conclusao() -> void:
	if _audio_player == null:
		return
	var stream := _gerar_audio_stream([523.25, 659.25, 783.99], 0.35, 5.0)
	_audio_player.stream = stream
	_audio_player.play()
