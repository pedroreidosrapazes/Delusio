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
signal segunda_chance_consumida(monstro: Node3D)
signal protecao_captura_alterada(ativa: bool)
signal noite_sobrevivida(dia_concluido: int, dias_sobrevividos: int, novo_recorde: bool)
signal game_over_disparado(resumo: Dictionary)
signal documento_lido_registrado(documento_id: StringName)

enum ModoNoturno { NENHUM = 0, VIGILIA_DOMESTICA = 1, TAREFAS_PENDENTES = 2 }
enum ModoJogo { ENDLESS = 0, HISTORIA = 1 }
const MODO_DEBUG: int = ModoJogo.ENDLESS
static var modo_jogo_selecionado: int = ModoJogo.ENDLESS

var modo_noturno: int = ModoNoturno.NENHUM

@export_category("Configurações do Dia")
@export var modo_jogo: int = ModoJogo.ENDLESS
@export var dia_atual: int = 1
@export var tarefas_totais: int = 3
@export var duracao_dia_segundos: float = 360.0
@export var duracao_vigilia_segundos: float = 45.0
@export var exigir_conclusao_vigilia_para_dormir: bool = false

var tarefas_concluidas: int = 0
var horario_atual: int = 0
var tempo_dia_restante: float = 360.0
var duracao_dia_efetiva: float = 360.0

const GERENCIADOR_MEDICAMENTOS := preload("res://scripts/core/gerenciador_medicamentos.gd")
const CENA_PESADELO_PATH: String = "res://scenes/levels/pesadelo.tscn"

@export var duracao_pesadelo_media: float = 20.0
var em_pesadelo: bool = false

var pontos_vigilia_ativos: bool = false
var recargas_luz_disponiveis: int = 2
var rastros_investigativos: Array[Node3D] = []
var tempo_vigilia_restante: float = 0.0
var vigilia_concluida: bool = true
var checagens_janela_vigilia: int = 0
var rastros_inspecionados: int = 0
var fusiveis_religados_noite: int = 0
var _ultimo_segundo_emitido: int = -1

var gerenciador_medicamentos: GerenciadorMedicamentos = null
var documentos_lidos: Array[StringName] = []
var jornal_silhueta_lido: bool = false
var estagio_introducao_silhueta: int = 0

var jogo_encerrado: bool = false
var cargas_segunda_chance_restantes: int = 0
var capturas_sofridas_na_noite: int = 0
var dias_sobrevividos: int = 0
var tarefas_concluidas_rodada: int = 0
var duracao_vigilia_efetiva: float = 45.0
var ultimo_resumo_game_over: Dictionary = {}
var caminho_save_endless: String = RegistroEndless.CAMINHO_PADRAO

@export_category("Referências da Cena")
@export var label_tarefas: Label
@export var silhueta: Node3D = null
@export var rondante: Node3D = null
@export var diretor_eventos_noite: Node = null
@export var ponto_intro_silhueta: Node3D = null
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


func esta_em_modo_debug() -> bool:
	return modo_jogo == MODO_DEBUG


func esta_em_modo_endless() -> bool:
	return esta_em_modo_debug()


func obter_nome_modo_jogo() -> String:
	return "MODO HISTÓRIA" if modo_jogo == ModoJogo.HISTORIA else "DEBUG MODE"


func _ready() -> void:
	modo_jogo = modo_jogo_selecionado
	if gerenciador_medicamentos == null:
		gerenciador_medicamentos = GerenciadorMedicamentos.new()
		gerenciador_medicamentos.name = "GerenciadorMedicamentos"
		add_child(gerenciador_medicamentos)

	if gerenciador_medicamentos.has_signal("escolha_aplicada") and not gerenciador_medicamentos.escolha_aplicada.is_connected(_ao_aplicar_escolha_medicamentos):
		gerenciador_medicamentos.escolha_aplicada.connect(_ao_aplicar_escolha_medicamentos)

	_garantir_esconderijo_cena()
	iniciar_novo_dia()


