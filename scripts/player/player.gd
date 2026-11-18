class_name Player
extends CharacterBody3D

## Controlador de Jogador em Primeira Pessoa.

signal hotbar_alterada()
signal hotbar_selecionada(indice: int)
signal interagivel_focado_alterado(alvo: Interactable)
signal sequencia_interacao_iniciada(sequencia: Array[int], tempo_limite: float, titulo: String)
signal sequencia_interacao_passo(indice: int, total: int)
signal sequencia_interacao_erro(motivo: String, nova_sequencia: Array[int], tempo_restante: float)
signal sequencia_interacao_tempo(restante: float, limite: float)
signal sequencia_interacao_finalizada(sucesso: bool)
signal som_emitido(posicao: Vector3, raio: float, tipo: String)

const HOTBAR_SLOTS: int = 6
const MAX_POR_ITEM: int = 50
const ACAO_OLHAR_TRAS: StringName = &"look_back"
const LIMITE_PAN_OLHAR_TRAS_GRAUS: float = 85.0

var indice_slot_selecionado: int:
	get:
		return _indice_slot_selecionado

var _indice_slot_selecionado: int = 0
var _slots_hotbar: Array[Dictionary] = [
	{"id": &"lanterna", "quantidade": 1},
	{"id": &"", "quantidade": 0},
	{"id": &"", "quantidade": 0},
	{"id": &"", "quantidade": 0},
	{"id": &"", "quantidade": 0},
	{"id": &"", "quantidade": 0},
]
var _lanterna_equipada: bool = true
var _luz_lanterna_acesa: bool = true

@export_category("Movimentação")
@export var velocidade_andar: float = 3.5
@export var velocidade_correr: float = 5.5
@export var forca_pulo: float = 4.0
@export var gravidade: float = 9.8
@export var reticula: ColorRect

@export_category("Câmera")
@export var sensibilidade_mouse: float = 0.002
var rotacao_x_camera: float = 0.0
var olhando_para_tras: bool = false
var _rotacao_y_olhar_tras: float = 0.0

@export_category("Balanço de Câmera (Head Bobbing)")
@export var balanco_ativo: bool = true
@export var frequencia_andar: float = 2.0
@export var frequencia_correr: float = 3.2
@export var amplitude_vertical: float = 0.06
@export var amplitude_horizontal: float = 0.03

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var lanterna: Node3D = $Camera3D/Flashlight
@onready var luz_lanterna: SpotLight3D = get_node_or_null("Camera3D/Flashlight/SpotLight3D") as SpotLight3D

const COR_LANTERNA_PADRAO := Color("#ffe3a8")
const ALCANCE_LANTERNA_PADRAO: float = 32.0
const ANGULO_LANTERNA_PADRAO: float = 52.0
const ATENUACAO_DISTANCIA_LANTERNA: float = 0.85
const ATENUACAO_ANGULO_LANTERNA: float = 0.75
var _energia_base_lanterna: float = 4.8

var tempo_balanco: float = 0.0
var posicao_original_camera: Vector3

var _desafio_sequencia: SequenciaDirecionalDesafio = SequenciaDirecionalDesafio.new()
var _interacao_ativa_alvo: Interactable = null
var _interagivel_focado: Interactable = null
var esconderijo_atual: Node = null
var _timer_som_movimento: float = 0.0


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		posicao_original_camera = camera.transform.origin
	if luz_lanterna:
		_aplicar_configuracao_lanterna()
	_atualizar_aparencia_lanterna()

	_desafio_sequencia.sequencia_iniciada.connect(
		func(seq: Array[int], limite: float, tit: String):
			sequencia_interacao_iniciada.emit(seq, limite, tit)
	)
	_desafio_sequencia.passo_acertado.connect(
		func(idx: int, tot: int):
			sequencia_interacao_passo.emit(idx, tot)
	)
	_desafio_sequencia.sequencia_errada.connect(
		func(motivo: String, seq: Array[int], rest: float):
			emitir_som(22.0, "erro_sequencia")
			sequencia_interacao_erro.emit(motivo, seq, rest)
	)
	_desafio_sequencia.tempo_atualizado.connect(
		func(rest: float, lim: float):
			sequencia_interacao_tempo.emit(rest, lim)
	)
	_desafio_sequencia.sequencia_concluida.connect(_ao_concluir_sequencia)
	_desafio_sequencia.sequencia_cancelada.connect(_ao_cancelar_sequencia)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_definir_olhar_para_tras(false)


