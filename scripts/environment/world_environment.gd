class_name ClimaAmbiente
extends WorldEnvironment

## Controlador de iluminação e atmosfera (Dia / Tarde / Noite).

signal horario_mudou(estado: int)

@export var directional_light: DirectionalLight3D

enum EstadoDia { DIA = 0, TARDE = 1, NOITE = 2 }

var estado_atual: int = EstadoDia.DIA
var _tween_transicao: Tween


func _ready() -> void:
	mudar_horario(EstadoDia.DIA)


func mudar_horario(estado: int, duracao_transicao: float = 0.0) -> void:
	if environment == null:
		return

	var env := environment
	env.fog_enabled = true
	env.adjustment_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_AGX

	# Não altera env.glow_enabled para preservar compatibilidade com CasaControlador/cama

	var config := _obter_config_horario(estado)
	estado_atual = estado

	if duracao_transicao > 0.0 and is_inside_tree():
		if _tween_transicao and _tween_transicao.is_valid():
			_tween_transicao.kill()
		_tween_transicao = create_tween().set_parallel(true)

		if directional_light:
			_tween_transicao.tween_property(directional_light, "rotation_degrees", config["light_rot"], duracao_transicao)
			_tween_transicao.tween_property(directional_light, "light_color", config["light_color"], duracao_transicao)
			_tween_transicao.tween_property(directional_light, "light_energy", config["light_energy"], duracao_transicao)

		_tween_transicao.tween_property(env, "background_energy_multiplier", config["bg_energy"], duracao_transicao)
		_tween_transicao.tween_property(env, "ambient_light_color", config["ambient_color"], duracao_transicao)
		_tween_transicao.tween_property(env, "ambient_light_energy", config["ambient_energy"], duracao_transicao)
		_tween_transicao.tween_property(env, "fog_light_color", config["fog_color"], duracao_transicao)
		_tween_transicao.tween_property(env, "fog_density", config["fog_density"], duracao_transicao)
		_tween_transicao.tween_property(env, "adjustment_contrast", config["contrast"], duracao_transicao)
		_tween_transicao.tween_property(env, "adjustment_saturation", config["saturation"], duracao_transicao)
	else:
		if directional_light:
			directional_light.rotation_degrees = config["light_rot"]
			directional_light.light_color = config["light_color"]
			directional_light.light_energy = config["light_energy"]

		env.background_energy_multiplier = config["bg_energy"]
		env.ambient_light_color = config["ambient_color"]
		env.ambient_light_energy = config["ambient_energy"]
		env.fog_light_color = config["fog_color"]
		env.fog_density = config["fog_density"]
		env.adjustment_contrast = config["contrast"]
		env.adjustment_saturation = config["saturation"]

	horario_mudou.emit(estado)


func _obter_config_horario(estado: int) -> Dictionary:
	match estado:
		EstadoDia.DIA:
			return {
				"light_rot": Vector3(-58, -45, 0),
				"light_color": Color("#ffe6bf"),
				"light_energy": 1.05,
				"bg_energy": 1.0,
				"ambient_color": Color("#d9b88f"),
				"ambient_energy": 0.85,
				"fog_color": Color("#c4b49b"),
				"fog_density": 0.0045,
				"contrast": 1.05,
				"saturation": 1.04
			}
		EstadoDia.TARDE:
			return {
				"light_rot": Vector3(-16, -115, 0),
				"light_color": Color("#e67e38"),
				"light_energy": 0.75,
				"bg_energy": 0.68,
				"ambient_color": Color("#8c4a27"),
				"ambient_energy": 0.55,
				"fog_color": Color("#7a4930"),
				"fog_density": 0.016,
				"contrast": 1.10,
				"saturation": 0.92
			}
		EstadoDia.NOITE:
			return {
				"light_rot": Vector3(-35, -45, 0),
				"light_color": Color("#6482ad"),
				"light_energy": 0.46,
				"bg_energy": 0.45,
				"ambient_color": Color("#24334d"),
				"ambient_energy": 0.58,
				"fog_color": Color("#1b283d"),
				"fog_density": 0.020,
				"contrast": 1.08,
				"saturation": 0.82
			}
		_:
			return _obter_config_horario(EstadoDia.DIA)
