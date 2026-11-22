extends SceneTree

## Teste Automatizado Headless — Fase 2:
## Orientação e giro suave dos monstros, esconderijos reais e tensão interna,
## relógio rural no HUD, Vigília Doméstica, RastroInvestigativo, CaixaFusiveis,
## JanelaVigilia, LuzPreenchimentoLanterna + DocumentoRondante e ZonaBreuNoturno.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DA FASE 2: CORE LOOP, MONSTROS, LANTERNA E SOBREVIVÊNCIA ===\n")

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
	var casa := mundo.get_node_or_null("Casa _final-col") as CasaControlador
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var rondante := mundo.get_node_or_null("RondanteFazenda") as RondanteFazenda

	_verificar(gerente != null and player != null and hud != null and casa != null and silhueta != null and rondante != null, "Nós centrais ausentes em world.tscn.")

	if _falhas.is_empty():
		_teste_1_orientacao_e_giro_suave_monstros(rondante, player)
		await _teste_2_esconderijos_reais_e_tensao(mundo, gerente, player)
		await _teste_3_relogio_rural_vigilia_rastros_e_fusiveis(mundo, gerente, hud, casa, player)
		_teste_4_janela_vigilia(mundo, gerente, player, silhueta)
		_teste_5_lanterna_e_documento_rondante(mundo, hud, player)
		_teste_6_zona_breu_noturno_sul(mundo, gerente, player, silhueta, rondante)

	mundo.queue_free()
	await process_frame

	if _falhas.is_empty():
		print("\nOK: Todos os testes da Fase 2 passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes da Fase 2:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_orientacao_e_giro_suave_monstros(rondante: RondanteFazenda, player: Player) -> void:
	print("--- [1] Teste de Orientação (180°) e Giro Suave do Rondante ---")
	_verificar(rondante.modelo_pivot != null, "RondanteFazenda deve possuir ModeloPivot.")
	if rondante.modelo_pivot != null:
		var ang_diff := absf(wrapf(rondante.modelo_pivot.rotation.y - PI, -PI, PI))
		_verificar(ang_diff <= 0.05, "ModeloPivot deve estar rotacionado em ~180° (PI) para alinhar +Z do RIG ao -Z de movimento (atual: %.3f)." % rondante.modelo_pivot.rotation.y)

	rondante.ativar()
	rondante.mudar_estado(RondanteFazenda.Estado.PATRULHA)
	rondante.global_position = Vector3(10.0, 0.571, 20.0)
	rondante.rotation = Vector3.ZERO # Olhando para -Z
	player.global_position = Vector3(-18.0, 0.62, 32.0)

	# Move para destino a +X (yaw esperado ~ -PI/2). Um delta pequeno (0.05s) deve girar parcialmente, não dar snap total.
	var destino_leste := Vector3(20.0, 0.571, 20.0)
	rondante.usar_desvio_obstaculo_raycast = false
	rondante._mover_para(destino_leste, 2.8, 0.05)
	var yaw_apos_passo := absf(rondante.rotation.y)
	_verificar(yaw_apos_passo > 0.05 and yaw_apos_passo < (PI * 0.5 - 0.1), "Giro em PATRULHA deve ser suavizado via lerp_angle e não instantâneo (yaw: %.3f)." % yaw_apos_passo)

	# Verifica que olha na direção do deslocamento (+X) e não para o jogador (-X/+Z)
	var dir_frente := Vector3(-rondante.global_transform.basis.z.x, 0.0, -rondante.global_transform.basis.z.z).normalized()
	_verificar(dir_frente.x > 0.0, "Rondante em patrulha deve girar na direção da rota (+X) e não ficar olhando fixado para o jogador.")
	rondante.desativar()
	print("OK: Orientação de 180° do RIG-Monstro e giro suave validados.")


func _teste_2_esconderijos_reais_e_tensao(mundo: Node3D, gerente: GameManager, player: Player) -> void:
	print("\n--- [2] Teste de Esconderijos Reais e Tensão / Vazamento de Luz ---")
	var esconderijos := get_nodes_in_group("esconderijos")
	var nomes: Array[String] = []
	for esc in esconderijos:
		if esc is Esconderijo:
			nomes.append((esc as Esconderijo).nome_esconderijo)
	_verificar(nomes.has("Armário do Quarto"), "Armário do Quarto deve estar sincronizado em 'esconderijos'.")
	_verificar(nomes.has("Armário do Pátio"), "Armário do Pátio (Armarioe_Fundo-col.blend) deve estar instanciado em 'esconderijos'.")
	_verificar(mundo.find_child("Esconderijo Fazenda", true, false) == null, "Cubo marrom procedural antigo não deve mais ser gerado.")

	var patio := mundo.find_child("EsconderijoPatio", true, false) as Esconderijo
	_verificar(patio != null, "EsconderijoPatio deve existir em world.tscn.")
	if patio != null:
		var sinal_tensao := {"chamado": false, "vazando": false}
		patio.tensao_esconderijo_alterada.connect(func(_i: float, vazando: bool):
			sinal_tensao["chamado"] = true
			sinal_tensao["vazando"] = vazando
		)
		gerente.horario_atual = 2
		player._luz_lanterna_acesa = true
		player._atualizar_aparencia_lanterna()
		patio.entrar(player)
		patio._process(0.1)
		_verificar(sinal_tensao["chamado"] and sinal_tensao["vazando"], "Entrar no esconderijo com lanterna acesa deve emitir alerta de vazamento de luz.")
		_verificar(patio.esta_comprometido(player), "Esconderijo com lanterna acesa deve ficar comprometido.")
		patio.sair(player)
		await process_frame
	gerente.iniciar_novo_dia()
	print("OK: Esconderijos reais e alerta de vazamento/tensão validados.")


func _teste_3_relogio_rural_vigilia_rastros_e_fusiveis(mundo: Node3D, gerente: GameManager, hud: HUD, casa: CasaControlador, player: Player) -> void:
	print("\n--- [3] Teste de Relógio Rural, Vigília Doméstica, Rastros e Caixa de Fusíveis ---")
	var label_timer := hud.obter_label_timer_dia()
	_verificar(label_timer != null, "HUD deve criar LabelTimerDia.")
	_verificar(gerente.obter_hora_formatada() == "06:00", "Dia deve iniciar às 06:00 (atual: %s)." % gerente.obter_hora_formatada())
	_verificar(label_timer != null and label_timer.text.contains("06:00"), "LabelTimerDia deve exibir o relógio rural 06:00.")

	# Avança tempo até entrar nos 35% finais -> transição automática para TARDE (1)
	gerente.processar_tempo_dia(gerente.duracao_dia_efetiva * 0.70)
	_verificar(gerente.horario_atual == 1, "Relógio abaixo de 35% restante deve transicionar automaticamente para TARDE (1).")
	_verificar(gerente.obter_hora_formatada() != "06:00", "Relógio rural deve avançar com o passar do dia.")

	# Concluir tarefas antes do fim -> entra em VIGILIA_DOMESTICA e bloqueia dormir até concluir vigília
	gerente.iniciar_novo_dia()
	for _i in range(gerente.tarefas_totais):
		gerente.concluir_tarefa()
	_verificar(gerente.horario_atual == 2 and gerente.modo_noturno == GameManager.ModoNoturno.VIGILIA_DOMESTICA, "Concluir todas as tarefas deve iniciar Noite de Vigília Doméstica.")
	_verificar(not gerente.vigilia_concluida, "Vigília recém-iniciada não deve estar concluída ainda.")

	var dia_antes := gerente.dia_atual
	gerente.tentar_dormir()
	_verificar(gerente.dia_atual == dia_antes, "Cama deve permanecer bloqueada enquanto a Vigília Doméstica estiver em curso.")

	# Rastros investigativos reais (RastroInvestigativo)
	_verificar(gerente.rastros_investigativos.size() == 3, "Devem existir 3 rastros investigativos na vigília.")
	var primeiro_rastro := gerente.rastros_investigativos[0] as RastroInvestigativo
	_verificar(primeiro_rastro != null, "Rastros gerados devem ser instâncias de RastroInvestigativo.")
	if primeiro_rastro != null:
		player._luz_lanterna_acesa = true
		player._atualizar_aparencia_lanterna()
		var tempo_antes := gerente.tempo_vigilia_restante
		primeiro_rastro.interagir(player)
		_verificar(primeiro_rastro.inspecionado, "RastroInvestigativo deve ser marcado como inspecionado.")
		_verificar(gerente.tempo_vigilia_restante < tempo_antes, "Inspecionar rastro deve acelerar a conclusão da vigília.")

	# CaixaFusiveis sincronizada na caixa_de_luz
	var fusivel_node := get_nodes_in_group("caixas_fusiveis")[0] as CaixaFusiveis if not get_nodes_in_group("caixas_fusiveis").is_empty() else null
	_verificar(fusivel_node != null, "caixa_de_luz da casa deve possuir script CaixaFusiveis.")
	var diretor := gerente.diretor_eventos_noite as DiretorEventosNoite
	if fusivel_node != null and diretor != null:
		diretor.disparar_queda_fusivel(10.0, true)
		_verificar(diretor.queda_fusivel_ativa, "Diretor deve ativar queda de fusível.")
		fusivel_node.concluir_interacao_direta(player)
		_verificar(not diretor.queda_fusivel_ativa, "Interagir com CaixaFusiveis deve religar a energia imediatamente.")

	# Conclui vigília -> Cama libera
	gerente.concluir_vigilia_domestica()
	_verificar(gerente.vigilia_concluida, "Vigília deve marcar vigilia_concluida = true.")
	gerente.tentar_dormir()
	_verificar(gerente.dia_atual == dia_antes + 1, "Após concluir vigília, dormir na cama deve avançar o dia.")
	gerente.dia_atual = 1
	gerente.iniciar_novo_dia()
	print("OK: Relógio rural, Vigília Doméstica, RastroInvestigativo e CaixaFusiveis validados.")


func _teste_4_janela_vigilia(mundo: Node3D, gerente: GameManager, player: Player, silhueta: Silhueta) -> void:
	print("\n--- [4] Teste da Mecânica de Olhar a Janela ---")
	var janela := mundo.find_child("JanelaVigilia", true, false) as JanelaVigilia
	_verificar(janela != null, "JanelaVigilia deve existir em LayoutMapaFase1/Setor1_CasaPatio/HookJanelaVigilia.")
	if janela == null:
		return

	gerente.iniciar_evento_terror()
	silhueta.ativar()
	silhueta.anel_atual = 2
	var cam_tf := janela.obter_transform_camera()
	var frente := -cam_tf.basis.z.normalized()
	silhueta.global_position = cam_tf.origin + frente * 12.0

	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	janela.interagir(player)

	_verificar(player.esta_olhando_janela(), "Interagir com JanelaVigilia deve ativar modo de espiar pela janela.")
	_verificar(silhueta.anel_atual == 3, "Espiar a Silhueta pela janela no escuro deve fazê-la recuar um anel (atual: %d)." % silhueta.anel_atual)

	player.sair_vigilia_janela()
	_verificar(not player.esta_olhando_janela(), "Sair da janela deve liberar o Player normalmente.")
	gerente.iniciar_novo_dia()
	print("OK: Mecânica de olhar a janela validada.")


func _teste_5_lanterna_e_documento_rondante(mundo: Node3D, hud: HUD, player: Player) -> void:
	print("\n--- [5] Teste da Lanterna (Preenchimento) e DocumentoRondante em Cena ---")
	_verificar(player.luz_preenchimento_lanterna != null, "Player deve criar LuzPreenchimentoLanterna suave de curto alcance.")
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	_verificar(player.luz_preenchimento_lanterna.visible, "LuzPreenchimentoLanterna deve acender junto com a lanterna.")
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	_verificar(not player.luz_preenchimento_lanterna.visible, "LuzPreenchimentoLanterna deve apagar junto com a lanterna.")

	var label_l := hud.obter_label_estado_lanterna()
	_verificar(label_l != null, "HUD deve exibir indicador discreto LabelEstadoLanterna.")

	var doc_rond := mundo.find_child("DocumentoRondante", true, false) as DocumentoLeitura
	_verificar(doc_rond != null, "DocumentoRondante (diario_celeiro) deve estar instanciado em world.tscn.")
	if doc_rond != null:
		_verificar(doc_rond.documento_id == &"diario_celeiro" and doc_rond.pode_interagir(), "DocumentoRondante deve estar interagível.")
	print("OK: Lanterna aprimorada e DocumentoRondante em cena validados.")


func _teste_6_zona_breu_noturno_sul(mundo: Node3D, gerente: GameManager, player: Player, silhueta: Silhueta, rondante: RondanteFazenda) -> void:
	print("\n--- [6] Teste da ZonaBreuNoturno ao Sul (Lanterna Obrigatória + Risco Ampliado) ---")
	var zona := mundo.find_child("ZonaBreuNoturno", true, false) as ZonaBreuNoturno
	_verificar(zona != null, "ZonaBreuNoturno deve possuir script ZonaBreuNoturno.")
	if zona == null:
		return

	var pos_original := player.global_position

	# 1. De dia: bloqueia entrada
	gerente.iniciar_novo_dia()
	player.global_position = zona.global_position
	_verificar(not zona.validar_entrada_ou_recuar(player), "ZonaBreuNoturno deve impedir entrada durante o dia.")
	_verificar(not zona.contem_ponto(player.global_position), "Player bloqueado deve ser recuado para fora da ZonaBreuNoturno.")

	# 2. À noite com lanterna apagada: bloqueia entrada
	gerente.iniciar_evento_terror()
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	player.global_position = zona.global_position
	_verificar(not zona.validar_entrada_ou_recuar(player), "ZonaBreuNoturno à noite sem lanterna ligada deve bloquear entrada.")

	# 3. À noite com lanterna acesa: permite entrada e BLOQUEIA desligar [F]
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	player.global_position = zona.global_position
	_verificar(zona.validar_entrada_ou_recuar(player), "ZonaBreuNoturno à noite com lanterna acesa deve permitir entrada.")
	_verificar(zona.esta_jogador_dentro(player), "ZonaBreuNoturno deve reconhecer Player dentro da área sul.")

	player.alternar_lanterna()
	_verificar(player.esta_com_lanterna_acesa(), "Dentro da ZonaBreuNoturno, apertar [F] NÃO deve desligar a lanterna.")

	# 4. Multiplicadores de risco nos 2 monstros
	_verificar(silhueta._obter_fator_zona_breu(player) > 1.0, "ZonaBreuNoturno deve ampliar fator de atração da Silhueta.")
	_verificar(rondante._jogador_em_zona_breu(player), "RondanteFazenda deve detectar Player dentro da ZonaBreuNoturno para ampliar visão.")

	player.global_position = pos_original
	gerente.iniciar_novo_dia()
	print("OK: ZonaBreuNoturno ao Sul validada com bloqueios, trava de [F] e multiplicadores de risco.")
