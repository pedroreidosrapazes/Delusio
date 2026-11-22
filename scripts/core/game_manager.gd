class_name GameManager
extends Node

## Gerenciador principal do ciclo de dias, tarefas e eventos de terror.

static var instance: GameManager

signal dia_iniciado(dia: int)
signal noite_iniciada()
signal tarefas_atualizadas(concluidas: int, totais: int, mensagem: String)
signal status_temporario(mensagem: String)
signal horario_alterado(estado: int)
signal tempo_dia_atualizado(restante: float, total: float, horario: int)
signal vigilia_progresso_atualizado(progresso: float, concluida: bool, resumo: String)
signal jogador_capturado_na_noite(monstro: Node3D)
signal documento_lido_registrado(documento_id: StringName)

enum ModoNoturno { NENHUM = 0, VIGILIA_DOMESTICA = 1, TAREFAS_PENDENTES = 2 }
enum ModoJogo { ENDLESS = 0, HISTORIA = 1 }
static var modo_jogo_selecionado: int = ModoJogo.ENDLESS

var modo_noturno: int = ModoNoturno.NENHUM

@export_category("Configurações do Dia")
@export var modo_jogo: int = ModoJogo.ENDLESS
@export var dia_atual: int = 1
@export var tarefas_totais: int = 3
@export var duracao_dia_segundos: float = 180.0
@export var duracao_vigilia_segundos: float = 45.0
@export var exigir_conclusao_vigilia_para_dormir: bool = false

var tarefas_concluidas: int = 0
var horario_atual: int = 0
var tempo_dia_restante: float = 180.0
var duracao_dia_efetiva: float = 180.0

const GERENCIADOR_MEDICAMENTOS := preload("res://scripts/core/gerenciador_medicamentos.gd")
const DIRETOR_EVENTOS_NOITE_SCRIPT := preload("res://scripts/core/diretor_eventos_noite.gd")
const CENA_RONDANTE_FAZENDA := preload("res://scenes/monsters/rondante_fazenda.tscn")
const RASTRO_INVESTIGATIVO_SCRIPT := preload("res://scripts/interactables/rastro_investigativo.gd")

var pontos_vigilia_ativos: bool = false
var recargas_luz_disponiveis: int = 2
var rastros_investigativos: Array[Node3D] = []
var tempo_vigilia_restante: float = 0.0
var vigilia_concluida: bool = false
var checagens_janela_vigilia: int = 0
var rastros_inspecionados: int = 0
var fusiveis_religados_noite: int = 0
var _ultimo_segundo_emitido: int = -1

var gerenciador_medicamentos: GerenciadorMedicamentos = null
var documentos_lidos: Array[StringName] = []
var jornal_silhueta_lido: bool = false
var estagio_introducao_silhueta: int = Silhueta.EstagioIntroducao.NAO_INICIADA

@export_category("Referências da Cena")
@export var label_tarefas: Label
@export var silhueta: Node3D
@export var rondante: Node3D
@export var diretor_eventos_noite: Node
@export var ponto_intro_silhueta: Node3D
@export var camera_player: Camera3D
@export var environment_noite: WorldEnvironment
@export var radio: Node3D


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func definir_modo_jogo(modo: int) -> void:
	modo_jogo_selecionado = modo


func esta_em_modo_endless() -> bool:
	return modo_jogo == ModoJogo.ENDLESS


func obter_nome_modo_jogo() -> String:
	return "MODO HISTÓRIA" if modo_jogo == ModoJogo.HISTORIA else "MODO ENDLESS"


func _ready() -> void:
	modo_jogo = modo_jogo_selecionado
	if gerenciador_medicamentos == null:
		gerenciador_medicamentos = GerenciadorMedicamentos.new()
		gerenciador_medicamentos.name = "GerenciadorMedicamentos"
		add_child(gerenciador_medicamentos)

	_garantir_diretor_eventos_noite()
	_garantir_rondante_cena()
	_garantir_esconderijo_cena()
	_conectar_silhueta_introducao()
	iniciar_novo_dia()


