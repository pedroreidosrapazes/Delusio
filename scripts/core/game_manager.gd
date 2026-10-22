class_name GameManager
extends Node

## Gerenciador principal do ciclo de dias, tarefas e eventos de terror.

static var instance: GameManager

signal dia_iniciado(dia: int)
signal noite_iniciada()
signal tarefas_atualizadas(concluidas: int, totais: int, mensagem: String)
signal status_temporario(mensagem: String)

@export_category("Configurações do Dia")
@export var dia_atual: int = 1
@export var tarefas_totais: int = 3
var tarefas_concluidas: int = 0

@export_category("Referências da Cena")
@export var label_tarefas: Label
@export var silhueta: Node3D
@export var camera_player: Camera3D
@export var environment_noite: WorldEnvironment
@export var radio: Node3D

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	iniciar_novo_dia()

func iniciar_novo_dia() -> void:
	tarefas_concluidas = 0
	
	# Desativa e esconde a silhueta no começo do dia
	if silhueta:
		silhueta.visible = false
		silhueta.process_mode = PROCESS_MODE_DISABLED
		if silhueta.has_method("desativar"):
			silhueta.desativar()
	
	# Reseta a iluminação para DIA
	if environment_noite and environment_noite.has_method("mudar_horario"):
		environment_noite.mudar_horario(0) # 0 = DIA
		
	# Reativa todos os objetos de tarefa no mapa
	var tarefas = get_tree().get_nodes_in_group("tarefas")
	for t in tarefas:
		t.visible = true
		if t is CollisionObject3D:
			for child in t.find_children("*", "CollisionShape3D"):
				if child is CollisionShape3D:
					child.disabled = false
		elif t.has_node("CollisionShape3D"):
			t.get_node("CollisionShape3D").disabled = false
			
		if "concluida" in t:
			t.concluida = false
		if "ja_usado" in t:
			t.ja_usado = false
		if "interacao_ativa" in t:
			t.interacao_ativa = true
			
	atualizar_hud()
	print("--- DIA %d INICIADO ---" % dia_atual)
	dia_iniciado.emit(dia_atual)
	
	if radio and radio.has_method("tocar_noticia"):
		radio.tocar_noticia(dia_atual)

func progredir_tarefa(_id_tarefa: String = "", _quantidade: int = 1) -> void:
	concluir_tarefa()

func concluir_tarefa(_id_tarefa: String = "") -> void:
	tarefas_concluidas += 1
	atualizar_hud()
	
	if tarefas_concluidas >= tarefas_totais:
		iniciar_evento_terror()

func atualizar_hud() -> void:
	var msg: String
	if tarefas_concluidas < tarefas_totais:
		msg = "Dia %d | Tarefas: %d / %d" % [dia_atual, tarefas_concluidas, tarefas_totais]
	else:
		msg = "Dia %d | Vá para a casa e durma na cama!" % dia_atual

	if label_tarefas:
		label_tarefas.text = msg

	tarefas_atualizadas.emit(tarefas_concluidas, tarefas_totais, msg)

func iniciar_evento_terror() -> void:
	print("A noite caiu... A silhueta despertou.")
	
	# Transiciona a iluminação para NOITE
	if environment_noite and environment_noite.has_method("mudar_horario"):
		environment_noite.mudar_horario(2) # 2 = NOITE
		
	if silhueta:
		silhueta.visible = true
		silhueta.process_mode = PROCESS_MODE_INHERIT
		if "camera" in silhueta and camera_player:
			silhueta.camera = camera_player
		if silhueta.has_method("ativar"):
			silhueta.ativar()
			
	noite_iniciada.emit()

func tentar_dormir() -> void:
	if tarefas_concluidas >= tarefas_totais:
		print("Você dormiu em segurança...")
		dia_atual += 1
		iniciar_novo_dia()
	else:
		print("Ainda não! Você precisa terminar todas as tarefas do dia antes de dormir.")
		var aviso = "Você ainda tem tarefas pendentes!"
		if label_tarefas:
			label_tarefas.text = aviso
		status_temporario.emit(aviso)
		# Restaura texto normal após 3 segundos
		await get_tree().create_timer(3.0).timeout
		atualizar_hud()
