class_name ClimaAmbiente
extends WorldEnvironment

## Controlador de iluminação e atmosfera (Dia / Tarde / Noite).

@export var directional_light: DirectionalLight3D

enum EstadoDia { DIA = 0, TARDE = 1, NOITE = 2 }

func _ready() -> void:
	mudar_horario(EstadoDia.DIA)

func mudar_horario(estado: int) -> void:
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
