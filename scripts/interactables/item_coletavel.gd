class_name ItemColetavel
extends Interactable

## Script para itens e ferramentas no cenário que o jogador pode pegar.

signal item_coletado(id_item: StringName, quantidade: int)

@export_category("Configurações do Item")
@export var id_item: StringName = &"silver_tape"
@export var quantidade: int = 1
@export var destruir_apos_coleta: bool = true

func _init() -> void:
	exigir_lanterna_a_noite = false
	exigir_sequencia_direcional = false

func _ready() -> void:
	add_to_group("itens_coletaveis")
	if prompt_interacao == "Interagir" or prompt_interacao.is_empty():
		prompt_interacao = "Pegar " + str(id_item).replace("_", " ").capitalize()

func _executar_interacao(jogador: Node3D) -> void:
	if not pode_interagir():
		return

	interacao_ativa = false

	if jogador != null and jogador.has_method("adicionar_item"):
		var restante: int = jogador.adicionar_item(id_item, quantidade)
		if restante < quantidade:
			var coletado: int = quantidade - restante
			print("Item coletado pelo jogador: ", id_item, " x", coletado)
			item_coletado.emit(id_item, coletado)
			if destruir_apos_coleta:
				for child in find_children("*", "CollisionShape3D", true, false):
					if child is CollisionShape3D:
						child.disabled = true
				queue_free()
		else:
			print("Inventário cheio para o item: ", id_item)
			interacao_ativa = true
	else:
		item_coletado.emit(id_item, quantidade)
		if destruir_apos_coleta:
			queue_free()