func _conectar_silhueta_introducao() -> void:
	if silhueta != null and silhueta.has_signal("introducao_etapa_concluida"):
		if not silhueta.introducao_etapa_concluida.is_connected(_ao_concluir_etapa_silhueta):
			silhueta.introducao_etapa_concluida.connect(_ao_concluir_etapa_silhueta)


func _ao_concluir_etapa_silhueta(etapa: int) -> void:
	if etapa == int(Silhueta.EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA):
		estagio_introducao_silhueta = Silhueta.EstagioIntroducao.ETAPA_B_TESTE_LANTERNA
	elif etapa == int(Silhueta.EstagioIntroducao.ETAPA_B_TESTE_LANTERNA):
		estagio_introducao_silhueta = Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL


func registrar_documento_lido(documento_id: StringName) -> void:
	if documento_id != &"" and not documentos_lidos.has(documento_id):
		documentos_lidos.append(documento_id)
	if documento_id == &"jornal_silhueta":
		jornal_silhueta_lido = true
		if horario_atual == 1 and estagio_introducao_silhueta == Silhueta.EstagioIntroducao.NAO_INICIADA and silhueta != null:
			_ativar_silhueta_com_estagio(Silhueta.EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA)
	documento_lido_registrado.emit(documento_id)


func _ativar_silhueta_com_estagio(etapa: int) -> void:
	if silhueta == null:
		return
	estagio_introducao_silhueta = etapa
	silhueta.visible = true
	silhueta.process_mode = PROCESS_MODE_INHERIT
	if "camera" in silhueta and camera_player:
		silhueta.camera = camera_player
	if etapa == Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL:
		if "estagio_introducao" in silhueta:
			silhueta.estagio_introducao = Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL
		if silhueta.has_method("ativar"):
			silhueta.ativar()
	elif silhueta.has_method("iniciar_etapa_introducao"):
		silhueta.iniciar_etapa_introducao(etapa, ponto_intro_silhueta)
	elif silhueta.has_method("ativar"):
		silhueta.ativar()


func _garantir_diretor_eventos_noite() -> void:
	if diretor_eventos_noite != null:
		return
	diretor_eventos_noite = get_node_or_null("DiretorEventosNoite")
	if diretor_eventos_noite == null and get_parent() != null:
		diretor_eventos_noite = get_parent().get_node_or_null("DiretorEventosNoite")
	if diretor_eventos_noite == null:
		diretor_eventos_noite = DIRETOR_EVENTOS_NOITE_SCRIPT.new()
		diretor_eventos_noite.name = "DiretorEventosNoite"
		add_child(diretor_eventos_noite)


func _garantir_rondante_cena() -> void:
	if rondante != null:
		return
	if get_parent() != null:
		rondante = get_parent().get_node_or_null("RondanteFazenda") as Node3D
	if rondante == null:
		rondante = CENA_RONDANTE_FAZENDA.instantiate() as Node3D
		rondante.name = "RondanteFazenda"
		rondante.position = Vector3(8.0, 1.0, 28.0)
		if get_parent() != null:
			get_parent().call_deferred("add_child", rondante)
		else:
			add_child(rondante)


func _garantir_esconderijo_cena() -> void:
	if get_tree() == null:
		return
	if not get_tree().get_nodes_in_group("esconderijos").is_empty():
		return
	for node in get_tree().current_scene.find_children("*", "Esconderijo", true, false) if get_tree().current_scene != null else []:
		if node != null:
			return


func _obter_duracao_transicao_clima() -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	return 3.5


func obter_hora_formatada() -> String:
	if horario_atual == 2:
		if modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and exigir_conclusao_vigilia_para_dormir and not vigilia_concluida:
			return "NOITE • VIGÍLIA"
		return "NOITE"
	var frac: float = 1.0 - clampf(tempo_dia_restante / maxf(1.0, duracao_dia_efetiva), 0.0, 1.0)
	var minutos_totais: int = int(roundf(lerpf(360.0, 1080.0, frac))) # Relógio rural: 06:00 -> 18:00
	var h: int = clampi(minutos_totais / 60, 6, 18)
	var m: int = minutos_totais % 60
	return "%02d:%02d" % [h, m]


