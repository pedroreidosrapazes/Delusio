extends SceneTree

## Teste Automatizado Headless:
## CriaturaConfig, MonstroNoturnoBase, Silhueta refinada, RondanteFazenda,
## Estímulos Sonoros do Player e DiretorEventosNoite.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES: 2 MONSTROS NOTURNOS E DIRETOR DE EVENTOS ===\n")

	_teste_1_criatura_config()

	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar scenes/levels/world.tscn.")
	if cena == null:
		quit(1)
		return

	var mundo := cena.instantiate()
	root.add_child(mundo)
	current_scene = mundo

	await process_frame

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var rondante := mundo.get_node_or_null("RondanteFazenda") as RondanteFazenda
	var diretor := gerente.diretor_eventos_noite as DiretorEventosNoite if gerente != null else null
	var radio := gerente.radio as Radio if gerente != null else null
	var casa := mundo.get_node_or_null("Casa _final-col") as CasaControlador

	_verificar(gerente != null, "GameManager ausente em world.tscn.")
	_verificar(player != null, "Player ausente em world.tscn.")
	_verificar(silhueta != null, "Silhueta ausente em world.tscn.")
	_verificar(rondante != null, "RondanteFazenda ausente em world.tscn.")
	_verificar(diretor != null, "DiretorEventosNoite ausente no GameManager.")
	_verificar(radio != null, "Radio ausente em world.tscn.")
	_verificar(casa != null, "CasaControlador ausente em world.tscn.")

	if _falhas.is_empty():
		_teste_2_contrato_base_e_grupo(silhueta, rondante)
		_teste_3_silhueta_captura_e_esconderijo(gerente, player, silhueta, mundo)
		_teste_4_rondante_maquina_estados_e_placeholder(gerente, player, silhueta, rondante, mundo)
		_teste_5_diretor_eventos_e_coordenacao(gerente, player, silhueta, rondante, diretor, radio, casa)

	mundo.queue_free()
	await process_frame

	if _falhas.is_empty():
		print("\nOK: Todos os testes dos 2 monstros noturnos e diretor de eventos passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_criatura_config() -> void:
	print("--- [1] Teste de CriaturaConfig (Resource) ---")
	var cfg := CriaturaConfig.criar_padrao_rondante()
	_verificar(cfg is Resource, "CriaturaConfig deve herdar de Resource.")
	_verificar(cfg.nome_criatura == "Rondante da Fazenda", "Nome padrão do Rondante incorreto.")
	_verificar(cfg.velocidade_patrulha > 0.0, "velocidade_patrulha deve ser > 0.")
	_verificar(cfg.velocidade_perseguicao > cfg.velocidade_patrulha, "velocidade_perseguicao deve superar velocidade_patrulha.")
	_verificar(cfg.raio_visao > 0.0, "raio_visao deve ser > 0.")
	_verificar(cfg.angulo_visao_graus > 0.0 and cfg.angulo_visao_graus <= 360.0, "angulo_visao_graus fora da faixa válida.")
	_verificar(cfg.raio_audicao_passos > 0.0, "raio_audicao_passos deve ser > 0.")
	_verificar(cfg.raio_audicao_corrida > cfg.raio_audicao_passos, "raio_audicao_corrida deve superar raio_audicao_passos.")
	_verificar(cfg.intervalo_min_evento > 0.0, "intervalo_min_evento deve ser > 0.")
	_verificar(cfg.sensivel_a_luz == true, "sensivel_a_luz deve iniciar true no padrão.")
	_verificar(cfg.tempo_tolerancia_esconderijo > 0.0, "tempo_tolerancia_esconderijo deve ser > 0.")

	var cfg_sil := CriaturaConfig.criar_padrao_silhueta()
	_verificar(cfg_sil.nome_criatura == "Silhueta", "Nome padrão da Silhueta incorreto.")
	print("OK: CriaturaConfig validado.")


func _teste_2_contrato_base_e_grupo(silhueta: Silhueta, rondante: RondanteFazenda) -> void:
	print("\n--- [2] Teste de Contrato Base e Grupo 'monstros_noturnos' ---")
	_verificar(silhueta is MonstroNoturnoBase, "Silhueta deve herdar de MonstroNoturnoBase.")
	_verificar(rondante is MonstroNoturnoBase, "RondanteFazenda deve herdar de MonstroNoturnoBase.")
	_verificar(silhueta.is_in_group("monstros_noturnos"), "Silhueta deve pertencer ao grupo 'monstros_noturnos'.")
	_verificar(rondante.is_in_group("monstros_noturnos"), "RondanteFazenda deve pertencer ao grupo 'monstros_noturnos'.")

	for monstro in [silhueta, rondante]:
		_verificar(monstro.has_method("ativar"), "%s deve implementar ativar()." % monstro.name)
		_verificar(monstro.has_method("desativar"), "%s deve implementar desativar()." % monstro.name)
		_verificar(monstro.has_method("receber_estimulo_sonoro"), "%s deve implementar receber_estimulo_sonoro()." % monstro.name)
		_verificar(monstro.has_method("receber_foco_lanterna"), "%s deve implementar receber_foco_lanterna()." % monstro.name)
	print("OK: Contrato MonstroNoturnoBase e grupo validados.")


func _teste_3_silhueta_captura_e_esconderijo(gerente: GameManager, player: Player, silhueta: Silhueta, mundo: Node3D) -> void:
	print("\n--- [3] Teste da Silhueta: API Legada, Esconderijo no Escuro e Captura ---")
	gerente.iniciar_evento_terror()
	_verificar(silhueta.ativa, "Silhueta deve ficar ativa ao iniciar a noite.")
	_verificar(silhueta.DISTANCIAS_ANEIS.size() == 4, "DISTANCIAS_ANEIS deve manter 4 anéis.")
	_verificar(silhueta.anel_atual == 4, "Silhueta deve iniciar no anel 4.")

	silhueta.avancar_anel()
	_verificar(silhueta.anel_atual == 3, "avancar_anel() deve reduzir para anel 3.")
	silhueta.recuar_anel()
	_verificar(silhueta.anel_atual == 4, "recuar_anel() deve retornar para anel 4.")

	# Esconderijo no escuro cancela investida
	var esconderijo := Esconderijo.new()
	mundo.add_child(esconderijo)
	esconderijo.global_position = player.global_position

	var estado_evitada := {"chamado": false}
	silhueta.investida_evitada_esconderijo.connect(func(_p): estado_evitada["chamado"] = true)

	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	esconderijo.entrar(player)
	silhueta.anel_atual = 2
	silhueta.em_investida = true
	silhueta._process(0.05)

	_verificar(not silhueta.em_investida, "Silhueta em investida deve cancelar ataque quando jogador está escondido no escuro.")
	_verificar(silhueta.anel_atual == 3, "Silhueta deve recuar um anel ao perder alvo para esconderijo no escuro.")
	_verificar(estado_evitada["chamado"], "Sinal investida_evitada_esconderijo deve ser emitido.")

	esconderijo.sair(player)
	esconderijo.queue_free()

	# Captura real a curta distância sem travar o loop
	var estado_captura := {"silhueta": false, "gm": false}
	silhueta.captura_realizada.connect(func(_p): estado_captura["silhueta"] = true)
	gerente.jogador_capturado_na_noite.connect(func(m):
		if m == silhueta:
			estado_captura["gm"] = true
	)

	if gerente.diretor_eventos_noite is DiretorEventosNoite:
		(gerente.diretor_eventos_noite as DiretorEventosNoite).janela_alivio_restante = 0.0

	silhueta.em_investida = true
	silhueta.global_position = player.global_position + Vector3(0.5, 0.0, 0.0)
	silhueta.altura_padrao = player.global_position.y
	silhueta._process(0.05)

	_verificar(estado_captura["silhueta"], "Silhueta deve emitir captura_realizada ao concluir investida a curta distância.")
	_verificar(estado_captura["gm"], "GameManager deve receber registro de captura sem travar o loop.")
	_verificar(not silhueta.em_investida, "Após captura, investida deve resetar para evitar loop infinito.")
	_verificar(not paused, "Captura não deve travar o SceneTree em pausa.")

	gerente.iniciar_novo_dia()
	print("OK: Silhueta refinada validada com sucesso.")


func _teste_4_rondante_maquina_estados_e_placeholder(gerente: GameManager, player: Player, silhueta: Silhueta, rondante: RondanteFazenda, mundo: Node3D) -> void:
	print("\n--- [4] Teste do RondanteFazenda: Placeholder, Patrulha, Som, Caçada, Esconderijo e Luz ---")

	# 1. Placeholder visual modular
	_verificar(rondante.visual_placeholder != null and rondante.visual_placeholder is MeshInstance3D, "RondanteFazenda deve conter filho VisualPlaceholder (MeshInstance3D).")
	var olho_esq := rondante.visual_placeholder.get_node_or_null("OlhoEsquerdo") as MeshInstance3D
	var olho_dir := rondante.visual_placeholder.get_node_or_null("OlhoDireito") as MeshInstance3D
	_verificar(olho_esq != null and olho_dir != null, "VisualPlaceholder deve conter OlhoEsquerdo e OlhoDireito.")
	if olho_esq != null:
		var mat_olho := olho_esq.material_override as StandardMaterial3D
		_verificar(mat_olho != null and mat_olho.emission_enabled, "Olhos do Rondante devem possuir emissão sutil configurada.")
	_verificar(rondante.nav_agent != null and rondante.nav_agent is NavigationAgent3D, "RondanteFazenda deve possuir NavigationAgent3D.")

	# 2. Estado inicial no DIA: INATIVO
	gerente.iniciar_novo_dia()
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.INATIVO, "Durante o DIA, RondanteFazenda deve estar INATIVO.")

	# 3. Ativação à NOITE -> PATRULHA e movimentação fallback sem NavMesh
	gerente.iniciar_evento_terror()
	if gerente.diretor_eventos_noite is DiretorEventosNoite:
		(gerente.diretor_eventos_noite as DiretorEventosNoite).janela_alivio_restante = 0.0

	_verificar(rondante.ativa and rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "À noite, RondanteFazenda deve iniciar em PATRULHA.")

	# Posiciona player longe e escondido temporariamente para isolar teste de patrulha
	var pos_player_orig := player.global_position
	rondante.global_position = Vector3(50.0, 0.5, 50.0)
	player.global_position = Vector3(-100.0, 2.0, -100.0)
	var pos_antes_patrulha := rondante.global_position
	rondante.processar_ia(0.5)
	_verificar(rondante.global_position.distance_to(pos_antes_patrulha) > 0.2, "Em PATRULHA, Rondante deve se mover em direção ao waypoint mesmo sem NavMesh.")

	# 4. Estímulo sonoro do Player -> PATRULHA -> INVESTIGANDO
	player.global_position = Vector3(45.0, 0.5, 50.0)
	rondante.global_position = Vector3(55.0, 0.5, 50.0)
	rondante.look_at(Vector3(65.0, 0.5, 50.0), Vector3.UP) # Olhando para longe do player
	player.emitir_som(18.0, "corrida")

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.INVESTIGANDO, "Som de corrida próximo deve levar Rondante para INVESTIGANDO (atual: %d)." % rondante.estado_atual)
	_verificar(rondante.ultima_posicao_som.distance_to(player.global_position) < 0.1, "Rondante deve armazenar última posição do som emitido.")

	# Teste também de erro na sequência disparando som
	var seq_som := {"recebido": false, "tipo": ""}
	player.som_emitido.connect(func(_p, _r, t):
		if t == "erro_sequencia":
			seq_som["recebido"] = true
			seq_som["tipo"] = t
	)
	var tarefa := mundo.get_node_or_null("Objetos_Tarefas/Planta1") as TarefaInterativa
	if tarefa != null:
		player._luz_lanterna_acesa = true
		player._atualizar_aparencia_lanterna()
		tarefa.interagir(player)
		if player.esta_em_interacao_sequencia():
			var dir_errada := int((player._desafio_sequencia.sequencia[0] + 1) % 4)
			player.submeter_direcao_sequencia(dir_errada)
			player.cancelar_interacao_sequencia()
			_verificar(seq_som["recebido"], "Erro no minigame de sequência deve emitir estímulo sonoro.")

	# 5. Avistar jogador fora de esconderijo -> INVESTIGANDO -> CACADA
	rondante.global_position = Vector3(40.0, 0.5, 50.0)
	player.global_position = Vector3(46.0, 0.5, 50.0)
	rondante.look_at(player.global_position, Vector3.UP)
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	rondante.processar_ia(0.1)

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.CACADA, "Ao avistar o jogador fora de esconderijo, Rondante deve entrar em CACADA.")

	# 6. Fuga via Esconderijo no escuro e silêncio -> CACADA -> PATRULHA
	var esconderijo := Esconderijo.new()
	mundo.add_child(esconderijo)
	esconderijo.global_position = Vector3(60.0, 0.5, 50.0)
	player.global_position = esconderijo.global_position
	# Jogador está a 20m, fora de vista imediata do último instante, e entra no abrigo sem lanterna
	esconderijo.entrar(player)
	_verificar(not rondante.pode_ver_jogador(player), "Rondante não deve ver jogador oculto em esconderijo no escuro sem ter sido visto no último instante.")

	# Avança tempo além de tempo_tolerancia_esconderijo
	var tempo_espera := rondante.config.tempo_tolerancia_esconderijo + 1.0
	var passos := int(ceilf(tempo_espera / 0.25))
	for i in range(passos):
		rondante.processar_ia(0.25)

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Após checar ao redor sem encontrar o jogador escondido e silencioso, Rondante deve voltar para PATRULHA (atual: %d)." % rondante.estado_atual)

	esconderijo.sair(player)
	esconderijo.queue_free()

	# 7. Contraste tático com a luz: lanterna no Rondante atordoa e avança anel da Silhueta
	silhueta.ativar()
	silhueta.anel_atual = 4
	rondante.cooldown_atordoamento_restante = 0.0
	rondante.tempo_foco_lanterna_acumulado = 0.0
	rondante.receber_foco_lanterna(0.5)

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.ATORDOADO_LUZ, "Foco direto da lanterna deve colocar Rondante em ATORDOADO_LUZ.")
	_verificar(rondante.cooldown_atordoamento_restante > 0.0, "Atordoamento por luz deve ativar cooldown.")
	_verificar(silhueta.anel_atual == 3, "Atordoar o Rondante com a lanterna deve criar o dilema tático avançando o anel da Silhueta.")

	# Recuperação do atordoamento
	rondante.processar_ia(rondante.duracao_atordoamento_luz + 0.2)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.INVESTIGANDO or rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Após fim do atordoamento, Rondante deve sair de ATORDOADO_LUZ.")

	player.global_position = pos_player_orig
	gerente.iniciar_novo_dia()
	print("OK: Máquina de estados e placeholder do RondanteFazenda validados.")


