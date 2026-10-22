class_name TarefaInterativa
extends Interactable

## Tarefa interativa do cenário (Ex: Regar plantas, cuidar da fazenda).

@export_category("Configurações da Tarefa")
@export var id_tarefa: String = "regar_horta"
@export var nome_exibicao: String = "Regar a horta"

var concluida: bool = false

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

	# Notifica o GameManager
	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa()
