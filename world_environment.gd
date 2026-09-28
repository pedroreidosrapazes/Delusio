extends WorldEnvironment

@export var directional_light: DirectionalLight3D

enum EstadoDia { DIA, TARDE, NOITE }

func _ready() -> void:
	mudar_horario(EstadoDia.DIA)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				mudar_horario(EstadoDia.DIA)
			KEY_2:
				mudar_horario(EstadoDia.TARDE)
			KEY_3:
				mudar_horario(EstadoDia.NOITE)

func mudar_horario(estado: EstadoDia) -> void:
	if environment == null:
		return

	var env = environment
	env.fog_enabled = true

	match estado:
		EstadoDia.DIA:
			if directional_light:
				directional_light.rotation_degrees = Vector3(-60, -45, 0)
				directional_light.light_color = Color("ffffff")
				directional_light.light_energy = 1.0
			
			env.background_energy_multiplier = 1.0
			env.ambient_light_color = Color("ffffff")
			env.ambient_light_energy = 1.0
			
			env.fog_light_color = Color("a0b0c0")
			env.fog_density = 0.005

		EstadoDia.TARDE:
			if directional_light:
				directional_light.rotation_degrees = Vector3(-15, -120, 0)
				directional_light.light_color = Color("ffaa55")
				directional_light.light_energy = 0.8
			
			env.background_energy_multiplier = 0.7
			env.ambient_light_color = Color("ff8844")
			env.ambient_light_energy = 0.6
			
			env.fog_light_color = Color("cc7744")
			env.fog_density = 0.015

		EstadoDia.NOITE:
			if directional_light:
				directional_light.rotation_degrees = Vector3(-35, -45, 0)
				directional_light.light_color = Color("5577aa")
				directional_light.light_energy = 0.35
			
			env.background_energy_multiplier = 0.3
			env.ambient_light_color = Color("223355")
			env.ambient_light_energy = 0.5
			
			env.fog_light_color = Color("0d1522")
			env.fog_density = 0.04
