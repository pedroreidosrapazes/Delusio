extends SceneTree

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DO MINIGAME DE SEQUÊNCIA DIRECIONAL ===")

	_testar_unidade_sequencia()
	_testar_integracao_mundo()
	_testar_cocho_cavalo()

	if _falhas.is_empty():
		print("\nOK: Todos os testes unitários e de integração da sequência direcional passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _testar_unidade_sequencia() -> void:
	print("\n--- [1] Teste Unitário: SequenciaDirecionalDesafio ---")

	var desafio := SequenciaDirecionalDesafio.new()

	# 1.1 Configurações de tamanhos e tempos variados (4, 6, 8)
	var configs: Array[Dictionary] = [
		{"tamanho": 4, "tempo_limite": 6.0, "titulo": "Teste 4"},
		{"tamanho": 6, "tempo_limite": 6.5, "titulo": "Teste 6"},
		{"tamanho": 8, "tempo_limite": 7.0, "titulo": "Teste 8"}
	]

	for cfg in configs:
		desafio.iniciar(cfg)
		_verificar(desafio.ativo == true, "Desafio deveria estar ativo após iniciar.")
		_verificar(desafio.sequencia.size() == cfg["tamanho"], "Tamanho da sequência gerada incorreto (%d != %d)." % [desafio.sequencia.size(), cfg["tamanho"]])
		_verificar(is_equal_approx(desafio.tempo_limite, cfg["tempo_limite"]), "Tempo limite incorreto.")
		_verificar(is_equal_approx(desafio.tempo_restante, cfg["tempo_limite"]), "Tempo restante inicial incorreto.")
		_verificar(desafio.titulo == cfg["titulo"], "Título da sequência incorreto.")

	# 1.2 Acerto completo conclui a sequência
	desafio.iniciar({"tamanho": 4, "tempo_limite": 6.0, "titulo": "Teste Acerto"})
	var estado_acerto := {"concluida": false}
	var passos_acertados: Array[int] = []
	desafio.sequencia_concluida.connect(func(): estado_acerto["concluida"] = true)
	desafio.passo_acertado.connect(func(idx: int, _tot: int): passos_acertados.append(idx))

	var seq_esperada := desafio.sequencia.duplicate()
	for i in range(seq_esperada.size()):
		var res := desafio.submeter_direcao(seq_esperada[i])
		if i == seq_esperada.size() - 1:
			_verificar(res == "concluida", "Último passo deveria retornar 'concluida', retornou: " + res)
		else:
			_verificar(res == "acerto", "Passo intermediário deveria retornar 'acerto', retornou: " + res)

	_verificar(estado_acerto["concluida"] == true, "Sinal 'sequencia_concluida' não foi emitido.")
	_verificar(passos_acertados.size() == 4, "Quantidade de sinais 'passo_acertado' incorreta.")
	_verificar(desafio.ativo == false, "Desafio deveria ficar inativo após conclusão.")

	# 1.3 Erro de tecla: reinicia progresso, gera nova sequência diferente, aplica cooldown e reinicia tempo
	desafio.iniciar({"tamanho": 4, "tempo_limite": 6.0, "titulo": "Teste Erro", "embaralhar_ao_errar": true, "reiniciar_tempo_ao_errar": true})
	var seq_antes := desafio.sequencia.duplicate()
	_verificar(desafio.submeter_direcao(seq_antes[0]) == "acerto", "Primeiro passo deveria acertar.")
	_verificar(desafio.indice_atual == 1, "Índice deveria estar em 1 após primeiro acerto.")

	# Consome um pouco de tempo
	desafio.processar_delta(1.5)
	_verificar(desafio.tempo_restante < 5.0, "Tempo deveria ter diminuído após processar_delta.")

	# Submete direção errada propositalmente
	var dir_errada: int = int((seq_antes[1] + 1) % 4)
	var estado_erro := {
		"recebido": false,
		"motivo": "",
		"nova_sequencia": []
	}
	desafio.sequencia_errada.connect(func(m: String, n_seq: Array[int], _t: float):
		estado_erro["recebido"] = true
		estado_erro["motivo"] = m
		estado_erro["nova_sequencia"] = n_seq.duplicate()
	)

	var res_erro := desafio.submeter_direcao(dir_errada)
	_verificar(res_erro == "erro", "Submissão de direção incorreta deveria retornar 'erro'.")
	_verificar(estado_erro["recebido"] == true and estado_erro["motivo"] == "tecla_errada", "Sinal de erro de tecla incorreto.")
	_verificar(desafio.indice_atual == 0, "Índice atual não foi resetado para 0 após erro.")
	_verificar(desafio.sequencia != seq_antes, "Nova sequência após erro deve ser estritamente diferente da anterior.")
	_verificar(estado_erro["nova_sequencia"] == desafio.sequencia, "Sequência passada no sinal sequencia_errada diverge do estado interno.")
	_verificar(is_equal_approx(desafio.tempo_restante, 6.0), "Tempo não foi reiniciado para o tempo limite após erro.")
	_verificar(desafio.bloqueio_restante > 0.0, "Bloqueio/cooldown anti-spam não foi aplicado após erro.")

	# Teste do cooldown anti-spam: submissão durante bloqueio é ignorada
	var erros_antes := desafio.erros_cometidos
	var res_bloqueado := desafio.submeter_direcao(desafio.sequencia[0])
	_verificar(res_bloqueado == "bloqueado", "Entrada durante bloqueio deveria retornar 'bloqueado'.")
	_verificar(desafio.erros_cometidos == erros_antes, "Entrada bloqueada não deve incrementar erros.")

	# Libera o cooldown com delta
	desafio.processar_delta(desafio.tempo_bloqueio_apos_erro + 0.05)
	_verificar(desafio.bloqueio_restante <= 0.0, "Bloqueio deveria ter zerado após expirar tempo de cooldown.")
	var res_apos_desbloqueio := desafio.submeter_direcao(desafio.sequencia[0])
	_verificar(res_apos_desbloqueio == "acerto", "Após fim do cooldown, entrada válida deve retornar 'acerto'.")

	# 1.4 Estouro do tempo limite (tempo_esgotado)
	desafio.iniciar({"tamanho": 4, "tempo_limite": 3.0, "titulo": "Teste Timeout"})
	var seq_antes_timeout := desafio.sequencia.duplicate()
	var estado_timeout := {"recebido": false}
	desafio.sequencia_errada.connect(func(m: String, _s: Array[int], _t: float):
		if m == "tempo_esgotado":
			estado_timeout["recebido"] = true
	)
	desafio.processar_delta(3.5)
	_verificar(estado_timeout["recebido"] == true, "Sinal de tempo_esgotado não foi emitido.")
	_verificar(desafio.indice_atual == 0, "Índice atual deveria resetar após timeout.")
	_verificar(desafio.sequencia != seq_antes_timeout, "Sequência após timeout deve ser diferente da anterior.")
	_verificar(is_equal_approx(desafio.tempo_restante, 3.0), "Tempo restante deveria ter sido reiniciado após timeout.")

	# 1.5 Cancelamento do desafio
	desafio.iniciar({"tamanho": 4, "tempo_limite": 6.0, "titulo": "Teste Cancelar"})
	var estado_cancelar := {"cancelado": false}
	desafio.sequencia_cancelada.connect(func(): estado_cancelar["cancelado"] = true)
	desafio.cancelar()
	_verificar(estado_cancelar["cancelado"] == true, "Sinal 'sequencia_cancelada' não emitido.")
	_verificar(desafio.ativo == false, "Desafio não desativou após cancelar.")

	print("OK: Testes unitários do SequenciaDirecionalDesafio passaram.")


func _testar_integracao_mundo() -> void:
	print("\n--- [2] Teste de Integração: World.tscn + Player + HUD + GameManager ---")

	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar scenes/levels/world.tscn.")
	if cena == null:
		return

	var mundo := cena.instantiate()
	root.add_child(mundo)
	current_scene = mundo

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var hud := mundo.get_node_or_null("Hud") as HUD
	var planta1 := mundo.get_node_or_null("Objetos_Tarefas/Planta1") as TarefaInterativa
	var planta2 := mundo.get_node_or_null("Objetos_Tarefas/Planta2") as TarefaInterativa
	var planta3 := mundo.get_node_or_null("Objetos_Tarefas/Planta3") as TarefaInterativa

	_verificar(gerente != null, "GameManager ausente no mundo.")
	_verificar(player != null, "Player ausente no mundo.")
	_verificar(hud != null, "HUD ausente no mundo.")
	_verificar(planta1 != null and planta2 != null and planta3 != null, "Uma das plantas (tarefas) ausente no mundo.")

	if _falhas.size() > 0:
		return

	var painel_hud := hud.obter_painel_sequencia()
	_verificar(painel_hud != null, "PainelSequenciaInteracao ausente no HUD.")
	_verificar(painel_hud.visible == false, "Painel de sequência deveria iniciar invisível.")

	# 2.1 Verifica a diferenciação de tamanho e tempo limite nas 3 tarefas configuradas
	_verificar(planta1.tamanho_sequencia == 4 and is_equal_approx(planta1.tempo_limite_sequencia, 6.0), "Planta1 com tamanho/tempo incorreto.")
	_verificar(planta2.tamanho_sequencia == 6 and is_equal_approx(planta2.tempo_limite_sequencia, 6.5), "Planta2 com tamanho/tempo incorreto.")
	_verificar(planta3.tamanho_sequencia == 8 and is_equal_approx(planta3.tempo_limite_sequencia, 7.0), "Planta3 com tamanho/tempo incorreto.")
	_verificar(planta1.id_tarefa == "regar_horta", "ID de Planta1 incorreto.")
	_verificar(planta2.id_tarefa == "podar_cerca", "ID de Planta2 incorreto.")
	_verificar(planta3.id_tarefa == "consertar_bomba", "ID de Planta3 incorreto.")

	# 2.2 Inicia interação em Planta1 com o player
	planta1.interagir(player)
	_verificar(player.esta_em_interacao_sequencia() == true, "Player deveria estar em interação de sequência.")
	_verificar(planta1.concluida == false, "Planta1 não pode ser concluída imediatamente ao iniciar sequência.")
	_verificar(painel_hud.visible == true, "Painel do HUD deveria estar visível durante o desafio.")

	# 2.3 Simula erro de tecla durante o desafio da Planta1
	var seq_inicial := player._desafio_sequencia.sequencia.duplicate()
	var tecla_errada: int = int((seq_inicial[0] + 1) % 4)
	var res_erro := player.submeter_direcao_sequencia(tecla_errada)
	_verificar(res_erro == "erro", "Submissão de direção incorreta no Player deveria retornar 'erro'.")
	_verificar(player._desafio_sequencia.indice_atual == 0, "Índice do jogador deveria ser resetado para 0.")
	_verificar(player._desafio_sequencia.sequencia != seq_inicial, "Sequência deveria ter sido alterada para uma nova diferente da inicial.")
	_verificar(planta1.concluida == false, "Planta1 deve continuar não concluída após o erro.")

	# 2.4 Aguarda expiração do cooldown anti-spam e completa a nova sequência
	player._desafio_sequencia.processar_delta(player._desafio_sequencia.tempo_bloqueio_apos_erro + 0.05)
	var nova_seq := player._desafio_sequencia.sequencia.duplicate()
	for i in range(nova_seq.size()):
		var res := player.submeter_direcao_sequencia(nova_seq[i])
		if i == nova_seq.size() - 1:
			_verificar(res == "concluida", "Último passo da sequência deveria concluir.")
		else:
			_verificar(res == "acerto", "Passo da sequência deveria acertar.")

	_verificar(planta1.concluida == true, "Planta1 deveria ter sido marcada como concluída após a sequência correta.")
	_verificar(gerente.tarefas_concluidas == 1, "GameManager deveria registrar 1 tarefa concluída.")
	_verificar(player.esta_em_interacao_sequencia() == false, "Player não deveria mais estar em interação de sequência.")
	_verificar(painel_hud.visible == false, "Painel do HUD deveria ter sido ocultado.")

	# 2.5 Inicia Planta2 e cancela
	planta2.interagir(player)
	_verificar(player.esta_em_interacao_sequencia() == true, "Player deveria entrar em interação com Planta2.")
	_verificar(player._desafio_sequencia.sequencia.size() == 6, "Planta2 deveria gerar sequência de 6 setas.")
	player.cancelar_interacao_sequencia()
	_verificar(planta2.concluida == false, "Planta2 não pode ser concluída após cancelamento.")
	_verificar(gerente.tarefas_concluidas == 1, "Contador de tarefas deve permanecer em 1 após cancelar Planta2.")
	_verificar(player.esta_em_interacao_sequencia() == false, "Player deve estar livre após cancelamento.")
	_verificar(painel_hud.visible == false, "Painel do HUD deve estar oculto após cancelamento.")

	mundo.queue_free()
	print("OK: Testes de integração do mundo passaram.")


func _testar_cocho_cavalo() -> void:
	print("\n--- [3] Teste Unitário: CochoCavalo ---")

	var cena_cocho := load("res://scenes/props/cocho_cavalo.tscn") as PackedScene
	_verificar(cena_cocho != null, "Não foi possível carregar res://scenes/props/cocho_cavalo.tscn.")
	if cena_cocho == null:
		return

	var instancia := cena_cocho.instantiate()
	var cocho: CochoCavalo = null
	if instancia is CochoCavalo:
		cocho = instancia
	else:
		cocho = instancia.find_child("StaticBody3D", true, false) as CochoCavalo

	_verificar(cocho != null, "Nó CochoCavalo não encontrado na cena cocho_cavalo.tscn.")
	if cocho:
		_verificar(cocho.exigir_sequencia_direcional == true, "CochoCavalo deve exigir sequência direcional.")
		_verificar(cocho.tamanho_sequencia == 5, "CochoCavalo deve ter tamanho de sequência 5.")
		_verificar(is_equal_approx(cocho.tempo_limite_sequencia, 5.5), "CochoCavalo deve ter tempo limite de 5.5s.")
		_verificar(cocho.pode_interagir() == true, "CochoCavalo deve permitir interação inicialmente.")

	instancia.queue_free()
	print("OK: Teste do CochoCavalo passou.")
