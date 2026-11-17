class_name PainelSequenciaInteracao
extends Control

## UI e feedback sonoro/visual para o minigame de sequência direcional.
## Visual Híbrido Tático Carvão-Carmesim unificado com TemaSurvivalHorror.

const CAMINHO_TEXTURA_SETA := "res://assets/ui/seta_estilizada_delusio.png"
const CAMINHO_FONTE_BOLD := "res://assets/fonts/Delusio-Bold.ttf"

const TAMANHO_SLOT_PADRAO := Vector2(48.0, 48.0)
const TAMANHO_SLOT_COMPACTO := Vector2(44.0, 44.0)
const SEPARACAO_SLOTS := 6
const DURACAO_FLASH_ERRO := 0.22
const DURACAO_STATUS_ERRO := 1.35

## Acento pontual em ouro envelhecido reservado ao filete interno do slot atual e destaque do cabeçalho/contador.
const COR_OURO_DELUSIO := Color("#bfa269")


class SlotDirecao extends Control:
	var direcao: int = 0
	var estado: int = 0 # 0 = pendente, 1 = atual, 2 = acertado, 3 = erro

	var _tween_pulso: Tween = null

	static var _pontos_seta_borda := PackedVector2Array([
		Vector2(0.0, -1.0),
		Vector2(0.5336, -0.14),
		Vector2(0.8832, -0.42),
		Vector2(0.7360, 0.04),
		Vector2(0.4232, 0.22),
		Vector2(0.2024, 0.06),
		Vector2(0.2024, 0.78),
		Vector2(0.4232, 1.0),
		Vector2(-0.4232, 1.0),
		Vector2(-0.2024, 0.78),
		Vector2(-0.2024, 0.06),
		Vector2(-0.4232, 0.22),
		Vector2(-0.7360, 0.04),
		Vector2(-0.8832, -0.42),
		Vector2(-0.5336, -0.14)
	])

	static var _pontos_seta_miolo := PackedVector2Array([
		Vector2(0.0, -0.72),
		Vector2(0.3864, -0.06),
		Vector2(0.0920, -0.08),
		Vector2(0.0920, 0.84),
		Vector2(-0.0920, 0.84),
		Vector2(-0.0920, -0.08),
		Vector2(-0.3864, -0.06)
	])

	static var _textura_seta_original: Texture2D = null
	static var _textura_seta_pendente: Texture2D = null
	static var _textura_seta_acertado: Texture2D = null
	static var _texturas_tentou_carregar: bool = false

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _ready() -> void:
		_atualizar_pivot()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_atualizar_pivot()

	func _atualizar_pivot() -> void:
		var base_sz := size if (size.x > 0.0 and size.y > 0.0) else custom_minimum_size
		pivot_offset = base_sz * 0.5

	func parar_animacao() -> void:
		if _tween_pulso != null and _tween_pulso.is_valid():
			_tween_pulso.kill()
		_tween_pulso = null
		scale = Vector2.ONE

	func animar_pulso(escala_pico: float, duracao: float, escala_inicial: float = -1.0) -> void:
		parar_animacao()
		if not is_inside_tree():
			return
		_atualizar_pivot()
		_tween_pulso = create_tween()
		_tween_pulso.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if escala_inicial > 0.0:
			scale = Vector2(escala_inicial, escala_inicial)
			_tween_pulso.tween_property(self, "scale", Vector2(escala_pico, escala_pico), duracao * 0.5)
			_tween_pulso.tween_property(self, "scale", Vector2.ONE, duracao * 0.5)
		else:
			scale = Vector2(escala_pico, escala_pico)
			_tween_pulso.tween_property(self, "scale", Vector2.ONE, duracao)

	static func _garantir_texturas_carregadas() -> void:
		if _texturas_tentou_carregar:
			return
		_texturas_tentou_carregar = true

		var img_base: Image = null
		if ResourceLoader.exists(CAMINHO_TEXTURA_SETA):
			var res := load(CAMINHO_TEXTURA_SETA)
			if res is Texture2D:
				_textura_seta_original = res as Texture2D
				img_base = _textura_seta_original.get_image()

		if img_base == null or img_base.is_empty():
			var caminho_abs := ProjectSettings.globalize_path(CAMINHO_TEXTURA_SETA)
			if FileAccess.file_exists(CAMINHO_TEXTURA_SETA) or FileAccess.file_exists(caminho_abs):
				var img_arquivo := Image.load_from_file(caminho_abs)
				if img_arquivo != null and not img_arquivo.is_empty():
					img_base = img_arquivo
					var img_orig := img_base.duplicate()
					if img_orig.is_compressed():
						img_orig.decompress()
					img_orig.clear_mipmaps()
					img_orig.generate_mipmaps()
					_textura_seta_original = ImageTexture.create_from_image(img_orig)

		if img_base == null or img_base.is_empty():
			return

		if img_base.is_compressed():
			img_base.decompress()
		if img_base.get_format() != Image.FORMAT_RGBA8:
			img_base.convert(Image.FORMAT_RGBA8)
		img_base.clear_mipmaps()

		_textura_seta_pendente = _criar_variante_osso_frio(img_base)
		_textura_seta_acertado = _criar_variante_dessaturada_suave(img_base)

	static func _criar_variante_osso_frio(img_base: Image) -> Texture2D:
		var w := img_base.get_width()
		var h := img_base.get_height()
		var dados := img_base.get_data()
		for i in range(0, dados.size(), 4):
			if dados[i + 3] == 0:
				continue
			var r := float(dados[i]) / 255.0
			var g := float(dados[i + 1]) / 255.0
			var b := float(dados[i + 2]) / 255.0
			var lum := 0.2126 * r + 0.7152 * g + 0.0722 * b
			# Realça faixa média para preservar nitidez das bordas em tom osso-frio sem escurecer em marrom.
			var lum_osso := lerpf(0.22, 0.96, pow(clampf(lum, 0.0, 1.0), 0.78))
			dados[i] = int(clampf(lum_osso * 0.92, 0.0, 1.0) * 255.0)
			dados[i + 1] = int(clampf(lum_osso * 0.95, 0.0, 1.0) * 255.0)
			dados[i + 2] = int(clampf(lum_osso * 1.00, 0.0, 1.0) * 255.0)

		var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, dados)
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)

	static func _criar_variante_dessaturada_suave(img_base: Image) -> Texture2D:
		var w := img_base.get_width()
		var h := img_base.get_height()
		var dados := img_base.get_data()
		for i in range(0, dados.size(), 4):
			if dados[i + 3] == 0:
				continue
			var r := float(dados[i]) / 255.0
			var g := float(dados[i + 1]) / 255.0
			var b := float(dados[i + 2]) / 255.0
			var lum := 0.2126 * r + 0.7152 * g + 0.0722 * b
			dados[i] = int(clampf(lerpf(r, lum * 0.90, 0.62), 0.0, 1.0) * 255.0)
			dados[i + 1] = int(clampf(lerpf(g, lum * 0.97, 0.62), 0.0, 1.0) * 255.0)
			dados[i + 2] = int(clampf(lerpf(b, lum * 0.92, 0.62), 0.0, 1.0) * 255.0)

		var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, dados)
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)

	static func obter_textura_estado(est: int) -> Texture2D:
		_garantir_texturas_carregadas()
		match est:
			0:
				return _textura_seta_pendente if _textura_seta_pendente != null else _textura_seta_original
			2:
				return _textura_seta_acertado if _textura_seta_acertado != null else _textura_seta_original
			_:
				return _textura_seta_original

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg_col := Color(0.071, 0.071, 0.082, 0.88)
		var border_col := TemaSurvivalHorror.COR_DIVISORIA
		var arrow_col := Color(1.0, 1.0, 1.0, 0.38)
		var borda_espessura := 1.5
		var escala_seta := 0.78

		if estado == 1: # Atual
			bg_col = Color(0.14, 0.06, 0.06, 0.96)
			border_col = TemaSurvivalHorror.COR_BORDA_VERMELHA
			arrow_col = Color.WHITE
			borda_espessura = 2.2
			escala_seta = 0.90
		elif estado == 2: # Acertado
			bg_col = Color(0.08, 0.13, 0.10, 0.92)
			border_col = TemaSurvivalHorror.COR_STATUS_ERVA
			arrow_col = Color(1.0, 1.0, 1.0, 0.72)
			borda_espessura = 2.0
		elif estado == 3: # Erro
			bg_col = Color(0.28, 0.05, 0.05, 0.96)
			border_col = TemaSurvivalHorror.COR_BORDA_VERMELHA
			arrow_col = Color(1.0, 0.72, 0.72, 1.0)
			borda_espessura = 2.2

		_desenhar_slot_chanfrado(r, 5.0, bg_col, border_col, borda_espessura)
		if estado == 1:
			_desenhar_moldura_interna_ouro(r)

		var centro := size * 0.5
		var angulo := _angulo_direcao(direcao)
		var tex := obter_textura_estado(estado)
		if tex != null:
			var lado := minf(size.x, size.y) * escala_seta
			var size_vec := Vector2(lado, lado)
			var half := size_vec * 0.5
			draw_set_transform(centro, angulo)
			draw_texture_rect(tex, Rect2(-half, size_vec), false, arrow_col)
			draw_set_transform(Vector2.ZERO, 0.0)
		else:
			_desenhar_seta_poligonal(centro, minf(size.x, size.y) * escala_seta * 0.46, angulo, arrow_col)

	func _criar_pontos_chanfrados(r: Rect2, chanfro: float) -> PackedVector2Array:
		var x0 := r.position.x + 0.5
		var y0 := r.position.y + 0.5
		var x1 := r.end.x - 0.5
		var y1 := r.end.y - 0.5
		var c := minf(chanfro, minf(r.size.x, r.size.y) * 0.25)

		return PackedVector2Array([
			Vector2(x0 + c, y0),
			Vector2(x1 - c, y0),
			Vector2(x1, y0 + c),
			Vector2(x1, y1 - c),
			Vector2(x1 - c, y1),
			Vector2(x0 + c, y1),
			Vector2(x0, y1 - c),
			Vector2(x0, y0 + c)
		])

	func _desenhar_slot_chanfrado(
		r: Rect2,
		chanfro: float,
		bg_col: Color,
		border_col: Color,
		borda_espessura: float
	) -> void:
		var pts := _criar_pontos_chanfrados(r, chanfro)
		draw_colored_polygon(pts, bg_col)

		var borda_pts := PackedVector2Array(pts)
		borda_pts.append(pts[0])
		draw_polyline(borda_pts, border_col, borda_espessura, true)

	func _desenhar_moldura_interna_ouro(r: Rect2) -> void:
		var r_interno := r.grow(-3.0)
		var pts_interno := _criar_pontos_chanfrados(r_interno, 3.5)
		var borda_interna := PackedVector2Array(pts_interno)
		borda_interna.append(pts_interno[0])
		draw_polyline(borda_interna, Color(COR_OURO_DELUSIO.r, COR_OURO_DELUSIO.g, COR_OURO_DELUSIO.b, 0.58), 1.0, true)

		var inset := 3.5
		var comp := 4.5
		var x0 := r.position.x + inset
		var y0 := r.position.y + inset
		var x1 := r.end.x - inset
		var y1 := r.end.y - inset
		var cor_marca := Color(COR_OURO_DELUSIO.r, COR_OURO_DELUSIO.g, COR_OURO_DELUSIO.b, 0.95)

		draw_line(Vector2(x0, y0 + comp), Vector2(x0, y0), cor_marca, 1.5, true)
		draw_line(Vector2(x0, y0), Vector2(x0 + comp, y0), cor_marca, 1.5, true)

		draw_line(Vector2(x1 - comp, y0), Vector2(x1, y0), cor_marca, 1.5, true)
		draw_line(Vector2(x1, y0), Vector2(x1, y0 + comp), cor_marca, 1.5, true)

		draw_line(Vector2(x1, y1 - comp), Vector2(x1, y1), cor_marca, 1.5, true)
		draw_line(Vector2(x1, y1), Vector2(x1 - comp, y1), cor_marca, 1.5, true)

		draw_line(Vector2(x0 + comp, y1), Vector2(x0, y1), cor_marca, 1.5, true)
		draw_line(Vector2(x0, y1), Vector2(x0, y1 - comp), cor_marca, 1.5, true)

	func _angulo_direcao(dir: int) -> float:
		match dir:
			SequenciaDirecionalDesafio.Direcao.CIMA:
				return 0.0
			SequenciaDirecionalDesafio.Direcao.DIREITA:
				return PI * 0.5
			SequenciaDirecionalDesafio.Direcao.BAIXO:
				return PI
			SequenciaDirecionalDesafio.Direcao.ESQUERDA:
				return -PI * 0.5
			_:
				return 0.0

	func _desenhar_seta_poligonal(centro: Vector2, raio: float, angulo: float, cor: Color) -> void:
		draw_set_transform(centro, angulo, Vector2(raio, raio))
		draw_colored_polygon(_pontos_seta_borda, cor)
		var cor_miolo := Color(
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.r * cor.r,
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.g * cor.g,
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.b * cor.b,
			cor.a
		)
		draw_colored_polygon(_pontos_seta_miolo, cor_miolo)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _painel_container: PanelContainer