func _teste_5_diretor_eventos_e_coordenacao(gerente: GameManager, player: Player, silhueta: Silhueta, rondante: RondanteFazenda, diretor: DiretorEventosNoite, radio: Radio, casa: CasaControlador) -> void:
	print("\n--- [5] Teste do DiretorEventosNoite e Coordenação dos 2 Monstros ---")

	# 1. Não ativa durante o DIA
	gerente.iniciar_novo_dia()
	diretor.ativar()
	_verificar(not diretor.ativo, "DiretorEventosNoite não deve ativar quando horario_atual != 2 (DIA).")

	# 2. Ativa em NOITE (VIGILIA_DOMESTICA)
	gerente.tarefas_concluidas = gerente.tarefas_totais
	gerente.modo_noturno = GameManager.ModoNoturno.VIGILIA_DOMESTICA
	gerente.iniciar_evento_terror()
	_verificar(diretor.ativo, "DiretorEventosNoite deve ativar automaticamente ao iniciar a NOITE.")
	_verificar(diretor.marcadores_som.size() >= 3, "Diretor deve registrar ao menos 3 Marker3D de som ambiental.")

	# 3. Evento: Estática direcional do rádio
	diretor.cooldown_restante = 0.0
	diretor.evento_em_andamento = false
	rondante.global_position = Vector3(8.0, 0.5, 28.0) # perto do celeiro
	var ev_radio := diretor.disparar_estatica_radio()
	_verificar(ev_radio.get("tipo", &"") == &"estatica_radio", "disparar_estatica_radio deve retornar evento válido.")
	_verificar(radio.ultima_zona_estatica == "celeiro", "Rádio deve indicar estática próxima do celeiro (atual: %s)." % radio.ultima_zona_estatica)

	# 4. Cooldown impede spam simultâneo de dois eventos
	var ev_spam := diretor.disparar_som_localizado()
	_verificar(ev_spam.is_empty(), "Cooldown deve impedir disparo de segundo evento logo após o primeiro.")

	# 5. Evento: Sons localizados em Marker3D
	diretor.cooldown_restante = 0.0
	var ev_som := diretor.disparar_som_localizado("GalhosAtrasJogador")
	_verificar(ev_som.get("tipo", &"") == &"som_localizado", "disparar_som_localizado deve disparar evento.")
	_verificar(ev_som.get("marcador", "") == "GalhosAtrasJogador", "Marcador escolhido deveria ser GalhosAtrasJogador.")

	# 6. Evento: Queda temporária de fusível / ponto de luz em VIGILIA_DOMESTICA
	diretor.cooldown_restante = 0.0
	_verificar(gerente.pontos_vigilia_ativos, "Pontos de vigília devem estar ativos antes da queda de fusível.")
	var ev_fusivel := diretor.disparar_queda_fusivel(2.0)
	_verificar(ev_fusivel.get("tipo", &"") == &"queda_fusivel", "disparar_queda_fusivel deve iniciar queda.")
	_verificar(diretor.queda_fusivel_ativa and diretor.evento_em_andamento, "Queda de fusível deve bloquear outros eventos simultâneos.")
	_verificar(not gerente.pontos_vigilia_ativos, "Queda de fusível deve desativar temporariamente os pontos de vigília.")
	_verificar(casa.queda_energia_ativa, "CasaControlador deve entrar em estado de queda de energia.")

	# Avança tempo para restaurar fusível
	diretor.processar_diretor(2.5)
	_verificar(not diretor.queda_fusivel_ativa, "Queda de fusível deve encerrar após duração configurada.")
	_verificar(gerente.pontos_vigilia_ativos, "Pontos de vigília devem ser restaurados após encerramento da queda.")
	_verificar(not casa.queda_energia_ativa, "Luzes da CasaControlador devem ser restauradas após queda.")

	# 7. Coordenação dos 2 monstros: evita ataque simultâneo em cima do jogador
	diretor.janela_alivio_restante = 0.0
	rondante.global_position = player.global_position + Vector3(4.0, 0.0, 0.0)
	rondante.mudar_estado(RondanteFazenda.Estado.CACADA)
	silhueta.anel_atual = 1
	silhueta.em_investida = true
	diretor.coordenar_monstros(0.1)

	_verificar(not silhueta.em_investida, "Diretor deve impedir investida simultânea da Silhueta enquanto o Rondante caça perto do jogador.")
	_verificar(silhueta.anel_atual >= 2, "Diretor deve fazer a Silhueta recuar anel para evitar empilhamento injusto.")

	# Janela de alívio pós-susto segura ambos os monstros
	diretor.registrar_alivio_pos_susto(4.0)
	rondante.mudar_estado(RondanteFazenda.Estado.CACADA)
	silhueta.em_investida = true
	diretor.coordenar_monstros(0.1)
	_verificar(not silhueta.em_investida and rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Janela de alívio pós-susto deve segurar ambos os monstros.")

	gerente.iniciar_novo_dia()
	_verificar(not diretor.ativo, "DiretorEventosNoite deve desativar ao iniciar novo dia.")
	print("OK: DiretorEventosNoite e coordenação justa validados.")
