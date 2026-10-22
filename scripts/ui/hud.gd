class_name HUD
extends CanvasLayer

## Interface do Usuário (HUD).

@onready var label_tarefas: Label = $LabelTarefas
@onready var reticula: ColorRect = $ColorRect

func _ready() -> void:
	if GameManager.instance:
		GameManager.instance.tarefas_atualizadas.connect(_on_tarefas_atualizadas)
		GameManager.instance.status_temporario.connect(_on_status_temporario)

func _on_tarefas_atualizadas(_concluidas: int, _totais: int, mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem

func _on_status_temporario(mensagem: String) -> void:
	if label_tarefas:
		label_tarefas.text = mensagem