var _estilo_painel: StyleBoxFlat
var _estilo_barra_fill: StyleBoxFlat
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
var _status_erro_tempo: float = 0.0
var _pct_tempo_atual: float = 1.0
var _tempo_acumulado: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE

	_criar_ui()
	_criar_audio()


func _obter_fonte_bold() -> Font:
	if ResourceLoader.exists(CAMINHO_FONTE_BOLD):
		var res := load(CAMINHO_FONTE_BOLD)
		if res is Font:
			return res as Font
	return null


func _obter_tamanho_slot(qtd: int) -> Vector2:
	return TAMANHO_SLOT_PADRAO if qtd < 8 else TAMANHO_SLOT_COMPACTO


func _criar_ui() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.62
	anchor_bottom = 0.62
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH
	_atualizar_dimensoes_painel()

	var fonte_bold := _obter_fonte_bold()

	_painel_container = PanelContainer.new()
	_painel_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_painel_container.mouse_filter = MOUSE_FILTER_IGNORE

	_estilo_painel = StyleBoxFlat.new()
	_estilo_painel.bg_color = Color(
		TemaSurvivalHorror.COR_FUNDO_PAINEL.r,
		TemaSurvivalHorror.COR_FUNDO_PAINEL.g,
		TemaSurvivalHorror.COR_FUNDO_PAINEL.b,
		0.92
	)
	_estilo_painel.set_border_width_all(1)
	_estilo_painel.border_width_left = 2
	_estilo_painel.border_color = Color(
		TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.r,
		TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.g,
		TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.b,
		0.65
	)
	_estilo_painel.set_corner_radius_all(3)
	_estilo_painel.shadow_color = Color(
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.r,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.g,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.b,
		0.84
	)
	_estilo_painel.shadow_size = 12
	_estilo_painel.content_margin_left = 16.0
	_estilo_painel.content_margin_right = 16.0
	_estilo_painel.content_margin_top = 12.0
	_estilo_painel.content_margin_bottom = 10.0
	_painel_container.add_theme_stylebox_override("panel", _estilo_painel)
	add_child(_painel_container)

	var raiz_vbox := VBoxContainer.new()
	raiz_vbox.add_theme_constant_override("separation", 6)
	raiz_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	_painel_container.add_child(raiz_vbox)

	# Linha Superior (Cabeçalho: Título + Contador com acento dourado pontual)
	var linha_topo := HBoxContainer.new()
	linha_topo.add_theme_constant_override("separation", 10)
	linha_topo.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(linha_topo)

	_label_titulo = Label.new()
	_label_titulo.text = "Tarefa"
	_label_titulo.size_flags_horizontal = SIZE_EXPAND_FILL
	_label_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if fonte_bold != null:
		_label_titulo.add_theme_font_override("font", fonte_bold)
	_label_titulo.add_theme_font_size_override("font_size", 17)
	_label_titulo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_ATIVO)
	_label_titulo.add_theme_color_override("font_outline_color", Color(TemaSurvivalHorror.COR_FUNDO_ABSOLUTO, 0.9))
	_label_titulo.add_theme_constant_override("outline_size", 2)
	linha_topo.add_child(_label_titulo)

	var moldura_contador := PanelContainer.new()
	moldura_contador.mouse_filter = MOUSE_FILTER_IGNORE
	var estilo_contador := StyleBoxFlat.new()
	estilo_contador.bg_color = Color(
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.r,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.g,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.b,
		0.72
	)
	estilo_contador.set_border_width_all(1)
	estilo_contador.border_color = Color(COR_OURO_DELUSIO.r, COR_OURO_DELUSIO.g, COR_OURO_DELUSIO.b, 0.45)
	estilo_contador.set_corner_radius_all(2)
	estilo_contador.content_margin_left = 8.0
	estilo_contador.content_margin_right = 8.0
	estilo_contador.content_margin_top = 1.0
	estilo_contador.content_margin_bottom = 1.0
	moldura_contador.add_theme_stylebox_override("panel", estilo_contador)
	linha_topo.add_child(moldura_contador)

	_label_contador = Label.new()
	_label_contador.text = "0 / 4"
	_label_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_contador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if fonte_bold != null:
		_label_contador.add_theme_font_override("font", fonte_bold)
	_label_contador.add_theme_font_size_override("font_size", 16)
	_label_contador.add_theme_color_override("font_color", COR_OURO_DELUSIO)
	_label_contador.add_theme_color_override("font_outline_color", Color(TemaSurvivalHorror.COR_FUNDO_ABSOLUTO, 0.9))
	_label_contador.add_theme_constant_override("outline_size", 2)
	moldura_contador.add_child(_label_contador)

	# Linha de Tempo estilo "Fio Carmesim" logo abaixo do cabeçalho
	var linha_tempo := HBoxContainer.new()
	linha_tempo.add_theme_constant_override("separation", 8)
	linha_tempo.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(linha_tempo)

	_barra_tempo = ProgressBar.new()
	_barra_tempo.custom_minimum_size = Vector2(0, 5.0)
	_barra_tempo.size_flags_horizontal = SIZE_EXPAND_FILL
	_barra_tempo.size_flags_vertical = SIZE_SHRINK_CENTER
	_barra_tempo.show_percentage = false
	_barra_tempo.max_value = 1.0
	_barra_tempo.value = 1.0
	var estilo_barra_bg := StyleBoxFlat.new()
	estilo_barra_bg.bg_color = Color(
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.r,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.g,
		TemaSurvivalHorror.COR_FUNDO_ABSOLUTO.b,
		0.90
	)
	estilo_barra_bg.set_border_width_all(0)
	estilo_barra_bg.set_corner_radius_all(1)
	_estilo_barra_fill = StyleBoxFlat.new()
	_estilo_barra_fill.bg_color = TemaSurvivalHorror.COR_DESTAQUE_VERMELHO
	_estilo_barra_fill.set_corner_radius_all(1)
	_barra_tempo.add_theme_stylebox_override("background", estilo_barra_bg)
	_barra_tempo.add_theme_stylebox_override("fill", _estilo_barra_fill)
	linha_tempo.add_child(_barra_tempo)

	_label_tempo = Label.new()
	_label_tempo.text = "6.0s"
	_label_tempo.custom_minimum_size = Vector2(38.0, 0)
	_label_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_tempo.add_theme_font_size_override("font_size", 12)
	_label_tempo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_NORMAL)
	linha_tempo.add_child(_label_tempo)

	# Linha de Alerta de Erro (oculta no estado normal)
	_label_status = Label.new()
	_label_status.text = ""
	_label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_status.add_theme_font_size_override("font_size", 12)
	_label_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_label_status.visible = false
	raiz_vbox.add_child(_label_status)

	# Container dos Slots de Direção
	_container_slots = HBoxContainer.new()
	_container_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_container_slots.add_theme_constant_override("separation", SEPARACAO_SLOTS)
	_container_slots.custom_minimum_size = Vector2(0, TAMANHO_SLOT_PADRAO.y)
	_container_slots.mouse_filter = MOUSE_FILTER_IGNORE
	raiz_vbox.add_child(_container_slots)

	# Rodapé compacto
	_label_dica = Label.new()
	_label_dica.text = "WASD / Setas  •  Botão Direito / Backspace: Cancelar"
	_label_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_dica.add_theme_font_size_override("font_size", 11)
	_label_dica.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_APAGADO)
	raiz_vbox.add_child(_label_dica)
	_atualizar_dimensoes_painel()