func processar_tempo_dia(delta: float) -> void:
	if horario_atual == 2:
		if modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and not vigilia_concluida and tempo_vigilia_restante > 0.0:
			tempo_vigilia_restante = maxf(0.0, tempo_vigilia_restante - delta)
			var seg_v: int = int(ceilf(tempo_vigilia_restante))
			if seg_v != _ultimo_segundo_emitido:
				_ultimo_segundo_emitido = seg_v
				_emitir_progresso_vigilia()
				tempo_dia_atualizado.emit(tempo_vigilia_restante, duracao_vigilia_segundos, horario_atual)
			if tempo_vigilia_restante <= 0.0:
				concluir_vigilia_domestica()
		return

	tempo_dia_restante = maxf(0.0, tempo_dia_restante - delta)
	var seg_atual: int = int(ceilf(tempo_dia_restante))
	if seg_atual != _ultimo_segundo_emitido:
		_ultimo_segundo_emitido = seg_atual
		tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)

	if horario_atual == 0 and tempo_dia_restante > 0.0 and tempo_dia_restante <= duracao_dia_efetiva * 0.35:
		horario_atual = 1
		if environment_noite and environment_noite.has_method("mudar_horario"):
			environment_noite.mudar_horario(1, _obter_duracao_transicao_clima())
		horario_alterado.emit(1)
		tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)

	if tempo_dia_restante <= 0.0 and horario_atual != 2:
		if tarefas_concluidas < tarefas_totais:
			modo_noturno = ModoNoturno.TAREFAS_PENDENTES
			iniciar_evento_terror()
		else:
			if modo_noturno == ModoNoturno.NENHUM:
				modo_noturno = ModoNoturno.VIGILIA_DOMESTICA
			iniciar_evento_terror()


func _process(delta: float) -> void:
	processar_tempo_dia(delta)


func iniciar_novo_dia() -> void:
	tarefas_concluidas = 0
	horario_atual = 0
	modo_noturno = ModoNoturno.NENHUM
	pontos_vigilia_ativos = false
	tempo_vigilia_restante = 0.0
	vigilia_concluida = false
	checagens_janela_vigilia = 0
	rastros_inspecionados = 0
	fusiveis_religados_noite = 0
	_ultimo_segundo_emitido = -1
	_limpar_rastros()

	var mult_t := 0.0
	if gerenciador_medicamentos != null:
		mult_t = gerenciador_medicamentos.obter_modificador("mult_tempo_dia", 0.0)
	tempo_dia_restante = maxf(30.0, duracao_dia_segundos * (1.0 + mult_t))
	duracao_dia_efetiva = tempo_dia_restante

	if dia_atual > 1 and estagio_introducao_silhueta != Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL:
		estagio_introducao_silhueta = Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL

	# Desativa e esconde a silhueta no começo do dia
	if silhueta:
		silhueta.visible = false
		silhueta.process_mode = PROCESS_MODE_DISABLED
		if silhueta.has_method("desativar"):
			silhueta.desativar()

	if rondante:
		rondante.visible = false
		rondante.process_mode = PROCESS_MODE_DISABLED
		if rondante.has_method("desativar"):
			rondante.desativar()

	if diretor_eventos_noite and diretor_eventos_noite.has_method("desativar"):
		diretor_eventos_noite.desativar()

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
	tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)
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
	elif tarefas_totais >= 2 and tarefas_concluidas == tarefas_totais - 1 and horario_atual == 0:
		horario_atual = 1
		if environment_noite and environment_noite.has_method("mudar_horario"):
			environment_noite.mudar_horario(1) # 1 = TARDE
		horario_alterado.emit(1)
		tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)