func esta_em_interacao_sequencia() -> bool:
	return _desafio_sequencia != null and _desafio_sequencia.ativo


func iniciar_interacao_sequencia(alvo: Interactable) -> void:
	if alvo == null or not alvo.pode_interagir():
		return
	if _desafio_sequencia.ativo:
		cancelar_interacao_sequencia()
	_interacao_ativa_alvo = alvo
	var cfg := alvo.obter_config_sequencia()
	_desafio_sequencia.iniciar(cfg)


func cancelar_interacao_sequencia() -> void:
	if not esta_em_interacao_sequencia():
		return
	_desafio_sequencia.cancelar()


func submeter_direcao_sequencia(dir: int) -> String:
	if not esta_em_interacao_sequencia():
		return "inativo"
	var gerente := GameManager.instance
	if gerente != null and gerente.horario_atual == 2:
		if _interacao_ativa_alvo != null and ("exigir_lanterna_a_noite" in _interacao_ativa_alvo) and _interacao_ativa_alvo.exigir_lanterna_a_noite:
			if not esta_com_lanterna_acesa():
				return "escuro"
	return _desafio_sequencia.submeter_direcao(dir)


func _ao_concluir_sequencia() -> void:
	var alvo := _interacao_ativa_alvo
	_interacao_ativa_alvo = null
	sequencia_interacao_finalizada.emit(true)
	if alvo != null and is_instance_valid(alvo) and alvo.pode_interagir():
		alvo.concluir_interacao_direta(self)


func _ao_cancelar_sequencia() -> void:
	_interacao_ativa_alvo = null
	sequencia_interacao_finalizada.emit(false)


func _deve_manter_cursor_livre() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if tree.paused:
		return true
	for node in tree.get_nodes_in_group("modal_cursor_ui"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Teclas repetidas não devem alternar nem selecionar novamente a hotbar.
	if event is InputEventKey and event.echo:
		return

	# Não recapturar mouse ou mover câmera enquanto um menu modal ou pausa estiver aberto.
	if _deve_manter_cursor_livre():
		return

	# Olhar para trás instantaneamente enquanto segura o botão.
	if InputMap.has_action(ACAO_OLHAR_TRAS):
		if event.is_action_pressed(ACAO_OLHAR_TRAS):
			_definir_olhar_para_tras(true)
		elif event.is_action_released(ACAO_OLHAR_TRAS):
			_definir_olhar_para_tras(false)

	# Controle de rotação da câmera pelo mouse
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if olhando_para_tras:
			var limite_pan := deg_to_rad(LIMITE_PAN_OLHAR_TRAS_GRAUS)
			_rotacao_y_olhar_tras = clamp(_rotacao_y_olhar_tras - event.relative.x * sensibilidade_mouse, -limite_pan, limite_pan)
		else:
			rotate_y(-event.relative.x * sensibilidade_mouse)
		rotacao_x_camera -= event.relative.y * sensibilidade_mouse
		rotacao_x_camera = clamp(rotacao_x_camera, deg_to_rad(-85.0), deg_to_rad(85.0))
		_atualizar_rotacao_camera()

	# Alternar captura do cursor do mouse
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Se estiver escondido, sair com tecla de interação ou pulo/cancelar
	if esta_escondido():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or (InputMap.has_action("jump") and event.is_action_pressed("jump")):
			if esconderijo_atual != null and esconderijo_atual.has_method("sair"):
				esconderijo_atual.sair(self)
			else:
				sair_esconderijo()
			get_viewport().set_input_as_handled()
			return

	# Se estiver no desafio de sequência direcional
	if esta_em_interacao_sequencia():
		# Cancelar com Botão Direito do Mouse ou Backspace
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) \
		or (event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE):
			cancelar_interacao_sequencia()
			get_viewport().set_input_as_handled()
			return

		# Teclas direcionais (WASD e Setas)
		var eh_cima: bool = event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W))
		var eh_baixo: bool = event.is_action_pressed("move_back") or event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S))
		var eh_esq: bool = event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and (event.keycode == KEY_LEFT or event.keycode == KEY_A))
		var eh_dir: bool = event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and (event.keycode == KEY_RIGHT or event.keycode == KEY_D))

		if eh_cima:
			submeter_direcao_sequencia(SequenciaDirecionalDesafio.Direcao.CIMA)
			get_viewport().set_input_as_handled()
			return
		elif eh_baixo:
			submeter_direcao_sequencia(SequenciaDirecionalDesafio.Direcao.BAIXO)
			get_viewport().set_input_as_handled()
			return
		elif eh_esq:
			submeter_direcao_sequencia(SequenciaDirecionalDesafio.Direcao.ESQUERDA)
			get_viewport().set_input_as_handled()
			return
		elif eh_dir:
			submeter_direcao_sequencia(SequenciaDirecionalDesafio.Direcao.DIREITA)
			get_viewport().set_input_as_handled()
			return

		# Bloqueia interação e hotbar durante a sequência, mas permite lanterna
		if event.is_action_pressed("flashlight"):
			alternar_lanterna()
		return

	# Tecla de Interação
	if event.is_action_pressed("interact"):
		tentar_interagir()

	# Tecla da Lanterna
	if event.is_action_pressed("flashlight"):
		alternar_lanterna()

	# Seleção dos seis espaços da hotbar.
	for indice in range(HOTBAR_SLOTS):
		var acao := "hotbar_%d" % (indice + 1)
		if InputMap.has_action(acao) and event.is_action_pressed(acao):
			selecionar_slot(indice)
			break


