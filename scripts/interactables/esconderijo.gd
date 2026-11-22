class_name Esconderijo
extends Interactable

## Esconderijo seguro para se ocultar da Silhueta à noite (Armários, Baús, Folhagens densas).

signal jogador_entrou(player: Player)
signal jogador_saiu(player: Player)
signal tensao_esconderijo_alterada(intensidade: float, luz_vazando: bool)

@export_category("Configurações do Esconderijo")
@export var nome_esconderijo: String = "Armário de Madeira"
@export var ponto_olhar: Node3D
@export var ponto_saida: Marker3D
@export var visual_scene_override: PackedScene

var ocupado: bool = false
var jogador_escondido: Player = null
var estabilidade_atual: float = 1.0
var _pos_antes_entrar: Vector3 = Vector3.ZERO
var _moveu_jogador_ao_entrar: bool = false
var _aviso_luz_cooldown: float = 0.0
var _timer_batimento: float = 0.0


func _init() -> void:
	prompt_interacao = "Esconder-se no armário"
	exigir_sequencia_direcional = false
	exigir_lanterna_a_noite = false


func _ready() -> void:
	add_to_group("esconderijos")
	prompt_interacao = "Esconder-se em " + nome_esconderijo
	if visual_scene_override != null and get_node_or_null("Modelo") == null:
		var inst := visual_scene_override.instantiate() as Node3D
		if inst != null:
			inst.name = "Modelo"
			add_child(inst)


func pode_interagir() -> bool:
	return interacao_ativa


func _executar_interacao(jogador: Node3D) -> void:
	if not (jogador is Player):
		return

	var p := jogador as Player
	if not ocupado:
		entrar(p)
	elif jogador_escondido == p:
		sair(p)


func entrar(player: Player) -> void:
	if ocupado or player == null:
		return

	ocupado = true
	jogador_escondido = player
	_pos_antes_entrar = player.global_position if player.is_inside_tree() else player.position
	_moveu_jogador_ao_entrar = false
	_aviso_luz_cooldown = 0.0
	_timer_batimento = 0.0
	BancoAudioDelusio.tocar_3d(self, &"armario_entrar", global_position, -3.0, 16.0)
	prompt_interacao = "Sair de " + nome_esconderijo
	if ponto_olhar != null and is_instance_valid(ponto_olhar) and player.is_inside_tree():
		player.global_position = ponto_olhar.global_position
		_moveu_jogador_ao_entrar = true
	player.entrar_esconderijo(self)

	# Se houver GameManager com medicamentos ativos, ajusta estabilidade
	var gerente := GameManager.instance
	estabilidade_atual = 1.0
	if gerente != null and gerente.gerenciador_medicamentos != null:
		var penalidade := gerente.gerenciador_medicamentos.obter_modificador("instabilidade_esconderijo", 0.0)
		estabilidade_atual = clampf(1.0 - penalidade, 0.20, 1.0)

	if player.esta_com_lanterna_acesa() and gerente != null:
		gerente.status_temporario.emit("A luz está vazando! Apague a lanterna [F]!")
		_aviso_luz_cooldown = 3.5

	jogador_entrou.emit(player)


func sair(player: Player = null) -> void:
	if not ocupado:
		return

	var p := player if player != null else jogador_escondido
	ocupado = false
	_timer_batimento = 0.0
	BancoAudioDelusio.tocar_3d(self, &"armario_sair", global_position, -3.0, 16.0)
	prompt_interacao = "Esconder-se em " + nome_esconderijo

	if p != null:
		if ponto_saida != null and is_instance_valid(ponto_saida) and p.is_inside_tree():
			p.global_position = ponto_saida.global_position
		elif _moveu_jogador_ao_entrar and p.is_inside_tree():
			p.global_position = _pos_antes_entrar
		p.sair_esconderijo()
		jogador_saiu.emit(p)

	_moveu_jogador_ao_entrar = false
	jogador_escondido = null


func _process(delta: float) -> void:
	if not ocupado or jogador_escondido == null or not is_instance_valid(jogador_escondido):
		return

	_aviso_luz_cooldown = maxf(0.0, _aviso_luz_cooldown - delta)
	var vazando := jogador_escondido.esta_com_lanterna_acesa()
	var gerente := GameManager.instance

	if vazando and _aviso_luz_cooldown <= 0.0:
		_aviso_luz_cooldown = 3.5
		if gerente != null:
			gerente.status_temporario.emit("A luz está vazando! Apague a lanterna [F]!")

	var menor_dist := 999.0
	if get_tree() != null:
		for m in get_tree().get_nodes_in_group("monstros_noturnos"):
			if m is Node3D and is_instance_valid(m) and ("ativa" in m) and m.ativa:
				var d := global_position.distance_to((m as Node3D).global_position)
				if d < menor_dist:
					menor_dist = d

	var prox := 0.0
	if menor_dist <= 16.0:
		prox = 1.0 - clampf(menor_dist / 16.0, 0.0, 1.0)
	var intensidade := clampf(prox * (1.0 + (1.0 - estabilidade_atual) * 0.6), 0.0, 1.0)

	if intensidade > 0.15:
		_timer_batimento -= delta
		if _timer_batimento <= 0.0:
			_timer_batimento = lerpf(1.2, 0.52, intensidade)
			BancoAudioDelusio.tocar_2d(self, &"batimento_cardiaco", lerpf(-12.0, -3.0, intensidade), 0.03)
	else:
		_timer_batimento = 0.0

	if (intensidade > 0.05 or vazando) and get_tree() != null and get_tree().current_scene != null:
		for f in get_tree().current_scene.find_children("*", "FiltroDelusioControlador", true, false):
			if f.has_method("registrar_impulso_tensao"):
				var pulso := (0.14 * intensidade + (0.12 if vazando else 0.0)) * delta
				if pulso > 0.0:
					f.registrar_impulso_tensao(pulso)
				break

	if intensidade > 0.05 or vazando:
		tensao_esconderijo_alterada.emit(intensidade, vazando)


func esta_comprometido(player: Player) -> bool:
	if player == null:
		return false

	# Se a lanterna estiver acesa dentro do esconderijo, a luz vaza e compromete a posição
	if player.esta_com_lanterna_acesa():
		return true

	# Se a Silhueta estiver em investida direta próxima
	var gerente := GameManager.instance
	if gerente != null and gerente.silhueta != null and is_instance_valid(gerente.silhueta):
		var sil := gerente.silhueta
		if ("em_investida" in sil) and sil.em_investida:
			if global_position.distance_to(sil.global_position) < 12.0:
				return true

	return false
