extends Node

var tarefas_pendentes: int = 3
var dia_atual: int = 1

# Referência ao gerenciador de clima para mudar o horário automaticamente
@export var gerenciador_clima: Node3D 

func concluir_tarefa() -> void:
	tarefas_pendentes -= 1
	print("Tarefa concluída! Restam: ", tarefas_pendentes)
	
	if tarefas_pendentes <= 0:
		iniciar_anoitecer()

func iniciar_anoitecer() -> void:
	print("O sol começa a baixar... A névoa está chegando.")
	
	# Se o gerenciador de clima estiver conectado, avança o horário para a TARDE/NOITE
	if gerenciador_clima and gerenciador_clima.has_method("mudar_horario"):
		gerenciador_clima.mudar_horario(gerenciador_clima.EstadoDia.TARDE)