func alternar_lanterna() -> void:
	if not _lanterna_equipada:
		return
	_luz_lanterna_acesa = not _luz_lanterna_acesa
	_atualizar_aparencia_lanterna()


func esta_com_lanterna_acesa() -> bool:
	return _lanterna_equipada and _luz_lanterna_acesa


func entrar_esconderijo(esconderijo: Node) -> void:
	esconderijo_atual = esconderijo
	velocity = Vector3.ZERO
	if get_tree() != null:
		for monstro in get_tree().get_nodes_in_group("monstros_noturnos"):
			if monstro != null and is_instance_valid(monstro) and monstro.has_method("notificar_jogador_entrou_esconderijo"):
				monstro.notificar_jogador_entrou_esconderijo(self)


func emitir_som(raio: float, tipo: String = "generico") -> void:
	var mult_ruido := 1.0
	var gerente := GameManager.instance
	if gerente != null and ("gerenciador_medicamentos" in gerente) and gerente.gerenciador_medicamentos != null:
		mult_ruido += float(gerente.gerenciador_medicamentos.obter_modificador("ruido_movimento", 0.0))
	var raio_final := maxf(0.0, raio * mult_ruido)
	var pos := global_position if is_inside_tree() else position
	som_emitido.emit(pos, raio_final, tipo)
	if get_tree() != null:
		for monstro in get_tree().get_nodes_in_group("monstros_noturnos"):
			if monstro != null and is_instance_valid(monstro) and monstro.has_method("receber_estimulo_sonoro"):
				monstro.receber_estimulo_sonoro(pos, raio_final)


func sair_esconderijo() -> void:
	esconderijo_atual = null


func esta_escondido() -> bool:
	return esconderijo_atual != null


func obter_slot(indice: int) -> Dictionary:
	if indice < 0 or indice >= HOTBAR_SLOTS:
		return {"id": &"", "quantidade": 0}
	return _slots_hotbar[indice].duplicate()


func selecionar_slot(indice: int) -> void:
	if indice < 0 or indice >= HOTBAR_SLOTS:
		return
	_indice_slot_selecionado = indice
	_lanterna_equipada = _slots_hotbar[indice]["id"] == &"lanterna"
	_atualizar_aparencia_lanterna()
	hotbar_selecionada.emit(indice)


