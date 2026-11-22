extends SceneTree

## Teste Automatizado Headless (Fase 6) — QA Técnico, Debug Mode, Silver Tape & Build:
## 1) Renomeação DEBUG MODE e ocultação da linha "melhor marca" / "Recorde Endless".
## 2) Respawn diário da Silver Tape (sem softlock no Dia 3+ da Caixa d'Água).
## 3) Escala e clamps de dificuldade contínua do Dia 1 ao Dia 10.
## 4) Blindagem de atalhos debug [N]/[P] no Modo História + controles na Pausa.
## 5) SubViewports da hotbar (UPDATE_ONCE) e do menu de pílulas (UPDATE_WHEN_PARENT_VISIBLE).
## 6) QA espacial/colisão de world.tscn (Interactables, PontoRonda, Esconderijo, spawn Player).
## 7) Presença e filtros do preset export_presets.cfg (Windows Desktop x86_64).

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _enviar_tecla(hud: HUD, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.echo = false
	hud._unhandled_input(ev)


func _executar() -> void:
	print("=== INICIANDO TESTE FASE 6: QA, DEBUG MODE E BUILD ===\n")

	# ------------------------------------------------------------------
	# 1. Menu Principal: DEBUG MODE & LabelRecordeEndless sempre oculto
	# ------------------------------------------------------------------
	var cena_menu := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_verificar(cena_menu != null, "Não foi possível carregar res://scenes/ui/main_menu.tscn.")
	if cena_menu != null:
		var menu := cena_menu.instantiate() as MainMenu
		_verificar(menu != null, "Instância raiz de main_menu.tscn deve ser MainMenu.")
		if menu != null:
			root.add_child(menu)
			await process_frame

			var btn_debug := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoModoEndless") as Button
			_verificar(btn_debug != null and btn_debug.text == "DEBUG MODE", "BotaoModoEndless deve exibir 'DEBUG MODE'.")
			_verificar(menu.label_recorde_endless != null and not menu.label_recorde_endless.visible, "LabelRecordeEndless deve iniciar oculto.")
			menu.atualizar_recorde_endless()
			_verificar(menu.label_recorde_endless != null and not menu.label_recorde_endless.visible, "LabelRecordeEndless deve permanecer oculto após atualizar_recorde_endless().")

			menu.queue_free()
			await process_frame

	# ------------------------------------------------------------------
	# 2. Carga do world.tscn em Debug Mode + QA Espacial/Colisões
	# ------------------------------------------------------------------
	GameManager.definir_modo_jogo(GameManager.MODO_DEBUG)
	var cena_mundo := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena_mundo != null, "Não foi possível carregar res://scenes/levels/world.tscn.")
	if cena_mundo == null:
		_finalizar()
		return

	var mundo: Node3D = cena_mundo.instantiate() as Node3D
	root.add_child(mundo)
	current_scene = mundo
	await process_frame
	await process_frame

	var gerente: GameManager = mundo.get_node_or_null("GameManager") as GameManager
	_verificar(gerente != null, "GameManager deve existir em world.tscn.")
	if gerente == null:
		_finalizar()
		return

	_verificar(gerente.esta_em_modo_debug(), "GameManager.esta_em_modo_debug() deve ser true no Debug Mode.")
	_verificar(gerente.obter_nome_modo_jogo() == "DEBUG MODE", "obter_nome_modo_jogo() deve retornar 'DEBUG MODE'.")

	var player: Player = null
	for c in mundo.find_children("*", "CharacterBody3D", true, false):
		if c is Player:
			player = c as Player
			break
	_verificar(player != null, "Player deve existir em world.tscn.")

	var hud: HUD = null
	for cl in mundo.find_children("*", "CanvasLayer", true, false):
		if cl is HUD:
			hud = cl as HUD
			break
	_verificar(hud != null, "HUD deve existir em world.tscn.")

	var menu_pausa: MenuPausa = null
	for ctrl in mundo.find_children("*", "Control", true, false):
		if ctrl is MenuPausa:
			menu_pausa = ctrl as MenuPausa
			break
	_verificar(menu_pausa != null, "MenuPausa deve existir em world.tscn.")

	# QA Espacial & Colisões
	var interactables: Array[Interactable] = []
	var interactables_sem_colisor: int = 0
	for sb in mundo.find_children("*", "StaticBody3D", true, false):
		if sb is Interactable:
			var inter: Interactable = sb as Interactable
			interactables.append(inter)
			var tem_col_ativo: bool = false
			for ch in inter.find_children("*", "CollisionShape3D", true, false):
				if ch is CollisionShape3D and not (ch as CollisionShape3D).disabled:
					tem_col_ativo = true
					break
			if not tem_col_ativo:
				interactables_sem_colisor += 1
	_verificar(interactables.size() >= 18, "world.tscn deve conter >= 18 Interactables (encontrados: %d)." % interactables.size())
	_verificar(interactables_sem_colisor == 0, "Todos os Interactables devem iniciar com pelo menos 1 CollisionShape3D ativo (sem colisor: %d)." % interactables_sem_colisor)

	var pontos_ronda: Array[Node] = get_nodes_in_group("pontos_ronda")
	var esconderijos: Array[Node] = get_nodes_in_group("esconderijos")
	_verificar(pontos_ronda.size() >= 8, "world.tscn deve conter >= 8 PontoRonda (encontrados: %d)." % pontos_ronda.size())
	_verificar(esconderijos.size() >= 2, "world.tscn deve conter >= 2 Esconderijos (encontrados: %d)." % esconderijos.size())
	if player != null:
		_verificar(player.global_position.y >= 0.0 and player.global_position.distance_to(Vector3(-18.443, 0.571, 32.105)) < 2.0,
			"Player deve iniciar dentro da casa na posição esperada (atual: %s)." % str(player.global_position))

	# ------------------------------------------------------------------
	# 3. Silver Tape respawn Dia 1 -> Dia 2 -> Dia 3 + Caixa d'Água
	# ------------------------------------------------------------------
	var silver_tapes: Array[ItemColetavel] = []
	var caixa_agua: CaixaDaAguaTarefa = null
	for inter in interactables:
		if inter is ItemColetavel and (inter as ItemColetavel).id_item == &"silver_tape":
			silver_tapes.append(inter as ItemColetavel)
		elif inter is CaixaDaAguaTarefa:
			caixa_agua = inter as CaixaDaAguaTarefa

	_verificar(silver_tapes.size() >= 2, "Devem existir pelo menos 2 nós ItemColetavel de silver_tape em world.tscn (atual: %d)." % silver_tapes.size())
	_verificar(caixa_agua != null, "CaixaDaAguaTarefa deve existir em world.tscn.")

	if player != null and caixa_agua != null and silver_tapes.size() >= 2:
		for dia_sim in range(1, 4):
			if dia_sim > 1:
				gerente.dia_atual = dia_sim
				gerente.iniciar_novo_dia()
				await process_frame
			_verificar(gerente.dia_atual == dia_sim,
				"Dia simulado deve corresponder a %d (atual: %d)." % [dia_sim, gerente.dia_atual])

			for st in silver_tapes:
				_verificar(is_instance_valid(st) and not st.is_queued_for_deletion(),
					"Silver Tape '%s' não pode ser destruída no Dia %d." % [st.name, dia_sim])
				_verificar(st.visible and st.interacao_ativa,
					"Silver Tape '%s' deve estar visível e ativa no início do Dia %d." % [st.name, dia_sim])

			# Coleta todas as Silver Tapes neste dia
			for st in silver_tapes:
				st._executar_interacao(player)
				_verificar(not st.visible and not st.interacao_ativa,
					"Silver Tape '%s' deve ficar oculta/inativa após coleta no Dia %d." % [st.name, dia_sim])

			_verificar(player.possui_item(&"silver_tape", 1),
				"Player deve possuir silver_tape no inventário no Dia %d." % dia_sim)
			caixa_agua._executar_interacao(player)
			_verificar(caixa_agua.concluida,
				"CaixaDaAguaTarefa deve poder ser concluída no Dia %d sem softlock." % dia_sim)

	# ------------------------------------------------------------------
	# 4. Curva de Dificuldade e Clamps (Dia 1 ao Dia 10)
	# ------------------------------------------------------------------
	var prev_vel: float = 0.0
	for dia_idx in range(1, 11):
		var params: Dictionary = gerente.obter_parametros_dificuldade_dia(dia_idx)
		var mult_dia: float = float(params.get("mult_duracao_dia", 0.0))
		var vigilia: float = float(params.get("duracao_vigilia", 0.0))
		var mult_vel: float = float(params.get("mult_velocidade_monstros", 0.0))
		var mult_agr: float = float(params.get("mult_agressividade_silhueta", 0.0))
		var mult_vis: float = float(params.get("mult_visao_rondante", 0.0))
		var mult_int: float = float(params.get("mult_intervalo_eventos", 0.0))

		_verificar(mult_dia >= 0.55 and mult_dia <= 1.0, "Dia %d mult_duracao_dia fora do clamp: %f" % [dia_idx, mult_dia])
		_verificar(vigilia >= gerente.duracao_vigilia_segundos and vigilia <= 75.0, "Dia %d duracao_vigilia fora do clamp: %f" % [dia_idx, vigilia])
		_verificar(mult_vel >= 1.0 and mult_vel <= 1.38 and mult_vel >= prev_vel, "Dia %d mult_velocidade_monstros inválida: %f" % [dia_idx, mult_vel])
		_verificar(mult_agr >= 1.0 and mult_agr <= 1.65, "Dia %d mult_agressividade_silhueta fora do clamp: %f" % [dia_idx, mult_agr])
		_verificar(mult_vis >= 1.0 and mult_vis <= 1.35, "Dia %d mult_visao_rondante fora do clamp: %f" % [dia_idx, mult_vis])
		_verificar(mult_int >= 0.55 and mult_int <= 1.0, "Dia %d mult_intervalo_eventos fora do clamp: %f" % [dia_idx, mult_int])
		prev_vel = mult_vel

	# ------------------------------------------------------------------
	# 5. Atalhos Debug [N]/[P], Ocultação de Recorde em Pausa/GameOver e SubViewports
	# ------------------------------------------------------------------
	if hud != null:
		# Garantir ícone da Silver Tape criado após coleta acima e checar SubViewports UPDATE_ONCE
		_verificar(hud._viewport_icone != null and hud._viewport_icone.render_target_update_mode == SubViewport.UPDATE_ONCE,
			"LanternaIconViewport deve usar SubViewport.UPDATE_ONCE.")
		_verificar(hud._viewport_icone_silver_tape != null and hud._viewport_icone_silver_tape.render_target_update_mode == SubViewport.UPDATE_ONCE,
			"SilverTapeIconViewport deve usar SubViewport.UPDATE_ONCE.")

		# Debug Mode: [N] alterna dia/noite e [P] abre menu de pílulas
		_verificar(hud._atalhos_debug_ativos(), "Atalhos debug devem estar ativos no Debug Mode.")
		var horario_inicial: int = gerente.horario_atual
		_enviar_tecla(hud, KEY_N)
		_verificar(gerente.horario_atual == 2 and horario_inicial != 2,
			"[N] deve alternar para noite (2) no Debug Mode.")
		_enviar_tecla(hud, KEY_N)
		_verificar(gerente.horario_atual == 0,
			"[N] na noite deve avançar para o novo dia (0) no Debug Mode.")

		_enviar_tecla(hud, KEY_P)
		await process_frame
		_verificar(hud.menu_medicamentos != null and hud.menu_medicamentos.visible,
			"[P] deve abrir MenuEscolhaMedicamentos no Debug Mode.")
		if hud.menu_medicamentos != null:
			var sv_esq: SubViewport = hud.menu_medicamentos.subviewport_esq
			var sv_dir: SubViewport = hud.menu_medicamentos.subviewport_dir
			# SubViewportContainer gerencia o SubViewport filho (força UPDATE_ALWAYS quando visível);
			# o ganho de GPU ocorre ao permanecer desativado/não contínuo enquanto o menu está fechado.
			_verificar(sv_esq != null and sv_dir != null,
				"SubViewports de MenuEscolhaMedicamentos devem existir.")
		_enviar_tecla(hud, KEY_P)
		await process_frame
		_verificar(hud.menu_medicamentos == null or not hud.menu_medicamentos.visible,
			"[P] novamente deve fechar MenuEscolhaMedicamentos no Debug Mode.")
		if hud.menu_medicamentos != null:
			var sv_esq_fechado: SubViewport = hud.menu_medicamentos.subviewport_esq
			var sv_dir_fechado: SubViewport = hud.menu_medicamentos.subviewport_dir
			_verificar(sv_esq_fechado != null and sv_esq_fechado.render_target_update_mode != SubViewport.UPDATE_ALWAYS,
				"SubViewportEsq oculto não deve permanecer em UPDATE_ALWAYS (atual: %s)." % str(sv_esq_fechado.render_target_update_mode if sv_esq_fechado != null else -1))
			_verificar(sv_dir_fechado != null and sv_dir_fechado.render_target_update_mode != SubViewport.UPDATE_ALWAYS,
				"SubViewportDir oculto não deve permanecer em UPDATE_ALWAYS (atual: %s)." % str(sv_dir_fechado.render_target_update_mode if sv_dir_fechado != null else -1))

		if menu_pausa != null:
			menu_pausa._atualizar_status_fazenda()
			if menu_pausa.label_status_tarefas != null:
				_verificar(menu_pausa.label_status_tarefas.text.contains("DEBUG MODE"),
					"MenuPausa.LabelStatusTarefas deve exibir DEBUG MODE.")
			if menu_pausa.label_resumo_diario != null:
				_verificar(not menu_pausa.label_resumo_diario.text.contains("Recorde") and not menu_pausa.label_resumo_diario.text.contains("Melhor marca"),
					"MenuPausa.LabelResumoDiario não deve exibir linha de recorde/melhor marca.")
			if menu_pausa.label_controles != null:
				_verificar(menu_pausa.label_controles.text.contains("[N] Dia/Noite") and menu_pausa.label_controles.text.contains("[P] Pílulas"),
					"MenuPausa.LabelControles deve exibir dicas de [N] e [P] no Debug Mode.")

		# Modo História: bloqueia [N]/[P] sem override e oculta dicas debug na Pausa
		gerente.modo_jogo = GameManager.ModoJogo.HISTORIA
		hud.permitir_atalhos_debug_em_historia = false
		_verificar(not hud._atalhos_debug_ativos(), "Atalhos debug devem ficar bloqueados no Modo História por padrão.")
		var horario_historia: int = gerente.horario_atual
		_enviar_tecla(hud, KEY_N)
		_enviar_tecla(hud, KEY_P)
		await process_frame
		_verificar(gerente.horario_atual == horario_historia, "[N] não deve pular turno no Modo História.")
		_verificar(hud.menu_medicamentos == null or not hud.menu_medicamentos.visible, "[P] não deve abrir pílulas no Modo História.")

		if menu_pausa != null:
			menu_pausa._atualizar_status_fazenda()
			if menu_pausa.label_controles != null:
				_verificar(not menu_pausa.label_controles.text.contains("[N] Dia/Noite"),
					"MenuPausa.LabelControles não deve exibir dicas [N]/[P] no Modo História.")

	# TelaGameOver: sem linha de recorde / melhor marca
	var tela_go := TelaGameOver.new()
	root.add_child(tela_go)
	await process_frame
	tela_go.abrir({
		"causa": "Teste QA",
		"dia_atual": 3,
		"dias_sobrevividos": 2,
		"tarefas_rodada": 5,
		"recorde_dias": 9,
		"recorde_tarefas": 20,
		"novo_recorde": true
	})
	_verificar(tela_go._label_selo_recorde != null and not tela_go._label_selo_recorde.visible,
		"TelaGameOver não deve exibir selo de recorde.")
	_verificar(tela_go._label_resumo != null and not tela_go._label_resumo.text.contains("Recorde") and not tela_go._label_resumo.text.contains("Melhor marca"),
		"TelaGameOver._label_resumo não deve exibir linha de recorde/melhor marca.")
	tela_go.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# 6. Preset Windows 64-bit (export_presets.cfg)
	# ------------------------------------------------------------------
	var existe_preset: bool = FileAccess.file_exists("res://export_presets.cfg")
	_verificar(existe_preset, "res://export_presets.cfg deve existir.")
	if existe_preset:
		var conteudo_preset: String = FileAccess.get_file_as_string("res://export_presets.cfg")
		_verificar(conteudo_preset.contains("Windows Desktop"), "Preset deve configurar plataforma Windows Desktop.")
		_verificar(conteudo_preset.contains("x86_64"), "Preset deve configurar arquitetura x86_64.")
		_verificar(conteudo_preset.contains("builds/Delusio.exe"), "Preset deve apontar para builds/Delusio.exe.")
		_verificar(conteudo_preset.contains("scripts/tests/*"), "Preset deve excluir scripts/tests/* do build final.")
		_verificar(conteudo_preset.contains("assets/ui/Diário.blend"), "Preset deve excluir arquivos .blend fonte.")

	mundo.queue_free()
	await process_frame
	await process_frame
	BancoAudioDelusio.limpar_cache()
	_finalizar()


func _finalizar() -> void:
	if _falhas.is_empty():
		print("\nOK: Fase 6 validada (Debug Mode, Silver Tape respawn Dia 3+, clamps, atalhos, SubViewports, colisões e export_presets.cfg)!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas na Fase 6:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)