func _atualizar_dimensoes_painel() -> void:
	var qtd := maxi(1, _sequencia_atual.size())
	var tamanho_slot := _obter_tamanho_slot(qtd)
	var largura := maxf(390.0, float(qtd) * (tamanho_slot.x + float(SEPARACAO_SLOTS)) + 52.0)
	var altura := 184.0 if (_label_status != null and _label_status.visible) else 162.0
	var tamanho := Vector2(largura, altura)

	custom_minimum_size = tamanho
	offset_left = -largura * 0.5
	offset_right = largura * 0.5
	offset_top = -altura * 0.5
	offset_bottom = altura * 0.5
	size = tamanho

	if _painel_container != null:
		_painel_container.custom_minimum_size = Vector2.ZERO
		_painel_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _criar_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioDesafio"
	add_child(_audio_player)


func _parar_animacoes_slots() -> void:
	for slot in _slots_ui:
		if is_instance_valid(slot):
			slot.parar_animacao()


func mostrar_sequencia(sequencia: Array[int], tempo_limite: float, titulo: String) -> void:
	_parar_animacoes_slots()
	_sequencia_atual = sequencia.duplicate()
	_tempo_limite = tempo_limite
	_indice_atual = 0
	_tempo_acumulado = 0.0
	_pct_tempo_atual = 1.0
	_status_erro_tempo = 0.0

	_label_titulo.text = titulo if titulo != "" else "Desafio Direcional"
	_label_contador.text = "0 / %d" % _sequencia_atual.size()
	_label_status.text = ""
	_label_status.visible = false

	_reconstruir_slots()
	_atualizar_dimensoes_painel()
	atualizar_tempo(tempo_limite, tempo_limite)

	_tremor_tempo = 0.0
	_flash_vermelho_tempo = 0.0
	_flash_estava_ativo = false
	if _painel_container:
		_painel_container.position.x = 0.0
	_aplicar_estilo_borda(false)

	visible = true