func _pode_persistir_save_endless() -> bool:
	if caminho_save_endless != RegistroEndless.CAMINHO_PADRAO:
		return true
	return DisplayServer.get_name() != "headless"


func _calcular_cargas_segunda_chance() -> int:
	if gerenciador_medicamentos != null and gerenciador_medicamentos.has_method("possui_protecao_segunda_captura"):
		return 1 if gerenciador_medicamentos.possui_protecao_segunda_captura() else 0
	return 0


func possui_protecao_captura_ativa() -> bool:
	return cargas_segunda_chance_restantes > 0


func obter_parametros_dificuldade_dia(dia: int = -1) -> Dictionary:
	var d: int = dia if dia > 0 else dia_atual
	var nivel: int = maxi(0, d - 1) if modo_jogo == ModoJogo.ENDLESS else 0
	return {
		"nivel": nivel,
		"mult_duracao_dia": maxf(0.55, 1.0 - float(nivel) * 0.06),
		"duracao_vigilia": clampf(duracao_vigilia_segundos + float(nivel) * 4.0, duracao_vigilia_segundos, 75.0),
		"mult_velocidade_monstros": minf(1.38, 1.0 + float(nivel) * 0.045),
		"mult_agressividade_silhueta": minf(1.65, 1.0 + float(nivel) * 0.08),
		"mult_visao_rondante": minf(1.35, 1.0 + float(nivel) * 0.04),
		"mult_intervalo_eventos": maxf(0.55, 1.0 - float(nivel) * 0.05)
	}


func _ao_aplicar_escolha_medicamentos(_opcao: int, _resultado: Dictionary) -> void:
	cargas_segunda_chance_restantes = _calcular_cargas_segunda_chance()
	protecao_captura_alterada.emit(cargas_segunda_chance_restantes > 0)

	if horario_atual == 0 and not jogo_encerrado:
		var mult_t: float = 0.0
		if gerenciador_medicamentos != null:
			mult_t = gerenciador_medicamentos.obter_modificador("mult_tempo_dia", 0.0)
		var params: Dictionary = obter_parametros_dificuldade_dia(dia_atual)
		var mult_dia_endless: float = float(params.get("mult_duracao_dia", 1.0))
		var nova_duracao: float = maxf(60.0, duracao_dia_segundos * mult_dia_endless * (1.0 + mult_t))
		var frac_restante: float = clampf(tempo_dia_restante / maxf(1.0, duracao_dia_efetiva), 0.0, 1.0)
		duracao_dia_efetiva = nova_duracao
		tempo_dia_restante = maxf(1.0, duracao_dia_efetiva * frac_restante)
		tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)

	if gerenciador_medicamentos != null and gerenciador_medicamentos.obter_modificador("resolver_dia_imediato", 0.0) > 0.0:
		if tarefas_concluidas < tarefas_totais:
			tarefas_concluidas = tarefas_totais
			tarefas_concluidas_rodada += tarefas_totais
			atualizar_hud()
			if modo_noturno == ModoNoturno.NENHUM:
				modo_noturno = ModoNoturno.VIGILIA_DOMESTICA
			iniciar_evento_terror()

	if radio and radio.has_method("tocar_noticia") and not jogo_encerrado:
		radio.tocar_noticia(dia_atual)


func registrar_documento_lido(documento_id: StringName) -> void:
	if documento_id != &"" and not documentos_lidos.has(documento_id):
		documentos_lidos.append(documento_id)
	documento_lido_registrado.emit(documento_id)


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
		return "NOITE"
	var frac: float = 1.0 - clampf(tempo_dia_restante / maxf(1.0, duracao_dia_efetiva), 0.0, 1.0)
	var minutos_brutos: float = lerpf(360.0, 1080.0, frac) # Relógio rural: 06:00 -> 18:00
	var minutos_totais: int = int(floorf(minutos_brutos / 5.0)) * 5
	var h: int = clampi(minutos_totais / 60, 6, 18)
	var m: int = minutos_totais % 60
	return "%02d:%02d" % [h, m]