func adicionar_item(id: StringName, quantidade: int) -> int:
	if quantidade <= 0:
		return 0
	if id == &"":
		return quantidade

	var alvo := -1
	for indice in range(HOTBAR_SLOTS):
		if _slots_hotbar[indice]["id"] == id:
			alvo = indice
			break
	if alvo == -1:
		for indice in range(HOTBAR_SLOTS):
			if _slots_hotbar[indice]["id"] == &"":
				alvo = indice
				break
	if alvo == -1:
		return quantidade

	var disponivel := MAX_POR_ITEM - int(_slots_hotbar[alvo]["quantidade"])
	var adicionado: int = mini(quantidade, disponivel)
	if adicionado <= 0:
		return quantidade
	_slots_hotbar[alvo]["id"] = id
	_slots_hotbar[alvo]["quantidade"] = int(_slots_hotbar[alvo]["quantidade"]) + adicionado
	hotbar_alterada.emit()
	return quantidade - adicionado


func possui_item(id: StringName, quantidade: int = 1) -> bool:
	if id == &"" or quantidade <= 0:
		return false
	var total := 0
	for indice in range(HOTBAR_SLOTS):
		if _slots_hotbar[indice]["id"] == id:
			total += int(_slots_hotbar[indice]["quantidade"])
			if total >= quantidade:
				return true
	return false


func consumir_item(id: StringName, quantidade: int = 1) -> bool:
	if not possui_item(id, quantidade):
		return false
	var restante := quantidade
	for indice in range(HOTBAR_SLOTS):
		if _slots_hotbar[indice]["id"] == id:
			var qtd_slot := int(_slots_hotbar[indice]["quantidade"])
			var remover := mini(restante, qtd_slot)
			qtd_slot -= remover
			restante -= remover
			if qtd_slot <= 0:
				_slots_hotbar[indice]["id"] = &""
				_slots_hotbar[indice]["quantidade"] = 0
			else:
				_slots_hotbar[indice]["quantidade"] = qtd_slot
			if restante <= 0:
				break
	hotbar_alterada.emit()
	return true


func _aplicar_configuracao_lanterna() -> void:
	if luz_lanterna == null:
		return
	luz_lanterna.light_color = COR_LANTERNA_PADRAO
	luz_lanterna.light_energy = _energia_base_lanterna
	luz_lanterna.spot_range = ALCANCE_LANTERNA_PADRAO
	luz_lanterna.spot_angle = ANGULO_LANTERNA_PADRAO
	luz_lanterna.spot_attenuation = ATENUACAO_DISTANCIA_LANTERNA
	luz_lanterna.spot_angle_attenuation = ATENUACAO_ANGULO_LANTERNA


func _atualizar_aparencia_lanterna() -> void:
	if lanterna:
		lanterna.visible = _lanterna_equipada
	if luz_lanterna:
		luz_lanterna.visible = _lanterna_equipada and _luz_lanterna_acesa
		if luz_lanterna.visible:
			_aplicar_configuracao_lanterna()


func calcular_fator_instabilidade_lanterna(distancia: float) -> float:
	if distancia >= 26.0:
		return 1.0
	return clampf(lerpf(0.35, 1.0, clampf(distancia / 26.0, 0.0, 1.0)), 0.35, 1.0)


func _processar_instabilidade_lanterna(_delta: float) -> void:
	if luz_lanterna == null or not is_instance_valid(luz_lanterna) or not _lanterna_equipada or not _luz_lanterna_acesa:
		return

	var gerente := GameManager.instance
	if gerente != null and gerente.silhueta != null and is_instance_valid(gerente.silhueta) and gerente.silhueta.visible:
		var dist := global_position.distance_to(gerente.silhueta.global_position)
		var fator := calcular_fator_instabilidade_lanterna(dist)
		var em_ameaca := ("estado_atual" in gerente.silhueta) and int(gerente.silhueta.estado_atual) == Silhueta.Estado.AMEACA_LANTERNA
		if em_ameaca:
			var flicker_ameaca := sin(Time.get_ticks_msec() * 0.09) * 0.45 + sin(Time.get_ticks_msec() * 0.028) * 0.25
			luz_lanterna.light_energy = clampf(_energia_base_lanterna * (0.55 + flicker_ameaca), _energia_base_lanterna * 0.18, _energia_base_lanterna * 1.15)
		elif fator < 1.0:
			var flicker := sin(Time.get_ticks_msec() * 0.045) * 0.25 + sin(Time.get_ticks_msec() * 0.012) * 0.15
			luz_lanterna.light_energy = clampf(_energia_base_lanterna * (fator + flicker), _energia_base_lanterna * 0.35, _energia_base_lanterna * 1.15)
		else:
			luz_lanterna.light_energy = _energia_base_lanterna
	else:
		luz_lanterna.light_energy = _energia_base_lanterna