func atualizar_passo(indice: int, total: int) -> void:
	_ocultar_status_erro()
	_indice_atual = indice
	_label_contador.text = "%d / %d" % [indice, total]
	_atualizar_estados_slots()

	if is_inside_tree():
		if indice - 1 >= 0 and indice - 1 < _slots_ui.size():
			_slots_ui[indice - 1].animar_pulso(1.14, 0.12)
		if indice >= 0 and indice < _slots_ui.size():
			_slots_ui[indice].animar_pulso(1.05, 0.14, 0.92)

	_tocar_som_acerto(indice)


func registrar_erro(motivo: String, nova_sequencia: Array[int], tempo_restante: float) -> void:
	_parar_animacoes_slots()
	_indice_atual = 0
	_sequencia_atual = nova_sequencia.duplicate()

	if motivo == "tempo_esgotado":
		_label_status.text = "Tempo esgotado! Sequência reiniciada"
	else:
		_label_status.text = "Tecla errada! Sequência alterada"
	_label_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_label_status.visible = true
	_status_erro_tempo = DURACAO_STATUS_ERRO

	_label_contador.text = "0 / %d" % _sequencia_atual.size()

	_reconstruir_slots()
	_atualizar_dimensoes_painel()
	for slot in _slots_ui:
		slot.estado = 3
		slot.queue_redraw()

	atualizar_tempo(tempo_restante, _tempo_limite)
	_disparar_tremor_e_flash()
	_tocar_som_erro()