func processar_tempo_dia(delta: float) -> void:
	if jogo_encerrado or em_pesadelo:
		return
	if horario_atual == 2:
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
	jogo_encerrado = false
	capturas_sofridas_na_noite = 0
	ultimo_resumo_game_over.clear()
	cargas_segunda_chance_restantes = _calcular_cargas_segunda_chance()

	tarefas_concluidas = 0
	horario_atual = 0
	modo_noturno = ModoNoturno.NENHUM
	pontos_vigilia_ativos = false
	tempo_vigilia_restante = 0.0
	vigilia_concluida = true
	checagens_janela_vigilia = 0
	rastros_inspecionados = 0
	fusiveis_religados_noite = 0
	_ultimo_segundo_emitido = -1

	var mult_t: float = 0.0
	if gerenciador_medicamentos != null:
		mult_t = gerenciador_medicamentos.obter_modificador("mult_tempo_dia", 0.0)
	var params: Dictionary = obter_parametros_dificuldade_dia(dia_atual)
	var mult_dia_endless: float = float(params.get("mult_duracao_dia", 1.0))
	duracao_vigilia_efetiva = float(params.get("duracao_vigilia", duracao_vigilia_segundos))
	tempo_dia_restante = maxf(60.0, duracao_dia_segundos * mult_dia_endless * (1.0 + mult_t))
	duracao_dia_efetiva = tempo_dia_restante

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
	protecao_captura_alterada.emit(cargas_segunda_chance_restantes > 0)
	tempo_dia_atualizado.emit(tempo_dia_restante, duracao_dia_efetiva, horario_atual)
	print("--- DIA %d INICIADO ---" % dia_atual)
	dia_iniciado.emit(dia_atual)

	if radio and radio.has_method("parar_radio"):
		radio.parar_radio()


func progredir_tarefa(_id_tarefa: String = "", _quantidade: int = 1) -> void:
	concluir_tarefa()


func concluir_tarefa(_id_tarefa: String = "") -> void:
	if jogo_encerrado:
		return
	tarefas_concluidas += 1
	tarefas_concluidas_rodada += 1
	atualizar_hud()

	if tarefas_concluidas >= tarefas_totais:
		if modo_noturno == ModoNoturno.NENHUM:
			modo_noturno = ModoNoturno.VIGILIA_DOMESTICA


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
	print("A noite caiu...")
	horario_atual = 2

	if modo_noturno == ModoNoturno.NENHUM:
		if tarefas_concluidas >= tarefas_totais:
			modo_noturno = ModoNoturno.VIGILIA_DOMESTICA
		else:
			modo_noturno = ModoNoturno.TAREFAS_PENDENTES

	# Transiciona a iluminação para NOITE
	if environment_noite and environment_noite.has_method("mudar_horario"):
		environment_noite.mudar_horario(2) # 2 = NOITE
	horario_alterado.emit(2)
	tempo_dia_atualizado.emit(0.0, duracao_dia_efetiva, horario_atual)
	atualizar_hud()
	noite_iniciada.emit()


func disparar_game_over(_monstro: Node3D = null) -> Dictionary:
	# Mecânica de morte/Game Over removida.
	return {}


func reiniciar_rodada_endless() -> void:
	jogo_encerrado = false
	GameManager.definir_modo_jogo(ModoJogo.ENDLESS)
	if get_tree() != null:
		get_tree().paused = false
		get_tree().reload_current_scene()


func tentar_dormir(_ignorar_vigilia: bool = false) -> void:
	if jogo_encerrado or em_pesadelo:
		return
	if tarefas_concluidas >= tarefas_totais:
		print("Você dormiu em segurança...")
		var dia_concluido: int = dia_atual
		dias_sobrevividos += 1
		var novo_rec: bool = false
		if _pode_persistir_save_endless():
			var reg: Dictionary = RegistroEndless.registrar_progresso_noite(dias_sobrevividos, tarefas_concluidas_rodada, caminho_save_endless)
			novo_rec = bool(reg.get("novo_recorde", false))
		noite_sobrevivida.emit(dia_concluido, dias_sobrevividos, novo_rec)
		dia_atual += 1
		if dia_concluido == 1 and DisplayServer.get_name() != "headless":
			_executar_sequencia_pesadelo()
		else:
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