func tentar_interagir() -> void:
	if esta_em_interacao_sequencia():
		return

	if raycast == null:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var col = raycast.get_collider()

		# 1. Se for uma instância de Interactable
		if col is Interactable and col.pode_interagir():
			col.interagir(self)
			return

		# 2. Se o pai for Interactable
		var pai = col.get_parent() if col else null
		if pai is Interactable and pai.pode_interagir():
			pai.interagir(self)
			return

		# 3. Suporte polimórfico genérico (has_method)
		if col and col.has_method("interagir"):
			col.interagir()
			return

		# 4. Tenta chamar o método interagir no nó pai (ex: nó raiz de porta ou mobília importada)
		if pai and pai.has_method("interagir"):
			pai.interagir()
			return


func _definir_olhar_para_tras(ativo: bool) -> void:
	if olhando_para_tras == ativo:
		return
	olhando_para_tras = ativo
	_rotacao_y_olhar_tras = 0.0
	_atualizar_rotacao_camera()


func _atualizar_rotacao_camera() -> void:
	if camera == null:
		return
	var yaw := (PI + _rotacao_y_olhar_tras) if olhando_para_tras else 0.0
	camera.rotation = Vector3(rotacao_x_camera, yaw, 0.0)


func _process(delta: float) -> void:
	if esta_em_interacao_sequencia():
		if _interacao_ativa_alvo == null or not is_instance_valid(_interacao_ativa_alvo) or not _interacao_ativa_alvo.pode_interagir():
			cancelar_interacao_sequencia()
		else:
			_desafio_sequencia.processar_delta(delta)

	if InputMap.has_action(ACAO_OLHAR_TRAS):
		var pressionado := Input.is_action_pressed(ACAO_OLHAR_TRAS)
		if olhando_para_tras != pressionado:
			_definir_olhar_para_tras(pressionado)

	_processar_instabilidade_lanterna(delta)
	_atualizar_reticula()


func _atualizar_reticula() -> void:
	if reticula == null or raycast == null:
		return

	var novo_focado: Interactable = null
	var interagivel := false

	if raycast.is_colliding():
		var col = raycast.get_collider()

		if col is Interactable and col.pode_interagir():
			novo_focado = col
			interagivel = true
		elif col and col.get_parent() is Interactable and (col.get_parent() as Interactable).pode_interagir():
			novo_focado = col.get_parent() as Interactable
			interagivel = true
		elif col and col.has_method("interagir"):
			interagivel = true
		elif col and col.get_parent() and col.get_parent().has_method("interagir"):
			interagivel = true

	if _interagivel_focado != novo_focado:
		_interagivel_focado = novo_focado
		interagivel_focado_alterado.emit(_interagivel_focado)

	if interagivel:
		reticula.color = Color.GREEN
	else:
		reticula.color = Color.WHITE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta

	if _deve_manter_cursor_livre():
		velocity.x = move_toward(velocity.x, 0, velocidade_andar)
		velocity.z = move_toward(velocity.z, 0, velocidade_andar)
		move_and_slide()
		_timer_som_movimento = 0.0
		return

	if esta_em_interacao_sequencia():
		velocity.x = move_toward(velocity.x, 0, velocidade_andar)
		velocity.z = move_toward(velocity.z, 0, velocidade_andar)
		move_and_slide()
		return

	if esta_escondido():
		velocity.x = move_toward(velocity.x, 0, velocidade_andar)
		velocity.z = move_toward(velocity.z, 0, velocidade_andar)
		move_and_slide()
		return

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

	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.4:
		_timer_som_movimento += delta
		if _timer_som_movimento >= 0.45:
			_timer_som_movimento = 0.0
			if esta_correndo:
				emitir_som(18.0, "corrida")
			else:
				emitir_som(6.5, "passos")
	else:
		_timer_som_movimento = 0.0

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