func atualizar_tempo(restante: float, limite: float) -> void:
	var pct := clampf(restante / limite, 0.0, 1.0) if limite > 0.0 else 1.0
	_pct_tempo_atual = pct
	_barra_tempo.value = pct
	_label_tempo.text = "%.1fs" % maxf(0.0, restante)

	if pct < 0.25:
		_label_tempo.add_theme_color_override("font_color", Color(0.95, 0.42, 0.42))
	elif pct < 0.5:
		_label_tempo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_STATUS_AMBAR)
	else:
		_label_tempo.add_theme_color_override("font_color", TemaSurvivalHorror.COR_TEXTO_NORMAL)
	_atualizar_cor_barra_tempo()


func _atualizar_cor_barra_tempo() -> void:
	if _estilo_barra_fill == null:
		return
	if _pct_tempo_atual < 0.25:
		var pulso := 0.5 + 0.5 * sin(_tempo_acumulado * 10.0)
		_estilo_barra_fill.bg_color = TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.darkened(0.20).lerp(
			TemaSurvivalHorror.COR_BORDA_VERMELHA,
			pulso
		)
	elif _pct_tempo_atual < 0.5:
		_estilo_barra_fill.bg_color = TemaSurvivalHorror.COR_STATUS_AMBAR
	else:
		_estilo_barra_fill.bg_color = TemaSurvivalHorror.COR_DESTAQUE_VERMELHO