func _executar_sequencia_pesadelo() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		iniciar_novo_dia()
		return

	var cena_pesadelo := load(CENA_PESADELO_PATH) as PackedScene
	if cena_pesadelo == null:
		push_warning("Cena de pesadelo não encontrada em: %s" % CENA_PESADELO_PATH)
		iniciar_novo_dia()
		return

	em_pesadelo = true
	var proc_anterior := process_mode
	process_mode = PROCESS_MODE_ALWAYS

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	fade_layer.process_mode = PROCESS_MODE_ALWAYS
	var fade_rect := ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_layer.add_child(fade_rect)
	tree.root.add_child(fade_layer)

	var tw_in := tree.create_tween()
	tw_in.tween_property(fade_rect, "color:a", 1.0, 0.7)
	await tw_in.finished

	var world_root := tree.current_scene
	var canvas_visiveis: Array[Dictionary] = []
	if world_root != null:
		for nodo in world_root.find_children("*", "CanvasLayer", true, false):
			var cl := nodo as CanvasLayer
			if cl != null:
				canvas_visiveis.append({"node": cl, "visible": cl.visible})
				cl.visible = false
		world_root.visible = false
		world_root.process_mode = PROCESS_MODE_DISABLED

	var pesadelo_inst := cena_pesadelo.instantiate()
	tree.root.add_child(pesadelo_inst)
	var cam_pesadelo := pesadelo_inst.find_child("Camera3D", true, false) as Camera3D
	if cam_pesadelo != null:
		cam_pesadelo.make_current()

	var tw_out := tree.create_tween()
	tw_out.tween_property(fade_rect, "color:a", 0.0, 0.7)
	await tw_out.finished

	var duracao := randf_range(maxf(5.0, duracao_pesadelo_media - 2.0), duracao_pesadelo_media + 2.0)
	await tree.create_timer(duracao).timeout

	var tw_end := tree.create_tween()
	tw_end.tween_property(fade_rect, "color:a", 1.0, 0.7)
	await tw_end.finished

	if is_instance_valid(pesadelo_inst):
		pesadelo_inst.queue_free()

	if world_root != null and is_instance_valid(world_root):
		world_root.process_mode = PROCESS_MODE_INHERIT
		world_root.visible = true
		for item in canvas_visiveis:
			var cl := item["node"] as CanvasLayer
			if cl != null and is_instance_valid(cl):
				cl.visible = bool(item["visible"])
	if camera_player != null and is_instance_valid(camera_player):
		camera_player.make_current()

	process_mode = proc_anterior
	em_pesadelo = false
	iniciar_novo_dia()

	var tw_wake := tree.create_tween()
	tw_wake.tween_property(fade_rect, "color:a", 0.0, 0.7)
	await tw_wake.finished

	if is_instance_valid(fade_layer):
		fade_layer.queue_free()


func recarregar_luz_vigilia() -> bool:
	if not pontos_vigilia_ativos or recargas_luz_disponiveis <= 0:
		return false
	recargas_luz_disponiveis -= 1
	return true


func registrar_captura_monstro(_monstro: Node3D, _player: Node3D = null) -> void:
	# Mecânica de morte/Game Over removida; método mantido para compatibilidade.
	pass


func registrar_fusivel_religado() -> void:
	fusiveis_religados_noite += 1


func registrar_rastro_inspecionado(_rastro: Node3D = null) -> void:
	rastros_inspecionados += 1


func registrar_vigilia_janela() -> void:
	checagens_janela_vigilia += 1


func concluir_vigilia_domestica() -> void:
	vigilia_concluida = true
	tempo_vigilia_restante = 0.0
	vigilia_progresso_atualizado.emit(1.0, true, "Vigília concluída.")