func atualizar_hud() -> void:
	var msg: String
	if tarefas_concluidas < tarefas_totais:
		msg = "Dia %d | Tarefas: %d / %d" % [dia_atual, tarefas_concluidas, tarefas_totais]
	elif exigir_conclusao_vigilia_para_dormir and modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and not vigilia_concluida:
		msg = "Dia %d | Vigília Noturna (%ds) — Espione a janela, fusível ou rastros!" % [dia_atual, int(ceilf(tempo_vigilia_restante))]
	else:
		msg = "Dia %d | Vá para a casa e durma na cama!" % dia_atual

	if label_tarefas:
		label_tarefas.text = msg

	tarefas_atualizadas.emit(tarefas_concluidas, tarefas_totais, msg)


func _emitir_progresso_vigilia() -> void:
	var total := maxf(1.0, duracao_vigilia_segundos)
	var progresso := 1.0 if vigilia_concluida else clampf(1.0 - (tempo_vigilia_restante / total), 0.0, 1.0)
	var resumo := "Vigília concluída!" if vigilia_concluida else "Vigília: %ds" % int(ceilf(tempo_vigilia_restante))
	vigilia_progresso_atualizado.emit(progresso, vigilia_concluida, resumo)


func ativar_vigilia_domestica() -> void:
	pontos_vigilia_ativos = true
	tempo_vigilia_restante = duracao_vigilia_segundos
	vigilia_concluida = false
	_ultimo_segundo_emitido = int(ceilf(tempo_vigilia_restante))
	recargas_luz_disponiveis = 2
	if gerenciador_medicamentos != null:
		recargas_luz_disponiveis += int(gerenciador_medicamentos.obter_modificador("recargas_noturnas_extras", 0.0))
	_gerar_rastros_investigativos()
	_emitir_progresso_vigilia()
	atualizar_hud()


func registrar_vigilia_janela() -> void:
	if horario_atual != 2 or modo_noturno != ModoNoturno.VIGILIA_DOMESTICA or vigilia_concluida:
		return
	checagens_janela_vigilia += 1
	tempo_vigilia_restante = maxf(0.0, tempo_vigilia_restante - 12.0)
	_emitir_progresso_vigilia()
	if tempo_vigilia_restante <= 0.0:
		concluir_vigilia_domestica()
	else:
		atualizar_hud()


func registrar_fusivel_religado() -> void:
	fusiveis_religados_noite += 1
	if horario_atual == 2 and modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and not vigilia_concluida:
		tempo_vigilia_restante = maxf(0.0, tempo_vigilia_restante - 15.0)
		_emitir_progresso_vigilia()
		if tempo_vigilia_restante <= 0.0:
			concluir_vigilia_domestica()
		else:
			atualizar_hud()


func registrar_rastro_inspecionado(_rastro: Node3D = null) -> void:
	rastros_inspecionados += 1
	if horario_atual == 2 and modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and not vigilia_concluida:
		tempo_vigilia_restante = maxf(0.0, tempo_vigilia_restante - 15.0)
		_emitir_progresso_vigilia()
		if tempo_vigilia_restante <= 0.0:
			concluir_vigilia_domestica()
		else:
			atualizar_hud()


func concluir_vigilia_domestica() -> void:
	if vigilia_concluida:
		return
	vigilia_concluida = true
	tempo_vigilia_restante = 0.0
	_emitir_progresso_vigilia()
	atualizar_hud()
	status_temporario.emit("A madrugada acalmou. Agora você pode dormir na cama.")


func recarregar_luz_vigilia() -> bool:
	if not pontos_vigilia_ativos or recargas_luz_disponiveis <= 0:
		return false
	recargas_luz_disponiveis -= 1
	status_temporario.emit("Luz recarregada no ponto de vigília! Restantes: %d" % recargas_luz_disponiveis)
	return true