func finalizar(sucesso: bool) -> void:
	_parar_animacoes_slots()
	_tremor_tempo = 0.0
	_flash_vermelho_tempo = 0.0
	_flash_estava_ativo = false
	_status_erro_tempo = 0.0
	if _painel_container:
		_painel_container.position.x = 0.0
	_ocultar_status_erro()
	_aplicar_estilo_borda(false)
	if sucesso:
		_tocar_som_conclusao()
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	_tempo_acumulado += delta
	if _pct_tempo_atual < 0.25:
		_atualizar_cor_barra_tempo()

	if _tremor_tempo > 0.0:
		_tremor_tempo = maxf(0.0, _tremor_tempo - delta)
		var desloc := sin(_tremor_tempo * 55.0) * 7.0 * (_tremor_tempo / DURACAO_FLASH_ERRO)
		if _painel_container:
			_painel_container.position.x = desloc
	elif _painel_container and _painel_container.position.x != 0.0:
		_painel_container.position.x = 0.0

	if _flash_vermelho_tempo > 0.0:
		_flash_vermelho_tempo = maxf(0.0, _flash_vermelho_tempo - delta)
		if _flash_vermelho_tempo <= 0.0 and _flash_estava_ativo:
			_encerrar_flash_erro()
	elif _flash_estava_ativo:
		_encerrar_flash_erro()

	if _status_erro_tempo > 0.0:
		_status_erro_tempo = maxf(0.0, _status_erro_tempo - delta)
		if _status_erro_tempo <= 0.0:
			_ocultar_status_erro()


