class_name CochoCavalo
extends Interactable

## Objeto interativo do cocho dos animais.

@export var id_tarefa: String = "alimentar_gado"
var ja_usado: bool = false


func _init() -> void:
	exigir_sequencia_direcional = true
	tamanho_sequencia = 5
	tempo_limite_sequencia = 5.5


func pode_interagir() -> bool:
	return super.pode_interagir() and not ja_usado


func _ready() -> void:
	prompt_interacao = "Alimentar Animais"
	add_to_group("tarefas")


func _executar_interacao(_jogador: Node3D) -> void:
	if ja_usado:
		print("Os animais já foram alimentados hoje.")
		return

	ja_usado = true
	interacao_ativa = false
	print("Animais alimentados com sucesso.")
	var pai_fx: Node = get_parent() if get_parent() != null else self
	BancoAudioDelusio.tocar_3d(pai_fx, &"tarefa_cocho", global_position, -2.0, 18.0)
	FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, &"graos", global_position)

	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa(id_tarefa)
