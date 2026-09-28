extends CharacterBody3D

@export_group("Movimentação")
@export var SPEED : float = 4.0
@export var RUN_SPEED : float = 7.0
@export var JUMP_VELOCITY : float = 4.5
@export var ACCELERATION : float = 16.0

@export_group("Câmera")
@export var MOUSE_SENSITIVITY : float = 0.002
var rotacao_x_camera : float = 0.0

@export_group("Efeitos de Caminhada (Head Bob)")
@export var BOB_FREQUENCY : float = 2.4
@export var BOB_AMPLITUDE : float = 0.06
var bob_tempo : float = 0.0
var pos_inicial_camera_y : float = 1.5

@export_group("Lanterna")
@export var LANTERNA_LIGADA_INICIO : bool = true

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D
@onready var lanterna: SpotLight3D = $Camera3D/Flashlight/SpotLight3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		pos_inicial_camera_y = camera.transform.origin.y
	
	if lanterna:
		lanterna.visible = LANTERNA_LIGADA_INICIO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Gira o corpo (esquerda/direita)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Gira a câmara (cima/baixo)
		rotacao_x_camera -= event.relative.y * MOUSE_SENSITIVITY
		
		# Limitamos entre aprox -85 e 85 graus (em radianos) usando números diretos para evitar erros de conversão
		rotacao_x_camera = clamp(rotacao_x_camera, -1.5, 1.5) 
		camera.rotation.x = rotacao_x_camera
		
		# VERIFICA A CONSOLA: Se este valor não mudar quando sobes o rato, o problema é o rato. Se mudar e a câmara não mexer, algo está a sobrescrever a câmara.
		print("Valor da rotação X: ", rotacao_x_camera)

	if event.is_action_pressed("flashlight") and lanterna != null:
		lanterna.visible = not lanterna.visible

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	var velocidade_atual := SPEED
	if Input.is_action_pressed("run"):
		velocidade_atual = RUN_SPEED

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * velocidade_atual, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * velocidade_atual, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, ACCELERATION * delta)

	_processar_head_bob(delta)

	move_and_slide()

func _processar_head_bob(delta: float) -> void:
	if not is_on_floor() or camera == null:
		return

	var vel_horizontal := Vector2(velocity.x, velocity.z).length()

	if vel_horizontal > 0.1:
		var freq_multiplicador := 1.3 if Input.is_action_pressed("run") else 1.0
		bob_tempo += delta * (BOB_FREQUENCY * freq_multiplicador) * 0.4
		
		var offset_y := sin(bob_tempo * 2.0) * BOB_AMPLITUDE
		var offset_x := cos(bob_tempo) * (BOB_AMPLITUDE * 0.8)
		
		camera.transform.origin.y = pos_inicial_camera_y + offset_y
		camera.transform.origin.x = offset_x
	else:
		bob_tempo = 0.0
		camera.transform.origin.y = move_toward(camera.transform.origin.y, pos_inicial_camera_y, delta * 2.0)
		camera.transform.origin.x = move_toward(camera.transform.origin.x, 0.0, delta * 2.0)
