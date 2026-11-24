class_name FiltroDelusioControlador
extends CanvasLayer

## Controlador do filtro pós-processamento de atmosfera e horror psicológico.

const SHADER_FILTRO := preload("res://shaders/post_process/filtro_delusio.gdshader")

var nivel_tensao_atual: float = 0.05
var peso_noite_atual: float = 0.0
var desfoque_fundo_atual: float = 0.0

var _tensao_base_horario: float = 0.05
var _peso_noite_alvo: float = 0.0
var _desfoque_fundo_alvo: float = 0.0
var _impulso_tensao: float = 0.0
var _niveis_cor_alvo: float = 32.0

var _retangulo: ColorRect
var _material_filtro: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 0
	_criar_retangulo_tela()
	definir_estado_horario(0, true)


func _criar_retangulo_tela() -> void:
	if _retangulo != null:
		return

	_retangulo = ColorRect.new()
	_retangulo.name = "ColorRectFiltro"
	_retangulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_retangulo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_material_filtro = ShaderMaterial.new()
	_material_filtro.shader = SHADER_FILTRO
	_retangulo.material = _material_filtro
	add_child(_retangulo)


func obter_material_filtro() -> ShaderMaterial:
	if _material_filtro == null and _retangulo != null:
		_material_filtro = _retangulo.material as ShaderMaterial
	return _material_filtro


func registrar_impulso_tensao(valor: float = 0.42) -> void:
	_impulso_tensao = clampf(_impulso_tensao + valor, 0.0, 0.65)
	nivel_tensao_atual = clampf(_tensao_base_horario + _impulso_tensao + calcular_tensao_silhueta(), 0.0, 1.0)
	_atualizar_uniformes_shader()


func definir_desfoque_fundo(valor: float, imediato: bool = false) -> void:
	_desfoque_fundo_alvo = clampf(valor, 0.0, 1.0)
	if imediato:
		desfoque_fundo_atual = _desfoque_fundo_alvo
		_atualizar_uniformes_shader()


func definir_estado_horario(estado: int, imediato: bool = true) -> void:
	match estado:
		0: # DIA
			_tensao_base_horario = 0.05
			_peso_noite_alvo = 0.0
			_niveis_cor_alvo = 32.0
		1: # TARDE
			_tensao_base_horario = 0.22
			_peso_noite_alvo = 0.35
			_niveis_cor_alvo = 28.0
		2: # NOITE
			_tensao_base_horario = 0.32
			_peso_noite_alvo = 1.0
			_niveis_cor_alvo = 28.0

	if imediato:
		peso_noite_atual = _peso_noite_alvo
		nivel_tensao_atual = clampf(_tensao_base_horario + _impulso_tensao + calcular_tensao_silhueta(), 0.0, 1.0)
		_atualizar_uniformes_shader()


func calcular_tensao_silhueta() -> float:
	return 0.0


func _process(delta: float) -> void:
	if get_tree() == null or not get_tree().paused:
		_impulso_tensao = move_toward(_impulso_tensao, 0.0, delta * 0.28)
		var tensao_silhueta := calcular_tensao_silhueta()
		var tensao_alvo := clampf(_tensao_base_horario + _impulso_tensao + tensao_silhueta, 0.0, 1.0)
		nivel_tensao_atual = move_toward(nivel_tensao_atual, tensao_alvo, delta * 1.5)
		peso_noite_atual = move_toward(peso_noite_atual, _peso_noite_alvo, delta * 0.8)
	desfoque_fundo_atual = move_toward(desfoque_fundo_atual, _desfoque_fundo_alvo, delta * 3.5)
	_atualizar_uniformes_shader()


func _atualizar_uniformes_shader() -> void:
	if _material_filtro == null:
		return
	_material_filtro.set_shader_parameter("nivel_tensao", nivel_tensao_atual)
	_material_filtro.set_shader_parameter("peso_noite", peso_noite_atual)
	_material_filtro.set_shader_parameter("niveis_cor", _niveis_cor_alvo)
	_material_filtro.set_shader_parameter("desfoque_fundo", desfoque_fundo_atual)
