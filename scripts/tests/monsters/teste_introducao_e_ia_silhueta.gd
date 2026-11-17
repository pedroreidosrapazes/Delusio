extends SceneTree

## Teste Automatizado Headless:
## Sistema de Jornal/Documento estilo Resident Evil, Introdução em 3 Etapas da Silhueta,
## Nova Máquina de Estados, Oclusão 3D por RayCast, Cone da Lanterna e Captura Segura.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES: JORNAL, INTRODUÇÃO 3 ETAPAS E IA DA SILHUETA ===\n")

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
	var hud := mundo.get_node_or_null("Hud") as HUD
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var pausas := mundo.find_children("*", "MenuPausa", true, false)
	var menu_pausa := (pausas[0] as MenuPausa) if not pausas.is_empty() else null

	_verificar(gerente != null and player != null and hud != null and silhueta != null and menu_pausa != null, "Nós essenciais ausentes em world.tscn.")

	if _falhas.is_empty():
		await _teste_1_jornal_documento_e_cursor(mundo, gerente, player, hud, menu_pausa)
		await _teste_2_introducao_3_etapas(gerente, player, silhueta)
		await _teste_3_oclusao_raycast_lanterna_ameaca_e_captura(mundo, gerente, player, hud, silhueta)

	mundo.queue_free()
	await process_frame

	if _falhas.is_empty():
		print("\nOK: Todos os testes do jornal, introdução e IA da Silhueta passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_jornal_documento_e_cursor(mundo: Node3D, gerente: GameManager, player: Player, hud: HUD, menu_pausa: MenuPausa) -> void:
	print("--- [1] Teste de Jornal/Documento Estilo Resident Evil e Bloqueio de Movimento ---")
	var jornal := mundo.find_child("JornalMesa", true, false) as DocumentoLeitura
	var bilhete := mundo.find_child("DocumentoMesa", true, false) as DocumentoLeitura
	var painel := hud.obter_painel_leitura()

	_verificar(jornal != null and bilhete != null, "JornalMesa e DocumentoMesa devem existir em world.tscn.")
	_verificar(painel != null, "PainelLeituraDocumento deve existir no HUD.")
	if jornal == null or bilhete == null or painel == null:
		return

	_verificar(jornal.documento_id == &"jornal_silhueta", "JornalMesa deve possuir documento_id = 'jornal_silhueta'.")
	_verificar(not jornal.texto_conteudo.to_lower().contains("lorem ipsum"), "JornalMesa deve ter conteúdo real do jogo, sem Lorem Ipsum.")
	_verificar(not bilhete.texto_conteudo.to_lower().contains("lorem ipsum"), "DocumentoMesa deve ter conteúdo real do jogo, sem Lorem Ipsum.")
	_verificar(painel.is_in_group("modal_cursor_ui"), "PainelLeituraDocumento deve estar no grupo 'modal_cursor_ui'.")

	# Ler o jornal abre o painel modal e registra leitura
	jornal.interagir(player)
	_verificar(painel.visible, "PainelLeituraDocumento deve abrir ao interagir com JornalMesa.")
	_verificar(jornal.lido, "JornalMesa deve ser marcado como lido.")
	_verificar(gerente.jornal_silhueta_lido, "GameManager deve registrar jornal_silhueta_lido = true.")

	# Player não deve conseguir se mover enquanto lê
	_verificar(player._deve_manter_cursor_livre(), "Player deve detectar cursor/modal ativo durante leitura do jornal.")
	player.velocity = Vector3(4.0, 0.0, 3.0)
	player._physics_process(0.2)
	_verificar(Vector2(player.velocity.x, player.velocity.z).length() < 3.5, "Player deve desacelerar até parar enquanto painel de leitura está aberto.")

	# Pressionar Esc fecha o painel sem abrir o MenuPausa
	var ev_esc := InputEventAction.new()
	ev_esc.action = "ui_cancel"
	ev_esc.pressed = true
	menu_pausa._input(ev_esc)
	_verificar(not painel.visible, "Esc deve fechar o PainelLeituraDocumento aberto.")
	_verificar(not paused, "Fechar documento com Esc não deve abrir o menu de pausa.")

	# Testa suporte de visual modular (placeholder/override)
	var doc_avulso := DocumentoLeitura.new()
	mundo.add_child(doc_avulso)
	_verificar(doc_avulso.get_node_or_null("PlaceholderMesh") != null, "DocumentoLeitura sem modelo deve criar PlaceholderMesh fallback.")
	doc_avulso.queue_free()
	await process_frame
	print("OK: Sistema de Jornal/Documento, modal e trava de movimento validados.")


func _teste_2_introducao_3_etapas(gerente: GameManager, player: Player, silhueta: Silhueta) -> void:
	print("\n--- [2] Teste da Introdução Progressiva da Silhueta em 3 Etapas ---")
	var etapas_concluidas: Array[int] = []
	var cb := func(etapa: int) -> void:
		etapas_concluidas.append(etapa)
	silhueta.introducao_etapa_concluida.connect(cb)

	gerente.estagio_introducao_silhueta = Silhueta.EstagioIntroducao.NAO_INICIADA
	silhueta.estagio_introducao = Silhueta.EstagioIntroducao.NAO_INICIADA
	gerente.dia_atual = 1
	gerente.iniciar_evento_terror()

	# Etapa A: Aparição Passiva em PontoIntroSilhueta
	_verificar(silhueta.ativa, "Silhueta deve ativar na 1ª noite.")
	_verificar(silhueta.estado_atual == Silhueta.Estado.INTRODUCAO_ESPREITA, "Etapa A deve iniciar em INTRODUCAO_ESPREITA (atual: %d)." % silhueta.estado_atual)
	_verificar(silhueta.estagio_introducao == Silhueta.EstagioIntroducao.ETAPA_A_APARICAO_PASSIVA, "Estágio deve ser ETAPA_A_APARICAO_PASSIVA.")

	# Mesmo com lanterna acesa, Etapa A é passiva e não entra em investida
	player.global_position = silhueta.global_position + Vector3(0.0, 0.0, 12.0)
	player.look_at(silhueta.global_position, Vector3.UP)
	player.camera.rotation = Vector3.ZERO
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	silhueta.usar_raycast_oclusao = false # Isola teste da geometria da cena
	silhueta._process(0.05)

	_verificar(not silhueta.em_investida, "Etapa A nunca deve iniciar investida ao ser encarada.")
	_verificar(etapas_concluidas.has(1), "Olhar para a Silhueta na Etapa A deve concluir etapa 1.")

	# Aguarda fade_out da Etapa A e transiciona para Etapa B
	for i in range(25):
		await process_frame
	silhueta._process(silhueta.tempo_pausa_entre_etapas_intro + 0.1)

	_verificar(silhueta.estagio_introducao == Silhueta.EstagioIntroducao.ETAPA_B_TESTE_LANTERNA, "Após pausa da Etapa A, deve iniciar ETAPA_B_TESTE_LANTERNA.")
	_verificar(silhueta.estado_atual == Silhueta.Estado.OBSERVANDO, "Etapa B deve iniciar em OBSERVANDO.")

	# Etapa B: Teste guiado da regra da lanterna -> entra em AMEACA_LANTERNA e recua ao apagar luz
	silhueta.global_position = player.global_position + Vector3(0.0, 0.0, -10.0)
	player.look_at(silhueta.global_position, Vector3.UP)
	player.camera.rotation = Vector3.ZERO
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	silhueta._process(silhueta.limiar_ameaca_lanterna + 0.1)

	_verificar(silhueta.estado_atual == Silhueta.Estado.AMEACA_LANTERNA, "Na Etapa B com lanterna acesa, Silhueta deve avisar entrando em AMEACA_LANTERNA (atual: %d)." % silhueta.estado_atual)
	_verificar(not silhueta.em_investida, "Janela justa da Etapa B não deve atacar antes de tempo_ameaca_intro.")

	# Jogador apaga a lanterna olhando para ela -> conclui Etapa B e entra na Etapa C
	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	silhueta._process(0.05)

	_verificar(etapas_concluidas.has(2), "Apagar a lanterna durante o aviso deve concluir a Etapa B.")
	_verificar(silhueta.estagio_introducao == Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL, "Após Etapa B, deve liberar ETAPA_C_CICLO_NORMAL.")
	_verificar(gerente.estagio_introducao_silhueta == Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL, "GameManager deve sincronizar ETAPA_C_CICLO_NORMAL.")

	silhueta.introducao_etapa_concluida.disconnect(cb)
	silhueta.usar_raycast_oclusao = true
	gerente.iniciar_novo_dia()
	print("OK: Introdução progressiva em 3 etapas validada.")


func _teste_3_oclusao_raycast_lanterna_ameaca_e_captura(mundo: Node3D, gerente: GameManager, player: Player, hud: HUD, silhueta: Silhueta) -> void:
	print("\n--- [3] Teste de Oclusão 3D, Feixe da Lanterna, Filtro e Captura Limpa ---")
	gerente.estagio_introducao_silhueta = Silhueta.EstagioIntroducao.ETAPA_C_CICLO_NORMAL
	gerente.iniciar_evento_terror()
	silhueta.ativar()
	silhueta.usar_raycast_oclusao = true

	# Posiciona jogador e Silhueta em linha reta com parede no meio
	player.global_position = Vector3(100.0, 2.0, 100.0)
	player.look_at(Vector3(100.0, 2.0, 90.0), Vector3.UP)
	player.camera.rotation = Vector3.ZERO
	silhueta.global_position = Vector3(100.0, 2.0, 90.0)
	silhueta.altura_padrao = 2.0

	var parede := StaticBody3D.new()
	var col_parede := CollisionShape3D.new()
	var box_parede := BoxShape3D.new()
	box_parede.size = Vector3(6.0, 6.0, 0.5)
	col_parede.shape = box_parede
	parede.add_child(col_parede)
	mundo.add_child(parede)
	parede.global_position = Vector3(100.0, 2.5, 95.0)
	await physics_frame

	_verificar(not silhueta.tem_linha_de_visao(player), "Parede sólida entre câmera e Silhueta deve bloquear linha de visão (RayCast).")
	player._luz_lanterna_acesa = true
	player._atualizar_aparencia_lanterna()
	_verificar(not silhueta.esta_no_feixe_lanterna(player), "Feixe da lanterna não deve atravessar parede sólida.")

	# Remove parede -> agora está livre no feixe da lanterna
	parede.queue_free()
	await physics_frame

	_verificar(silhueta.tem_linha_de_visao(player), "Sem parede, linha de visão deve ficar livre.")
	_verificar(silhueta.esta_no_feixe_lanterna(player), "Silhueta à frente com lanterna acesa deve estar no feixe.")

	# Avança para AMEACA_LANTERNA e verifica bônus de tensão no FiltroDelusio
	var filtro := hud.obter_filtro_delusio()
	var tensao_antes := filtro.calcular_tensao_silhueta()
	silhueta._process(silhueta.limiar_ameaca_lanterna + 0.1)
	_verificar(silhueta.estado_atual == Silhueta.Estado.AMEACA_LANTERNA, "Lanterna direta deve colocar Silhueta em AMEACA_LANTERNA.")
	var tensao_ameaca := filtro.calcular_tensao_silhueta()
	_verificar(tensao_ameaca > tensao_antes, "FiltroDelusio deve elevar tensão extra durante AMEACA_LANTERNA.")

	# Continua iluminando além de tempo_limite_lanterna -> INVESTIDA
	silhueta._process(silhueta.tempo_limite_lanterna)
	_verificar(silhueta.estado_atual == Silhueta.Estado.INVESTIDA and silhueta.em_investida, "Persistir com lanterna deve iniciar INVESTIDA.")

	# Captura ao encostar no player -> retorna ao ciclo sem travar
	if gerente.diretor_eventos_noite is DiretorEventosNoite:
		(gerente.diretor_eventos_noite as DiretorEventosNoite).janela_alivio_restante = 0.0

	var capturado := {"ok": false}
	silhueta.captura_realizada.connect(func(_p): capturado["ok"] = true)
	silhueta.global_position = player.global_position + Vector3(0.4, 0.0, 0.0)
	silhueta._process(0.05)

	_verificar(capturado["ok"], "Silhueta deve concluir captura a curta distância.")
	_verificar(silhueta.estado_atual == Silhueta.Estado.OBSERVANDO and not silhueta.em_investida, "Após captura, Silhueta deve retornar para OBSERVANDO no anel 4 sem travar.")
	_verificar(silhueta.tempo_recuperacao_captura > 0.0, "Após captura, deve ativar janela de recuperação.")
	_verificar(not paused, "Captura não deve travar o SceneTree.")

	gerente.iniciar_novo_dia()
	print("OK: Oclusão 3D, cone da lanterna, filtro e captura segura validados.")
