extends StaticBody3D

@export var nome_tarefa: String = "Cuidados da Fazenda"
var concluida: bool = false

func _ready() -> void:
	add_to_group("interativo")

func interagir() -> void:
	if concluida:
		print("Você já realizou esta tarefa por hoje.")
		return

	var manager = get_tree().current_scene.get_node_or_null("GameManager")
	if manager:
		concluida = true
		print("Concluído: ", nome_tarefa)
		manager.concluir_tarefa()
		
		# Desativa ou altera o visual do objeto após o uso
		queue_free()
	else:
		print("ERRO: GameManager não encontrado na cena!")
