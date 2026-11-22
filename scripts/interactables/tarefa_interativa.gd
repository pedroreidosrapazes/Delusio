class_name TarefaInterativa
extends Interactable

## Tarefa interativa do cenário (Ex: Regar plantas, cuidar da fazenda).

@export_category("Configurações da Tarefa")
@export var id_tarefa: String = "regar_horta"
@export var nome_exibicao: String = "Regar a horta"

var concluida: bool = false


func _init() -> void:
	exigir_sequencia_direcional = true
	tamanho_sequencia = 4
	tempo_limite_sequencia = 6.0


func pode_interagir() -> bool:
	return super.pode_interagir() and not concluida


func _ready() -> void:
	prompt_interacao = nome_exibicao
	add_to_group("tarefas")


func _executar_interacao(_jogador: Node3D) -> void:
	if concluida:
		print("Você já concluiu esta tarefa hoje: ", nome_exibicao)
		return

	concluida = true
	interacao_ativa = false
	print("Tarefa realizada: ", nome_exibicao)

	# Feedback visual (desativa colisão e visibilidade)
	visible = false
	for child in find_children("*", "CollisionShape3D"):
		if child is CollisionShape3D:
			child.disabled = true

	var sfx_id: StringName = &"tarefa_agua"
	var tipo_burst: StringName = &"agua"
	match id_tarefa:
		"podar_cerca":
			sfx_id = &"tarefa_cerca"
			tipo_burst = &"folhas"
		"consertar_bomba":
			sfx_id = &"tarefa_bomba"
			tipo_burst = &"faiscas"
	var pai_fx: Node = get_parent() if get_parent() != null else self
	BancoAudioDelusio.tocar_3d(pai_fx, sfx_id, global_position, -2.0, 18.0)
	FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, tipo_burst, global_position)

	# Notifica o GameManager
	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa()
