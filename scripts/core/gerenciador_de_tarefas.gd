class_name GerenciadorTarefas
extends Node

## Sub-gerenciador de tarefas detalhadas por ID.

signal tarefa_progrediu(id_tarefa: String, atual: int, total: int)
signal tarefa_concluida(id_tarefa: String)
signal todas_tarefas_concluidas

var tarefas: Dictionary = {
	"regar_horta": {
		"nome": "Regar a horta",
		"atual": 0,
		"total": 3,
		"concluida": false
	},
	"alimentar_gado": {
		"nome": "Alimentar os animais",
		"atual": 0,
		"total": 1,
		"concluida": false
	}
}

func progredir_tarefa(id_tarefa: String, quantidade: int = 1) -> void:
	if not tarefas.has(id_tarefa):
		print("GerenciadorTarefas: ID '%s' não mapeado, registrando conclusão direta..." % id_tarefa)
		if GameManager.instance:
			GameManager.instance.concluir_tarefa(id_tarefa)
		return

	var t = tarefas[id_tarefa]
	if t["concluida"]:
		return

	t["atual"] = clampi(t["atual"] + quantidade, 0, t["total"])
	tarefa_progrediu.emit(id_tarefa, t["atual"], t["total"])
	print("Progresso [%s]: %d/%d" % [t["nome"], t["atual"], t["total"]])

	if t["atual"] >= t["total"]:
		t["concluida"] = true
		tarefa_concluida.emit(id_tarefa)
		print("Tarefa concluída: ", t["nome"])
		if GameManager.instance:
			GameManager.instance.concluir_tarefa(id_tarefa)
		_verificar_todas_concluidas()

func _verificar_todas_concluidas() -> void:
	for id in tarefas:
		if not tarefas[id]["concluida"]:
			return
			
	print("Todas as tarefas detalhadas foram concluídas!")
	todas_tarefas_concluidas.emit()

func resetar_diario() -> void:
	for id in tarefas:
		tarefas[id]["atual"] = 0
		tarefas[id]["concluida"] = false
