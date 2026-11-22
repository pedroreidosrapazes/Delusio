extends SceneTree

## Teste Automatizado Headless — Fase 3 (Modo Endless, Game Over na 1ª Captura e Pílula de 2ª Chance):
## Valida:
## 1. Catálogo com med_3_redondo usando modelo 3D existente MEDICAMENTO 3 - REDONDO.blend
## 2. Game Over na 1ª captura sem pílula (Silhueta e Rondante), TelaGameOver e congelamento de IA/timer
## 3. Pílula de 2ª chance ativa protege da 1ª captura, libera HUD e mata na 2ª captura da mesma noite
## 4. Escalamento de dificuldade Endless do Dia 1 ao Dia 5
## 5. Boletins cíclicos do rádio no Dia 5+
## 6. Persistência local de recordes (RegistroEndless) + atualização do MainMenu

const CAMINHO_SAVE_TMP := "user://teste_fase3_endless_tmp.cfg"
var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _limpar_save_temporario() -> void:
	var caminho_real: String = ProjectSettings.globalize_path(CAMINHO_SAVE_TMP)
	if FileAccess.file_exists(caminho_real):
		DirAccess.remove_absolute(caminho_real)


func _executar() -> void:
	print("=== INICIANDO TESTES DA FASE 3: ENDLESS, GAME OVER E PÍLULA DE 2ª CHANCE ===\n")
	_limpar_save_temporario()

	GameManager.definir_modo_jogo(GameManager.ModoJogo.ENDLESS)
	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar res://scenes/levels/world.tscn.")
	if cena == null:
		quit(1)
		return

	var mundo := cena.instantiate() as Node3D
	root.add_child(mundo)
	current_scene = mundo
	await process_frame
	await physics_frame

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var hud := mundo.get_node_or_null("Hud") as HUD
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var rondante := mundo.get_node_or_null("RondanteFazenda") as RondanteFazenda
	var radio := gerente.radio if gerente != null else null

	_verificar(gerente != null and player != null and hud != null and silhueta != null and rondante != null, "Nós principais ausentes em world.tscn.")

	if _falhas.is_empty():
		gerente.caminho_save_endless = CAMINHO_SAVE_TMP
		_teste_1_pilula_segunda_chance_catalogo(gerente, hud)
		_teste_2_game_over_primeira_captura_sem_pilula(gerente, player, hud, silhueta, rondante)
		_teste_3_pilula_segura_primeira_e_mata_na_segunda(gerente, player, hud, silhueta, rondante)
		_teste_4_escalamento_dificuldade_endless(gerente)
		_teste_5_radio_ciclico_dia_avancado(radio)
		await _teste_6_persistencia_recorde_e_menu(gerente)

	mundo.queue_free()
	await process_frame
	_limpar_save_temporario()

	if _falhas.is_empty():
		print("\nOK: Todos os testes da Fase 3 (Endless, Game Over e Pílula de 2ª Chance) passaram!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas na Fase 3:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_pilula_segunda_chance_catalogo(gerente: GameManager, hud: HUD) -> void:
	print("--- [1] Teste da Pílula med_3_redondo no Catálogo e Placeholder ---")
	var g_med := gerente.gerenciador_medicamentos
	_verificar(g_med != null, "GerenciadorMedicamentos deve existir no GameManager.")
	if g_med == null:
		return

	var cat := g_med.obter_catalogo()
	_verificar(cat.has(&"med_3_redondo"), "Catálogo deve conter a pílula '&med_3_redondo'.")
	if cat.has(&"med_3_redondo"):
		var dados: Dictionary = cat[&"med_3_redondo"]
		var caminho_modelo: String = str(dados.get("modelo", ""))
		_verificar(caminho_modelo == "res://assets/medicamentos_e_placa/MEDICAMENTO 3 - REDONDO.blend", "med_3_redondo deve manter gancho para MEDICAMENTO 3 - REDONDO.blend.")

	var menu_med := hud.obter_menu_medicamentos()
	_verificar(menu_med != null, "MenuEscolhaMedicamentos deve existir no HUD.")
	if menu_med != null:
		menu_med.abrir({"esquerda": [&"med_3_redondo", &"med_1_oval"], "direita": [&"med_2_oval", &"med_2_pilula"]})
		_verificar(menu_med.pilulas_rb_esq.size() == 2, "MenuEscolhaMedicamentos deve instanciar as 2 pílulas do vidro esquerdo com placeholder ou modelo real.")
		var achou_pilula_3 := false
		for rb in menu_med.pilulas_rb_esq:
			if rb != null and rb.name == "Pilula_med_3_redondo":
				achou_pilula_3 = not rb.find_children("*", "MeshInstance3D", true, false).is_empty()
		_verificar(achou_pilula_3, "Pilula_med_3_redondo deve instanciar malha visual (placeholder ou .blend real) sem erros.")
		menu_med.fechar()

	_verificar(not g_med.possui_protecao_segunda_captura(), "Sem escolher a pílula, proteção de 2ª captura deve ser false.")
	g_med.aplicar_escolha(0, {"esquerda": [&"med_3_redondo", &"med_1_oval"], "direita": [&"med_2_oval", &"med_2_pilula"]})
	_verificar(g_med.possui_protecao_segunda_captura(), "Com med_3_redondo ativa, possui_protecao_segunda_captura() deve retornar true.")
	_verificar(gerente.cargas_segunda_chance_restantes == 1, "GameManager deve receber exatamente 1 carga de 2ª chance via escolha_aplicada.")

	# Limpa escolha para os testes seguintes começarem sem pílula
	g_med.aplicar_escolha(0, {"esquerda": [&"med_1_oval", &"med_1_redondo"], "direita": [&"med_2_oval", &"med_2_pilula"]})
	_verificar(gerente.cargas_segunda_chance_restantes == 0, "Sem med_3_redondo, cargas_segunda_chance_restantes deve zerar.")
	print("OK: Pílula de 2ª chance e fallback placeholder validados no catálogo, Menu 3D e GameManager.")


func _teste_2_game_over_primeira_captura_sem_pilula(gerente: GameManager, player: Player, hud: HUD, silhueta: Silhueta, rondante: RondanteFazenda) -> void:
	print("\n--- [2] Teste de Game Over na 1ª Captura Sem Pílula ---")
	gerente.dia_atual = 1
	gerente.dias_sobrevividos = 0
	gerente.tarefas_concluidas_rodada = 0
	gerente.iniciar_novo_dia()
	gerente.iniciar_evento_terror()

	var estado := {"game_over": 0, "causa": ""}
	var cb := func(resumo: Dictionary) -> void:
		estado["game_over"] += 1
		estado["causa"] = str(resumo.get("causa", ""))
	gerente.game_over_disparado.connect(cb)

	# Captura pela Silhueta sem pílula -> Game Over imediato
	gerente.registrar_captura_monstro(silhueta, player)
	_verificar(gerente.jogo_encerrado, "1ª captura sem pílula deve encerrar a partida (jogo_encerrado == true).")
	_verificar(estado["game_over"] == 1 and estado["causa"] == "Silhueta", "Game Over deve registrar causa 'Silhueta' (atual: %s)." % estado["causa"])
	_verificar(not paused, "Game Over não deve travar SceneTree.paused.")

	var tela_go := hud.obter_tela_game_over()
	_verificar(tela_go != null and tela_go.visible, "TelaGameOver deve ficar visível ao ocorrer Game Over.")

	# Verifica congelamento de timer e IA quando jogo_encerrado == true
	var tempo_antes: float = gerente.tempo_dia_restante
	gerente.processar_tempo_dia(3.0)
	_verificar(is_equal_approx(gerente.tempo_dia_restante, tempo_antes), "Timer do GameManager deve congelar após Game Over.")

	var pos_sil_antes := silhueta.global_position
	silhueta.em_investida = true
	silhueta._process(0.5)
	_verificar(silhueta.global_position.is_equal_approx(pos_sil_antes), "Silhueta não deve continuar avançando após Game Over.")

	var pos_rond_antes := rondante.global_position
	rondante.mudar_estado(RondanteFazenda.Estado.CACADA)
	rondante.ultima_posicao_vista_jogador = player.global_position
	rondante.processar_ia(0.5)
	_verificar(rondante.global_position.is_equal_approx(pos_rond_antes), "RondanteFazenda não deve avançar após Game Over.")

	# Também testa 1ª captura pelo Rondante após reset de dia
	gerente.iniciar_novo_dia()
	_verificar(not gerente.jogo_encerrado and (tela_go == null or not tela_go.visible), "Novo dia deve fechar TelaGameOver e reabrir partida.")
	gerente.iniciar_evento_terror()
	gerente.registrar_captura_monstro(rondante, player)
	_verificar(gerente.jogo_encerrado and estado["causa"] == "Rondante da Fazenda", "1ª captura pelo Rondante sem pílula deve dar Game Over com causa 'Rondante da Fazenda'.")

	gerente.game_over_disparado.disconnect(cb)
	gerente.iniciar_novo_dia()
	print("OK: Game Over imediato na 1ª captura, TelaGameOver e congelamento validados.")


func _teste_3_pilula_segura_primeira_e_mata_na_segunda(gerente: GameManager, player: Player, hud: HUD, silhueta: Silhueta, rondante: RondanteFazenda) -> void:
	print("\n--- [3] Teste da Pílula Ativa: Sobrevive à 1ª Captura e Morre na 2ª ---")
	gerente.dia_atual = 1
	gerente.iniciar_novo_dia()

	gerente.gerenciador_medicamentos.aplicar_escolha(0, {"esquerda": [&"med_3_redondo", &"med_1_oval"], "direita": [&"med_2_oval", &"med_2_pilula"]})
	_verificar(gerente.possui_protecao_captura_ativa(), "Proteção de captura deve estar ativa após escolher med_3_redondo.")
	var lbl_lanterna := hud.obter_label_estado_lanterna()
	_verificar(lbl_lanterna != null and lbl_lanterna.text.contains("2ª Chance"), "HUD deve sinalizar '2ª Chance' enquanto a pílula estiver protegendo o jogador.")

	gerente.iniciar_evento_terror()
	var contador := {"segunda_chance": 0, "game_over": 0}
	var cb_sc := func(_m: Node3D) -> void: contador["segunda_chance"] += 1
	var cb_go := func(_r: Dictionary) -> void: contador["game_over"] += 1
	gerente.segunda_chance_consumida.connect(cb_sc)
	gerente.game_over_disparado.connect(cb_go)

	# 1ª captura na noite -> salva pela pílula
	gerente.registrar_captura_monstro(silhueta, player)
	_verificar(not gerente.jogo_encerrado, "Com pílula ativa, 1ª captura NÃO deve causar Game Over.")
	_verificar(contador["segunda_chance"] == 1 and contador["game_over"] == 0, "1ª captura deve consumir 2ª chance sem disparar Game Over.")
	_verificar(gerente.cargas_segunda_chance_restantes == 0, "Carga de 2ª chance deve ser consumida para 0 após o golpe.")
	if lbl_lanterna != null:
		_verificar(not lbl_lanterna.text.contains("2ª Chance"), "Após consumir a proteção, indicador '2ª Chance' deve sumir do HUD.")
	if gerente.diretor_eventos_noite is DiretorEventosNoite:
		_verificar((gerente.diretor_eventos_noite as DiretorEventosNoite).janela_alivio_restante >= 7.5, "Diretor deve abrir janela de alívio após pílula segurar captura.")

	# 2ª captura na mesma noite -> Game Over fatal
	gerente.registrar_captura_monstro(rondante, player)
	_verificar(gerente.jogo_encerrado and contador["game_over"] == 1, "2ª captura na mesma noite deve causar Game Over mesmo tendo usado a pílula.")

	gerente.segunda_chance_consumida.disconnect(cb_sc)
	gerente.game_over_disparado.disconnect(cb_go)
	gerente.gerenciador_medicamentos.limpar_efeitos_diarios()
	gerente.iniciar_novo_dia()
	print("OK: Regra de 2ª captura exclusiva com pílula validada.")


func _teste_4_escalamento_dificuldade_endless(gerente: GameManager) -> void:
	print("\n--- [4] Teste de Escalamento Infinito do Modo Endless (Dia 1 -> Dia 5) ---")
	var d1: Dictionary = gerente.obter_parametros_dificuldade_dia(1)
	var d5: Dictionary = gerente.obter_parametros_dificuldade_dia(5)

	_verificar(is_equal_approx(float(d1["mult_duracao_dia"]), 1.0), "Dia 1 deve manter duração base 1.0.")
	_verificar(is_equal_approx(float(d1["mult_velocidade_monstros"]), 1.0), "Dia 1 deve manter velocidade 1.0.")
	_verificar(float(d5["mult_duracao_dia"]) < float(d1["mult_duracao_dia"]), "Dia 5 deve ter dia mais curto que o Dia 1.")
	_verificar(float(d5["duracao_vigilia"]) > float(d1["duracao_vigilia"]), "Dia 5 deve ter vigília mais longa que o Dia 1.")
	_verificar(float(d5["mult_velocidade_monstros"]) > float(d1["mult_velocidade_monstros"]), "Dia 5 deve aumentar velocidade dos monstros.")
	_verificar(float(d5["mult_agressividade_silhueta"]) > float(d1["mult_agressividade_silhueta"]), "Dia 5 deve aumentar agressividade da Silhueta.")
	_verificar(float(d5["mult_visao_rondante"]) > float(d1["mult_visao_rondante"]), "Dia 5 deve ampliar visão do Rondante.")
	_verificar(float(d5["mult_intervalo_eventos"]) < float(d1["mult_intervalo_eventos"]), "Dia 5 deve reduzir intervalo entre eventos noturnos.")
	print("OK: Curva de escalamento Endless validada do Dia 1 ao Dia 5.")


func _teste_5_radio_ciclico_dia_avancado(radio: Node) -> void:
	print("\n--- [5] Teste de Boletins Cíclicos do Rádio no Dia 5+ ---")
	_verificar(radio != null and radio is Radio, "Radio deve estar vinculado no GameManager.")
	if radio == null or not (radio is Radio):
		return
	var r := radio as Radio
	r.tocar_noticia(5)
	_verificar(r.esta_transmitindo(), "Rádio no Dia 5 deve transmitir boletim Endless ao invés de ficar sem falas.")
	_verificar(r.obter_texto_atual().contains("Dia 5"), "Boletim Endless do Dia 5 deve mencionar o dia atual (atual: %s)." % r.obter_texto_atual())
	r.parar_radio()
	print("OK: Boletins cíclicos Endless do rádio validados.")


func _teste_6_persistencia_recorde_e_menu(gerente: GameManager) -> void:
	print("\n--- [6] Teste de Persistência de Recorde Local e MainMenu ---")
	gerente.dia_atual = 1
	gerente.dias_sobrevividos = 0
	gerente.tarefas_concluidas_rodada = 0
	gerente.iniciar_novo_dia()
	gerente.tarefas_concluidas = gerente.tarefas_totais
	gerente.tarefas_concluidas_rodada = gerente.tarefas_totais
	gerente.tentar_dormir(true)
	await process_frame

	_verificar(gerente.dias_sobrevividos == 1 and gerente.dia_atual == 2, "Dormir deve incrementar dias_sobrevividos para 1 e avançar para o Dia 2.")
	var salvo: Dictionary = RegistroEndless.carregar(CAMINHO_SAVE_TMP)
	_verificar(int(salvo.get("recorde_dias", 0)) == 1, "RegistroEndless deve persistir recorde_dias == 1.")
	_verificar(int(salvo.get("recorde_tarefas", 0)) == gerente.tarefas_totais, "RegistroEndless deve persistir recorde_tarefas.")

	var cena_menu := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_verificar(cena_menu != null, "Não foi possível carregar main_menu.tscn para validar exibição do recorde.")
	if cena_menu != null:
		var menu := cena_menu.instantiate() as MainMenu
		root.add_child(menu)
		await process_frame
		menu.atualizar_recorde_endless(CAMINHO_SAVE_TMP)
		_verificar(menu.label_recorde_endless != null and menu.label_recorde_endless.text.contains("1 NOITE"), "MainMenu deve exibir o recorde salvo na LabelRecordeEndless.")
		menu.queue_free()
		await process_frame

	print("OK: Persistência local de recordes e exibição no MainMenu validadas.")
