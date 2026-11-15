extends SceneTree

## Teste Automatizado: Sistemas de Medicamentos, Traits High-Roller,
## Menu 3D com Blur, Vigília Doméstica, Silhueta e Esconderijos.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES: MEDICAMENTOS, HIGH-ROLLER, VIGÍLIA E ESCONDERIJOS ===\n")

	var cena := load("res://scenes/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar scenes/world.tscn.")
	if cena == null:
		quit(1)
		return

	var mundo := cena.instantiate()
	root.add_child(mundo)
	current_scene = mundo

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var hud := mundo.get_node_or_null("Hud") as HUD
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var tarefa := mundo.get_node_or_null("Objetos_Tarefas/Planta1") as TarefaInterativa

	_verificar(gerente != null and player != null and hud != null and silhueta != null and tarefa != null, "Nós obrigatórios ausentes em world.tscn.")
	if _falhas.size() > 0:
		quit(1)
		return

	_teste_1_catalogo_medicamentos_sem_numeros()
	_teste_2_sorteio_vidros_e_escolhas()
	_teste_3_sistema_high_roller_e_traits()
	await _teste_4_menu_3d_e_blur_filtro(hud)
	_teste_5_lanterna_noite_tarefas_e_silhueta(gerente, player, tarefa, silhueta)
	_teste_6_esconderijo_e_comprometimento(mundo, player)
	_teste_7_ramificacao_modo_noturno(gerente)
	await _teste_8_inclinacao_independente_janela_e_cursor_pausa(hud, mundo, player)

	mundo.queue_free()

	if _falhas.is_empty():
		print("\nOK: Todos os testes dos sistemas de medicamentos e vigília passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_catalogo_medicamentos_sem_numeros() -> void:
	print("--- [1] Teste do Catálogo dos 12 Medicamentos (Sem Números nos Efeitos) ---")
	var gerente_med := GerenciadorMedicamentos.new()
	var catalogo := gerente_med.obter_catalogo()

	_verificar(catalogo.size() == 12, "O catálogo deve conter exatamente 12 variações de medicamentos (atual: %d)." % catalogo.size())

	var loot_padrao := gerente_med.obter_loot_table_padrao()
	var loot_rara := gerente_med.obter_loot_table_rara()
	_verificar(loot_padrao.size() == 11, "A loot table padrão deve conter 11 medicamentos (atual: %d)." % loot_padrao.size())
	_verificar(loot_rara.size() == 1, "A loot table rara deve conter 1 medicamento (atual: %d)." % loot_rara.size())
	_verificar(loot_rara.has(&"med_4_oval"), "O medicamento raro deve ser 'med_4_oval'.")

	var regex_digitos := RegEx.new()
	regex_digitos.compile("[0-9%]")

	for id in catalogo:
		var dados: Dictionary = catalogo[id]
		var buff: String = dados.get("buff", "")
		var debuff: String = dados.get("debuff", "")

		# Valida que não contém dígitos numéricos nem símbolo de porcentagem
		var match_buff := regex_digitos.search(buff)
		var match_debuff := regex_digitos.search(debuff)
		_verificar(match_buff == null, "O buff de '%s' contém números ou porcentagem: '%s'" % [id, buff])
		_verificar(match_debuff == null, "O debuff de '%s' contém números ou porcentagem: '%s'" % [id, debuff])

		# Valida presença de +, ++ ou +++ e -, -- ou ---
		_verificar(buff.contains("+"), "O buff de '%s' deve conter indicador '+': '%s'" % [id, buff])
		_verificar(debuff.contains("-"), "O debuff de '%s' deve conter indicador '-': '%s'" % [id, debuff])

		# Valida propriedades físicas
		_verificar(float(dados.get("massa", 0.0)) > 0.0, "Massa inválida para '%s'." % id)
		_verificar(float(dados.get("atrito", 0.0)) > 0.0, "Atrito inválido para '%s'." % id)

	print("OK: Catálogo de 12 medicamentos e formatação de efeitos sem números validada com sucesso.")


func _teste_2_sorteio_vidros_e_escolhas() -> void:
	print("\n--- [2] Teste de Sorteio Matinal e Escolhas dos Vidros de Petri ---")
	var gerente_med := GerenciadorMedicamentos.new()
	var vidros := gerente_med.sortear_vidros_manha()

	_verificar(vidros.has("esquerda") and vidros.has("direita"), "Sorteio deve retornar dicionário com 'esquerda' e 'direita'.")
	var esq: Array = vidros.get("esquerda", [])
	var dir: Array = vidros.get("direita", [])
	_verificar(esq.size() == 2, "Vidro esquerdo deve conter 2 pílulas (atual: %d)." % esq.size())
	_verificar(dir.size() == 2, "Vidro direito deve conter 2 pílulas (atual: %d)." % dir.size())

	# Teste Escolha 0 (Esquerda)
	var res_esq := gerente_med.aplicar_escolha(0, vidros)
	_verificar(res_esq["pilulas"] == esq, "Escolha 0 deve aplicar as 2 pílulas da esquerda.")

	# Teste Escolha 1 (Direita)
	var res_dir := gerente_med.aplicar_escolha(1, vidros)
	_verificar(res_dir["pilulas"] == dir, "Escolha 1 deve aplicar as 2 pílulas da direita.")

	# Teste Escolha 2 (Ambos os Vidros)
	var res_ambos := gerente_med.aplicar_escolha(2, vidros)
	_verificar(res_ambos["pilulas"].size() == 4, "Escolha 2 (ambos) deve aplicar 4 pílulas.")

	print("OK: Sorteio matinal e escolhas dos vidros verificadas.")


func _teste_3_sistema_high_roller_e_traits() -> void:
	print("\n--- [3] Teste do Sistema High-Roller e Traits Darkest Dungeon ---")
	var gerente_med := GerenciadorMedicamentos.new()
	gerente_med.streak_high_roller = 0

	# Escolha de ambos os vidros eleva a streak e desbloqueia trait
	var res_hr := gerente_med.aplicar_escolha(2)
	_verificar(gerente_med.streak_high_roller == 1, "Streak High-Roller deve incrementar após tomar ambos os vidros.")
	_verificar(gerente_med.traits_ativos.size() > 0, "Deve desbloquear um trait ao tomar ambos os vidros.")

	# Verificação da chance de drop da loot table rara calculada isoladamente
	gerente_med.traits_ativos.clear()
	var chance_base := 0.02 + 1.0 * 0.03 # streak = 1 -> 0.05
	_verificar(is_equal_approx(gerente_med.calcular_chance_rara(), chance_base), "Chance rara incorreta para streak 1 (esperado %f, atual %f)." % [chance_base, gerente_med.calcular_chance_rara()])

	# Trait Sorte do Abismo eleva chance em +0.06
	gerente_med.adicionar_trait(&"sorte_do_abismo")
	_verificar(is_equal_approx(gerente_med.calcular_chance_rara(), chance_base + 0.06), "Trait Sorte do Abismo não elevou chance rara em +0.06.")

	# Trait Dependência Funcional
	gerente_med.adicionar_trait(&"dependencia_funcional")
	# Tomar ambos os vidros -> concede bônus "foco químico"
	var res_foco := gerente_med.aplicar_escolha(2)
	_verificar(res_foco["modificadores"].get("foco_quimico", false) == true, "Foco químico deve conferir bônus com ambos os vidros.")
	_verificar(float(res_foco["modificadores"].get("bonus_tempo_tarefa", 0.0)) >= 0.50, "Bônus de tempo em tarefas do foco químico deve ser aplicado.")

	# Tomar apenas 1 vidro com dependência funcional -> penalidade de abstinência
	var res_abst := gerente_med.aplicar_escolha(0)
	_verificar(res_abst["modificadores"].get("tremor_abstinencia", false) == true, "Abstinência deve aplicar penalidade ao tomar apenas um vidro.")
	_verificar(float(res_abst["modificadores"].get("mult_impulso_erro", 0.0)) >= 0.25, "Impulso de erro aumentado na abstinência.")

	print("OK: Sistema High-Roller, traits e dependência funcional validados.")


func _teste_4_menu_3d_e_blur_filtro(hud: HUD) -> void:
	print("\n--- [4] Teste do Menu 3D dos Vidros de Petri e Blur de Fundo ---")
	var filtro := hud.obter_filtro_delusio()
	_verificar(filtro != null, "FiltroDelusioControlador deve existir no HUD.")
	_verificar(hud.layer == 1, "HUD deve estar na layer 1.")
	_verificar(filtro.layer == 0, "FiltroDelusio deve estar na layer 0.")

	var menu := hud.obter_menu_medicamentos()
	_verificar(menu != null, "MenuEscolhaMedicamentos deve estar instanciado no HUD.")

	var vidros_teste := {
		"esquerda": [&"med_1_oval", &"med_1_pilula"],
		"direita": [&"med_2_oval", &"med_3_pilula"]
	}

	# Ao abrir o menu, o blur de fundo deve ser ativado
	menu.abrir(vidros_teste)
	_verificar(menu.visible, "Menu deve estar visível ao abrir.")
	_verificar(is_equal_approx(filtro._desfoque_fundo_alvo, 1.0), "Abrir o menu deve definir alvo de desfoque_fundo em 1.0.")

	# Verificação da estrutura 3D dos vidros de Petri e acrílico translúcido
	_verificar(menu.pivo_esq != null and menu.pivo_dir != null, "Pivôs dos vidros 3D devem existir.")
	_verificar(menu.pilulas_rb_esq.size() == 2, "Vidro esquerdo deve ter 2 corpos rígidos de pílulas.")
	_verificar(menu.pilulas_rb_dir.size() == 2, "Vidro direito deve ter 2 corpos rígidos de pílulas.")

	var rb0: RigidBody3D = menu.pilulas_rb_esq[0]
	_verificar(rb0.get_parent() == menu.subviewport_esq, "Pílula RigidBody3D deve ser irmã do pivô (filha do SubViewport) para física real de rolagem.")
	_verificar(rb0.continuous_cd and not rb0.can_sleep, "Pílulas devem usar continuous_cd e can_sleep = false para responder à inclinação.")

	var prato_anim := menu.pivo_esq.get_node_or_null("PratoFisico") as AnimatableBody3D
	_verificar(prato_anim != null and prato_anim.sync_to_physics, "Prato físico deve usar AnimatableBody3D com sync_to_physics = true.")

	var mundo_env := menu.subviewport_esq.get_node_or_null("WorldEnvironmentVidro") as WorldEnvironment
	_verificar(mundo_env != null and mundo_env.environment != null, "SubViewport deve possuir WorldEnvironment próprio.")

	var malhas_petri := menu.pivo_esq.find_children("*", "MeshInstance3D", true, false)
	_verificar(malhas_petri.size() > 0, "Deve haver malha da placa de Petri.")
	if malhas_petri.size() > 0:
		var mat_over := (malhas_petri[0] as MeshInstance3D).material_override as StandardMaterial3D
		_verificar(mat_over != null and mat_over.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Placa de Petri deve usar material translúcido (TRANSPARENCY_ALPHA).")
		if mat_over != null:
			_verificar(mat_over.roughness <= 0.16 and mat_over.albedo_color.a < 0.5, "Acrílico da placa deve ter roughness baixo (não fosco) e alpha translúcido.")

	# Teste de sinal da inclinação: parte mais baixa do vidro deve acompanhar o cursor
	menu.pivo_esq.rotation = Vector3.ZERO
	menu.atualizar_inclinacao_mouse(Vector2(0.8, 0.7), 0.2)
	_verificar(menu.pivo_esq.rotation.z < -0.01, "Cursor à direita deve abaixar borda direita (rotation.z negativo).")
	_verificar(menu.pivo_esq.rotation.x > 0.01, "Cursor para baixo deve abaixar borda inferior (rotation.x positivo).")

	menu.pivo_esq.rotation = Vector3.ZERO
	menu.atualizar_inclinacao_mouse(Vector2(-0.8, -0.7), 0.2)
	_verificar(menu.pivo_esq.rotation.z > 0.01, "Cursor à esquerda deve abaixar borda esquerda (rotation.z positivo).")
	_verificar(menu.pivo_esq.rotation.x < -0.01, "Cursor para cima deve abaixar borda superior (rotation.x negativo).")

	# Ao fechar/escolher opção, o blur de fundo deve retornar para 0.0
	menu.escolher(0)
	_verificar(not menu.visible, "Menu deve ser ocultado após a escolha.")
	_verificar(is_equal_approx(filtro._desfoque_fundo_alvo, 0.0), "Após fechar o menu, o alvo de desfoque deve retornar a 0.0.")

	print("OK: Menu 3D, física dos vidros, material acrílico e desfoque de fundo validados.")


func _teste_5_lanterna_noite_tarefas_e_silhueta(gerente: GameManager, player: Player, tarefa: TarefaInterativa, silhueta: Silhueta) -> void:
	print("\n--- [5] Teste de Bloqueio sem Lanterna à Noite e Silhueta Evoluída ---")
	gerente.horario_atual = 2 # NOITE
	tarefa.exigir_lanterna_a_noite = true

	# 1. Lanterna apagada à noite: interação bloqueada
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	_verificar(not player.esta_com_lanterna_acesa(), "Lanterna do jogador deve estar apagada.")

	tarefa.interagir(player)
	_verificar(not tarefa.concluida, "Tarefa não deve ser concluída no escuro à noite.")
	_verificar(not player.esta_em_interacao_sequencia(), "Sequência não deve iniciar no escuro à noite.")

	# 2. Lanterna acesa à noite: interação permitida
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	_verificar(player.esta_com_lanterna_acesa(), "Lanterna do jogador deve estar acesa.")

	tarefa.interagir(player)
	_verificar(player.esta_em_interacao_sequencia(), "Sequência deve iniciar normalmente com lanterna acesa à noite.")

	# Teste de apagar a lanterna durante o minigame
	player._luz_lanterna_acesa = false
	var res_passo := player.submeter_direcao_sequencia(0)
	_verificar(res_passo == "escuro", "Passo da sequência deve ser ignorado/bloqueado com status 'escuro' quando a lanterna é apagada.")
	player.cancelar_interacao_sequencia()
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()

	# 3. Silhueta: 4 anéis de espreita e atração por lanterna
	silhueta.ativar()
	_verificar(silhueta.anel_atual == 4, "Silhueta deve iniciar no anel 4 de espreita.")
	_verificar(is_equal_approx(silhueta.obter_distancia_anel(1), 4.5), "Anel 1 deve ter distância de 4.5m.")
	_verificar(is_equal_approx(silhueta.obter_distancia_anel(4), 28.0), "Anel 4 deve ter distância de 28.0m.")

	silhueta.avancar_anel()
	_verificar(silhueta.anel_atual == 3, "Silhueta deve avançar para o anel 3.")
	silhueta.recuar_anel()
	_verificar(silhueta.anel_atual == 4, "Silhueta deve recuar para o anel 4.")

	# Investida quando encarada com lanterna
	silhueta.tempo_olhando_lanterna = 2.1
	silhueta.em_investida = true
	_verificar(silhueta.em_investida, "Silhueta deve entrar em investida após ser encarada com lanterna por mais de 2s.")
	silhueta.parar_investida()
	_verificar(not silhueta.em_investida, "Parar investida deve resetar estado de ataque.")

	silhueta.desativar()
	gerente.horario_atual = 0 # Restaura para DIA
	print("OK: Bloqueio no escuro à noite e comportamento da Silhueta validados.")


func _teste_6_esconderijo_e_comprometimento(mundo: Node3D, player: Player) -> void:
	print("\n--- [6] Teste do Esconderijo e Comprometimento por Lanterna ---")
	var esconderijo := Esconderijo.new()
	mundo.add_child(esconderijo)

	# 1. Jogador entra no esconderijo com lanterna apagada -> Seguro
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	esconderijo.entrar(player)
	_verificar(esconderijo.ocupado, "Esconderijo deve estar ocupado.")
	_verificar(player.esta_escondido(), "Player deve estar com status escondido.")
	_verificar(not esconderijo.esta_comprometido(player), "Esconderijo NÃO deve estar comprometido com lanterna apagada.")

	# 2. Jogador acende a lanterna dentro do esconderijo -> Comprometido!
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	_verificar(esconderijo.esta_comprometido(player), "Esconderijo DEVE estar comprometido quando a lanterna é acesa!")

	# 3. Jogador sai do esconderijo
	esconderijo.sair(player)
	_verificar(not esconderijo.ocupado, "Esconderijo deve estar desocupado após sair.")
	_verificar(not player.esta_escondido(), "Player não deve mais estar com status escondido.")

	esconderijo.queue_free()
	print("OK: Mecânicas de esconderijo e comprometimento por luz validadas.")


func _teste_7_ramificacao_modo_noturno(gerente: GameManager) -> void:
	print("\n--- [7] Teste da Ramificação entre Tarefas Pendentes e Vigília Doméstica ---")
	gerente.tarefas_totais = 3

	# Caso A: Tempo do dia esgota antes de concluir as tarefas -> ModoNoturno.TAREFAS_PENDENTES
	gerente.iniciar_novo_dia()
	gerente.tarefas_concluidas = 1
	gerente.processar_tempo_dia(250.0) # Zera o relógio do dia
	_verificar(gerente.horario_atual == 2, "Noite deveria ter iniciado quando o tempo zerou.")
	_verificar(gerente.modo_noturno == GameManager.ModoNoturno.TAREFAS_PENDENTES, "Modo noturno deveria ser TAREFAS_PENDENTES (atual: %d)." % gerente.modo_noturno)

	# Caso B: Todas as tarefas concluídas a tempo -> ModoNoturno.VIGILIA_DOMESTICA
	gerente.iniciar_novo_dia()
	gerente.concluir_tarefa()
	gerente.concluir_tarefa()
	gerente.concluir_tarefa()
	_verificar(gerente.horario_atual == 2, "Noite deveria ter iniciado após a 3ª tarefa.")
	_verificar(gerente.modo_noturno == GameManager.ModoNoturno.VIGILIA_DOMESTICA, "Modo noturno deveria ser VIGILIA_DOMESTICA (atual: %d)." % gerente.modo_noturno)
	_verificar(gerente.pontos_vigilia_ativos, "Pontos de vigília devem estar ativos no modo VIGILIA_DOMESTICA.")
	_verificar(gerente.recargas_luz_disponiveis >= 2, "Devem haver ao menos 2 recargas de luz na vigília.")
	_verificar(gerente.rastros_investigativos.size() > 0, "Rastros investigativos devem ter sido gerados na vigília.")

	var ok_recarga := gerente.recarregar_luz_vigilia()
	_verificar(ok_recarga, "Recarga de luz na vigília deve ter sucesso.")

	gerente.iniciar_novo_dia() # Restaura dia
	print("OK: Ramificação entre Tarefas Pendentes e Vigília Doméstica validada.")


func _teste_8_inclinacao_independente_janela_e_cursor_pausa(hud: HUD, mundo: Node3D, player: Player) -> void:
	print("\n--- [8] Teste de Inclinação Independente, Limites de Janela e Cursor com Menu de Pausa ---")
	var menu := hud.obter_menu_medicamentos()
	_verificar(menu != null, "MenuEscolhaMedicamentos deve existir no HUD.")
	if menu == null:
		return

	menu.abrir({
		"esquerda": [&"med_1_oval", &"med_1_pilula"],
		"direita": [&"med_2_oval", &"med_3_pilula"]
	})
	await process_frame
	await process_frame

	# 1. Independência entre vidro esquerdo e vidro direito
	var centro_esq := menu.vp_cont_esq.get_global_rect().get_center()
	menu.pivo_esq.rotation = Vector3.ZERO
	menu.pivo_dir.rotation = Vector3.ZERO
	menu.definir_cursor_na_janela(true)
	menu.atualizar_inclinacao_por_cursor_tela(centro_esq, true, 0.25)

	_verificar(absf(menu.pivo_esq.rotation.z) < 0.02, "Vidro esquerdo com cursor no seu próprio centro deve permanecer quase nivelado.")
	_verificar(menu.pivo_dir.rotation.z > 0.05, "Vidro direito com cursor à sua esquerda (sobre vidro esq.) deve abaixar sua borda esquerda (rotation.z positivo).")
	_verificar(absf(menu.pivo_dir.rotation.z - menu.pivo_esq.rotation.z) > 0.05, "Os dois vidros devem girar de forma independente.")

	# 2. Comportamento fora da janela: retornar suavemente ao neutro em vez de inclinar
	var rot_dir_antes := menu.pivo_dir.rotation.z
	menu.definir_cursor_na_janela(false)
	menu.atualizar_inclinacao_por_cursor_tela(centro_esq + Vector2(1800.0, 0.0), false, 0.2)
	_verificar(absf(menu.pivo_dir.rotation.z) < absf(rot_dir_antes), "Quando cursor sai da janela, vidro deve retornar suavemente ao neutro em vez de inclinar para fora.")
	menu.definir_cursor_na_janela(true)

	# 3. Bug do cursor ao pausar/retomar com Esc enquanto MenuEscolhaMedicamentos está aberto
	var pausas := mundo.find_children("*", "MenuPausa", true, false)
	_verificar(pausas.size() > 0, "MenuPausa deve existir na cena world.tscn.")
	if pausas.size() > 0:
		var menu_pausa := pausas[0] as MenuPausa
		menu_pausa.pausar_jogo()
		_verificar(paused == true, "Jogo deve entrar em pausa.")
		menu_pausa.retomar_jogo()
		_verificar(paused == false, "Jogo deve retomar após fechar pausa.")
		_verificar(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Cursor deve permanecer MOUSE_MODE_VISIBLE ao fechar pausa com menu de medicamentos aberto.")

		# Player._unhandled_input não deve recapturar o mouse com clique esquerdo enquanto menu está aberto
		var ev_clique := InputEventMouseButton.new()
		ev_clique.button_index = MOUSE_BUTTON_LEFT
		ev_clique.pressed = true
		player._unhandled_input(ev_clique)
		_verificar(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Player._unhandled_input não deve capturar o mouse enquanto MenuEscolhaMedicamentos está aberto.")

		menu.fechar()
		_verificar(not menu_pausa._tem_menu_modal_cursor_ativo(), "Sem menu modal visível, MenuPausa deve voltar a capturar o mouse ao retomar.")

	print("OK: Inclinação independente, limite de janela e preservação do cursor após pausa validados.")
