class_name Interactable
extends CollisionObject3D

## Classe base para todos os objetos interativos do jogo (Portas, Rádio, Cama, Tarefas).
signal interagiu(jogador: Node3D)

@export_category("Configurações de Interação")
@export var prompt_interacao: String = "Interagir"
@export var interacao_ativa: bool = true

func interagir(jogador: Node3D = null) -> void:
	if not interacao_ativa:
		return
	_executar_interacao(jogador)
	interagiu.emit(jogador)

func _executar_interacao(_jogador: Node3D) -> void:
	pass