func _encerrar_flash_erro() -> void:
	_flash_estava_ativo = false
	_aplicar_estilo_borda(false)
	_atualizar_estados_slots()


func _ocultar_status_erro() -> void:
	_status_erro_tempo = 0.0
	if _label_status and _label_status.visible:
		_label_status.visible = false
		_atualizar_dimensoes_painel()


func _disparar_tremor_e_flash() -> void:
	_tremor_tempo = DURACAO_FLASH_ERRO
	_flash_vermelho_tempo = DURACAO_FLASH_ERRO
	_flash_estava_ativo = true
	_aplicar_estilo_borda(true)


func _aplicar_estilo_borda(vermelho: bool) -> void:
	if _estilo_painel == null:
		return
	if vermelho:
		_estilo_painel.border_color = TemaSurvivalHorror.COR_BORDA_VERMELHA
		_estilo_painel.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	else:
		_estilo_painel.border_color = Color(
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.r,
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.g,
			TemaSurvivalHorror.COR_DESTAQUE_VERMELHO.b,
			0.65
		)
		_estilo_painel.bg_color = Color(
			TemaSurvivalHorror.COR_FUNDO_PAINEL.r,
			TemaSurvivalHorror.COR_FUNDO_PAINEL.g,
			TemaSurvivalHorror.COR_FUNDO_PAINEL.b,
			0.92
		)


func _reconstruir_slots() -> void:
	for slot in _slots_ui:
		if is_instance_valid(slot):
			slot.parar_animacao()
			if _container_slots != null and slot.get_parent() == _container_slots:
				_container_slots.remove_child(slot)
			slot.queue_free()
	_slots_ui.clear()

	var qtd := _sequencia_atual.size()
	var tamanho_slot := _obter_tamanho_slot(qtd)
	_container_slots.custom_minimum_size = Vector2(0, tamanho_slot.y)

	for i in range(qtd):
		var slot := SlotDirecao.new()
		slot.custom_minimum_size = tamanho_slot
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
	if _audio_player == null or not _audio_player.is_inside_tree():
		return
	var freq := 440.0 * pow(1.08, float(passo))
	var stream := _gerar_audio_stream([freq], 0.12, 12.0)
	_audio_player.stream = stream
	_audio_player.play()


func _tocar_som_erro() -> void:
	if _audio_player == null or not _audio_player.is_inside_tree():
		return
	var stream := _gerar_audio_stream([140.0, 148.0], 0.28, 6.0)
	_audio_player.stream = stream
	_audio_player.play()


func _tocar_som_conclusao() -> void:
	if _audio_player == null or not _audio_player.is_inside_tree():
		return
	var stream := _gerar_audio_stream([523.25, 659.25, 783.99], 0.35, 5.0)
	_audio_player.stream = stream
	_audio_player.play()
