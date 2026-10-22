class_name Player
extends CharacterBody3D

## Controlador de Jogador em Primeira Pessoa.

@export_category("Movimentação")
@export var velocidade_andar: float = 3.5
@export var velocidade_correr: float = 5.5
@export var forca_pulo: float = 4.0
@export var gravidade: float = 9.8
@export var reticula: ColorRect

@export_category("Câmera")
@export var sensibilidade_mouse: float = 0.002
var rotacao_x_camera: float = 0.0

@export_category("Balanço de Câmera (Head Bobbing)")
@export var balanco_ativo: bool = true
@export var frequencia_andar: float = 2.0
@export var frequencia_correr: float = 3.2
@export var amplitude_vertical: float = 0.06
@export var amplitude_horizontal: float = 0.03

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var lanterna: Node3D = $Camera3D/Flashlight

var tempo_balanco: float = 0.0
var posicao_original_camera: Vector3

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		posicao_original_camera = camera.transform.origin

func _unhandled_input(event: InputEvent) -> void:
	# Controle de rotação da câmera pelo mouse
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidade_mouse)
		rotacao_x_camera -= event.relative.y * sensibilidade_mouse
		rotacao_x_camera = clamp(rotacao_x_camera, deg_to_rad(-85.0), deg_to_rad(85.0))
		if camera:
			camera.rotation.x = rotacao_x_camera

	# Alternar captura do cursor do mouse
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Tecla de Interação
	if event.is_action_pressed("interact"):
		tentar_interagir()

	# Tecla da Lanterna
	if event.is_action_pressed("flashlight"):
		alternar_lanterna()

func alternar_lanterna() -> void:
	if lanterna:
		lanterna.visible = not lanterna.visible

func tentar_interagir() -> void:
	if raycast == null:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var col = raycast.get_collider()
		
		# 1. Se for uma instância de Interactable
		if col is Interactable and col.interacao_ativa:
			col.interagir(self)
			return

		# 2. Suporte polimórfico genérico (has_method)
		if col and col.has_method("interagir"):
			col.interagir()
			return
			
		# 3. Tenta chamar o método interagir no nó pai (ex: nó raiz de porta ou mobília importada)
		var pai = col.get_parent() if col else null
		if pai and pai.has_method("interagir"):
			pai.interagir()
			return

func _process(_delta: float) -> void:
	_atualizar_reticula()

func _atualizar_reticula() -> void:
	if reticula == null or raycast == null:
		return

	if raycast.is_colliding():
		var col = raycast.get_collider()
		var interagivel := false

		if col is Interactable and col.interacao_ativa:
			interagivel = true
		elif col and col.has_method("interagir"):
			interagivel = true
		elif col and col.get_parent() and col.get_parent().has_method("interagir"):
			interagivel = true

		if interagivel:
			reticula.color = Color.GREEN
			return

	reticula.color = Color.WHITE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta

	# Pulo (suporta a ação "jump" e fallback para "ui_accept")
	var quer_pular := Input.is_action_just_pressed("jump") if InputMap.has_action("jump") else Input.is_action_just_pressed("ui_accept")
	if quer_pular and is_on_floor():
		velocity.y = forca_pulo

	var esta_correndo := Input.is_action_pressed("run")
	var vel_atual := velocidade_correr if esta_correndo else velocidade_andar

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direcao := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direcao:
		velocity.x = direcao.x * vel_atual
		velocity.z = direcao.z * vel_atual
	else:
		velocity.x = move_toward(velocity.x, 0, vel_atual)
		velocity.z = move_toward(velocity.z, 0, vel_atual)

	move_and_slide()

	if balanco_ativo and camera:
		_processar_balanco_camera(delta, input_dir, esta_correndo)

func _processar_balanco_camera(delta: float, input_dir: Vector2, esta_correndo: bool) -> void:
	var movendo := input_dir.length() > 0.0 and is_on_floor()
	
	if movendo:
		var freq := frequencia_correr if esta_correndo else frequencia_andar
		tempo_balanco += delta * freq * (velocity.length() / velocidade_andar)
		
		var bob_y := sin(tempo_balanco * 2.0) * amplitude_vertical
		var bob_x := cos(tempo_balanco) * amplitude_horizontal
		
		camera.transform.origin = posicao_original_camera + Vector3(bob_x, bob_y, 0)
	else:
		tempo_balanco = 0.0
		camera.transform.origin = camera.transform.origin.lerp(posicao_original_camera, delta * 8.0)