func _gerar_rastros_investigativos() -> void:
	_limpar_rastros()
	var specs: Array[Dictionary] = [
		{
			"id": &"rastro_horta",
			"desc": "Pegadas arrastadas perto da horta... alguém parou aqui olhando a janela.",
			"hook": "LayoutMapaFase1/Setor2_PatioTarefas/HookHorta",
			"fallback": Vector3(-2.0, 0.571, 26.0)
		},
		{
			"id": &"rastro_cocho",
			"desc": "Marcas fundas de garras e terra revirada junto ao cocho.",
			"hook": "LayoutMapaFase1/Setor2_PatioTarefas/HookCocho",
			"fallback": Vector3(6.0, 0.571, 22.0)
		},
		{
			"id": &"rastro_sul",
			"desc": "Rastro estranho seguindo na direção da mata fechada ao sul.",
			"hook": "LayoutMapaFase1/Setor4_ZonaBreuNoturno/HookEntradaBreu",
			"fallback": Vector3(-8.0, 0.571, 45.0)
		}
	]

	var pai_mundo: Node = get_parent() if get_parent() != null else self
	for i in range(specs.size()):
		var spec := specs[i]
		var rastro: RastroInvestigativo = RASTRO_INVESTIGATIVO_SCRIPT.new()
		rastro.name = "RastroInvestigativo_%d" % i
		rastro.rastro_id = spec["id"]
		rastro.descricao_pista = spec["desc"]

		var pos_alvo: Vector3 = spec["fallback"]
		if pai_mundo != null:
			var marcador := pai_mundo.get_node_or_null(str(spec["hook"])) as Node3D
			if marcador != null:
				pos_alvo = marcador.position
		pai_mundo.add_child(rastro)
		if rastro is Node3D:
			(rastro as Node3D).position = pos_alvo
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
	tempo_dia_atualizado.emit(tempo_vigilia_restante if modo_noturno == ModoNoturno.VIGILIA_DOMESTICA else 0.0, duracao_dia_efetiva, horario_atual)

	if silhueta:
		_conectar_silhueta_introducao()
		if estagio_introducao_silhueta == Silhueta.EstagioIntroducao.NAO_INICIADA and dia_atual <= 1:
			_ativar_silhueta_com_estagio(Silhueta.EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA)
		elif estagio_introducao_silhueta == Silhueta.EstagioIntroducao.ETAPA_B_TESTE_LANTERNA:
			_ativar_silhueta_com_estagio(Silhueta.EstagioIntroducao.ETAPA_B_TESTE_LANTERNA)
		else:
			_ativar_silhueta_com_estagio(Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL)

	if rondante:
		rondante.visible = true
		rondante.process_mode = PROCESS_MODE_INHERIT
		if rondante.has_method("ativar"):
			rondante.ativar()

	if diretor_eventos_noite and diretor_eventos_noite.has_method("ativar"):
		diretor_eventos_noite.ativar()

	noite_iniciada.emit()


func registrar_captura_monstro(monstro: Node3D, player: Player) -> void:
	if player != null and player.esta_em_interacao_sequencia():
		player.cancelar_interacao_sequencia()
	if diretor_eventos_noite != null and diretor_eventos_noite.has_method("registrar_alivio_pos_susto"):
		diretor_eventos_noite.registrar_alivio_pos_susto()
	if get_tree() != null and get_tree().current_scene != null:
		for n in get_tree().current_scene.find_children("*", "FiltroDelusioControlador", true, false):
			if n.has_method("registrar_impulso_tensao"):
				n.registrar_impulso_tensao(0.55)
				break
	status_temporario.emit("Você foi alcançado na escuridão! Recue para um abrigo!")
	jogador_capturado_na_noite.emit(monstro)


func tentar_dormir(ignorar_vigilia: bool = false) -> void:
	if tarefas_concluidas >= tarefas_totais:
		if exigir_conclusao_vigilia_para_dormir and modo_noturno == ModoNoturno.VIGILIA_DOMESTICA and not vigilia_concluida and not ignorar_vigilia:
			var aviso_v := "Vigília em curso (%ds)! Espione a janela, cheque o quadro de luz ou os rastros." % int(ceilf(tempo_vigilia_restante))
			if label_tarefas:
				label_tarefas.text = aviso_v
			status_temporario.emit(aviso_v)
			return
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
