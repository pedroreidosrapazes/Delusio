class_name CaixaDaAguaTarefa
extends Interactable

## Tarefa de consertar o vazamento da caixa d'água utilizando Silver Tape.

@export_category("Configurações da Tarefa")
@export var id_tarefa: String = "consertar_caixa_agua"
@export var nome_exibicao: String = "Consertar caixa d'água"
@export var item_necessario: StringName = &"silver_tape"
@export var quantidade_necessaria: int = 1

@export_category("Referências da Caixa d'Água")
@export var caminho_rig_faiscas: NodePath = ^"../Cube/Rig_Faiscas"
@export var caminho_animation_player: NodePath = ^"../AnimationPlayer"
@export var caminho_remendo: NodePath = ^"RemendoSilverTape"

var concluida: bool = false
var _particulas_vazamento: GPUParticles3D = null
var _audio_vazamento: AudioStreamPlayer3D = null


func _init() -> void:
	exigir_sequencia_direcional = true
	tamanho_sequencia = 5
	tempo_limite_sequencia = 6.0
	exigir_lanterna_a_noite = true


func _ready() -> void:
	prompt_interacao = "Tampar vazamento"
	add_to_group("tarefas")
	if get_node_or_null("ParticulasVazamentoAgua") == null:
		_particulas_vazamento = FabricaParticulasDelusio.criar_vazamento_agua()
		add_child(_particulas_vazamento)
	if _audio_vazamento == null:
		_audio_vazamento = AudioStreamPlayer3D.new()
		_audio_vazamento.name = "AudioVazamento3D"
		_audio_vazamento.stream = BancoAudioDelusio.obter_sfx(&"vazamento_agua_loop")
		_audio_vazamento.bus = BancoAudioDelusio.resolver_bus(&"SFX")
		_audio_vazamento.max_distance = 14.0
		_audio_vazamento.volume_db = -8.0
		add_child(_audio_vazamento)
	_aplicar_estado_visual(false)

	if GameManager.instance and not GameManager.instance.dia_iniciado.is_connected(_ao_iniciar_novo_dia):
		GameManager.instance.dia_iniciado.connect(_ao_iniciar_novo_dia)


func _exit_tree() -> void:
	if _audio_vazamento != null:
		_audio_vazamento.stop()
		_audio_vazamento.stream = null


func pode_interagir() -> bool:
	return super.pode_interagir() and not concluida


func interagir(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return

	if jogador != null and jogador.has_method("possui_item"):
		if not jogador.possui_item(item_necessario, quantidade_necessaria):
			if GameManager.instance:
				GameManager.instance.status_temporario.emit("Você precisa de Silver Tape para tampar o vazamento!")
			return

	super.interagir(jogador)


func _executar_interacao(jogador: Node3D) -> void:
	if concluida:
		return

	if jogador != null and jogador.has_method("consumir_item"):
		if not jogador.consumir_item(item_necessario, quantidade_necessaria):
			if GameManager.instance:
				GameManager.instance.status_temporario.emit("Você precisa de Silver Tape para tampar o vazamento!")
			return

	concluida = true
	interacao_ativa = false
	_aplicar_estado_visual(true)
	_definir_colisao_ativa(false)
	var pai_fx: Node = get_parent() if get_parent() != null else self
	BancoAudioDelusio.tocar_3d(pai_fx, &"fita_silver_tape", global_position, -2.0, 16.0)
	FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, &"fita", global_position)

	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
		GameManager.instance.status_temporario.emit("Vazamento da caixa d'água tampado com Silver Tape!")
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa(id_tarefa)


func _ao_iniciar_novo_dia(_dia: int) -> void:
	concluida = false
	interacao_ativa = true
	_definir_colisao_ativa(true)
	_aplicar_estado_visual(false)


func _definir_colisao_ativa(ativa: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		if child is CollisionShape3D:
			child.disabled = not ativa


func _aplicar_estado_visual(consertada: bool) -> void:
	var remendo := get_node_or_null(caminho_remendo) as Node3D
	if remendo:
		remendo.visible = consertada

	var rig_faiscas := get_node_or_null(caminho_rig_faiscas) as Node3D
	if rig_faiscas:
		rig_faiscas.visible = not consertada

	if _particulas_vazamento != null:
		_particulas_vazamento.emitting = not consertada

	if _audio_vazamento != null:
		if consertada:
			_audio_vazamento.stop()
		elif is_inside_tree() and _audio_vazamento.is_inside_tree() and not _audio_vazamento.playing:
			_audio_vazamento.play()

	var anim_player := get_node_or_null(caminho_animation_player) as AnimationPlayer
	if anim_player:
		if consertada:
			anim_player.stop()
		elif anim_player.has_animation("Anim_Vazamento"):
			anim_player.play("Anim_Vazamento")
