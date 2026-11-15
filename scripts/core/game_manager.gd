class_name GameManager
extends Node

## Gerenciador principal do ciclo de dias, tarefas e eventos de terror.

static var instance: GameManager

signal dia_iniciado(dia: int)
signal noite_iniciada()
signal tarefas_atualizadas(concluidas: int, totais: int, mensagem: String)
signal status_temporario(mensagem: String)
signal horario_alterado(estado: int)

enum ModoNoturno { NENHUM = 0, VIGILIA_DOMESTICA = 1, TAREFAS_PENDENTES = 2 }
var modo_noturno: int = ModoNoturno.NENHUM

@export_category("Configurações do Dia")
@export var dia_atual: int = 1
@export var tarefas_totais: int = 3
@export var duracao_dia_segundos: float = 180.0

var tarefas_concluidas: int = 0
var horario_atual: int = 0
var tempo_dia_restante: float = 180.0

const GERENCIADOR_MEDICAMENTOS := preload("res://scripts/core/gerenciador_medicamentos.gd")

var pontos_vigilia_ativos: bool = false
var recargas_luz_disponiveis: int = 2
var rastros_investigativos: Array[Node3D] = []

var gerenciador_medicamentos: GerenciadorMedicamentos = null

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
	if gerenciador_medicamentos == null:
		gerenciador_medicamentos = GerenciadorMedicamentos.new()
		gerenciador_medicamentos.name = "GerenciadorMedicamentos"
		add_child(gerenciador_medicamentos)

	iniciar_novo_dia()


func processar_tempo_dia(delta: float) -> void:
	if horario_atual == 2:
		return

	tempo_dia_restante = maxf(0.0, tempo_dia_restante - delta)
	if tempo_dia_restante <= 0.0 and horario_atual != 2:
		if tarefas_concluidas < tarefas_totais:
			modo_noturno = ModoNoturno.TAREFAS_PENDENTES
			iniciar_evento_terror()


func _process(delta: float) -> void:
	processar_tempo_dia(delta)


func iniciar_novo_dia() -> void:
	tarefas_concluidas = 0
	horario_atual = 0
	modo_noturno = ModoNoturno.NENHUM
	pontos_vigilia_ativos = false
	_limpar_rastros()

	var mult_t := 0.0
	if gerenciador_medicamentos != null:
		mult_t = gerenciador_medicamentos.obter_modificador("mult_tempo_dia", 0.0)
	tempo_dia_restante = maxf(30.0, duracao_dia_segundos * (1.0 + mult_t))

	# Desativa e esconde a silhueta no começo do dia
	if silhueta:
		silhueta.visible = false
		silhueta.process_mode = PROCESS_MODE_DISABLED
		if silhueta.has_method("desativar"):
			silhueta.desativar()

	# Reseta a iluminação para DIA
	if environment_noite and environment_noite.has_method("mudar_horario"):
		environment_noite.mudar_horario(0) # 0 = DIA
	horario_alterado.emit(0)

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

	# Se medicamento raro resolver tarefas imediatamente
	if gerenciador_medicamentos != null and gerenciador_medicamentos.obter_modificador("resolver_dia_imediato", 0.0) > 0.0:
		tarefas_concluidas = tarefas_totais

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
		if modo_noturno == ModoNoturno.NENHUM:
			modo_noturno = ModoNoturno.VIGILIA_DOMESTICA
		iniciar_evento_terror()
	elif tarefas_totais >= 2 and tarefas_concluidas == tarefas_totais - 1:
		horario_atual = 1
		if environment_noite and environment_noite.has_method("mudar_horario"):
			environment_noite.mudar_horario(1) # 1 = TARDE
		horario_alterado.emit(1)


func atualizar_hud() -> void:
	var msg: String
	if tarefas_concluidas < tarefas_totais:
		msg = "Dia %d | Tarefas: %d / %d" % [dia_atual, tarefas_concluidas, tarefas_totais]
	else:
		msg = "Dia %d | Vá para a casa e durma na cama!" % dia_atual

	if label_tarefas:
		label_tarefas.text = msg

	tarefas_atualizadas.emit(tarefas_concluidas, tarefas_totais, msg)


func ativar_vigilia_domestica() -> void:
	pontos_vigilia_ativos = true
	recargas_luz_disponiveis = 2
	if gerenciador_medicamentos != null:
		recargas_luz_disponiveis += int(gerenciador_medicamentos.obter_modificador("recargas_noturnas_extras", 0.0))
	_gerar_rastros_investigativos()


func recarregar_luz_vigilia() -> bool:
	if not pontos_vigilia_ativos or recargas_luz_disponiveis <= 0:
		return false
	recargas_luz_disponiveis -= 1
	status_temporario.emit("Luz recarregada no ponto de vigília! Restantes: %d" % recargas_luz_disponiveis)
	return true


func _gerar_rastros_investigativos() -> void:
	_limpar_rastros()
	for i in range(3):
		var rastro := Node3D.new()
		rastro.name = "RastroInvestigativo_%d" % i
		rastro.add_to_group("rastros_vigilia")
		add_child(rastro)
		rastros_investigativos.append(rastro)


func _limpar_rastros() -> void:
	for r in rastros_investigativos:
		if is_instance_valid(r):
			r.queue_free()
	rastros_investigativos.clear()


func iniciar_evento_terror() -> void:
	print("A noite caiu... A silhueta despertou.")
	horario_atual = 2

	if modo_noturno == ModoNoturno.NENHUM:
		if tarefas_concluidas >= tarefas_totais:
			modo_noturno = ModoNoturno.VIGILIA_DOMESTICA
		else:
			modo_noturno = ModoNoturno.TAREFAS_PENDENTES

	if modo_noturno == ModoNoturno.VIGILIA_DOMESTICA:
		ativar_vigilia_domestica()

	# Transiciona a iluminação para NOITE
	if environment_noite and environment_noite.has_method("mudar_horario"):
		environment_noite.mudar_horario(2) # 2 = NOITE
	horario_alterado.emit(2)

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
