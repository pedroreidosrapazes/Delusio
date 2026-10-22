class_name Cama
extends Interactable

## Objeto interativo de dormir para avançar o dia.

func _ready() -> void:
	prompt_interacao = "Dormir"

func _executar_interacao(_jogador: Node3D) -> void:
	if GameManager.instance:
		GameManager.instance.tentar_dormir()
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("tentar_dormir"):
			manager.tentar_dormir()
