extends SceneTree

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DO SISTEMA DE ATMOSFERA E FILTRO DELUSIO ===")

	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar scenes/levels/world.tscn.")
	if cena == null:
		quit(1)
		return

	var mundo := cena.instantiate()
	root.add_child(mundo)
	current_scene = mundo

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var hud := mundo.get_node_or_null("Hud") as HUD
	var casa := mundo.get_node_or_null("Casa _final-col") as CasaControlador
	var clima := mundo.get_node_or_null("WorldEnvironment") as ClimaAmbiente
	var env := clima.environment if clima else null
	var dir_light := clima.directional_light if clima else null

	var planta1 := mundo.get_node_or_null("Objetos_Tarefas/Planta1") as TarefaInterativa
	var planta2 := mundo.get_node_or_null("Objetos_Tarefas/Planta2") as TarefaInterativa
	var planta3 := mundo.get_node_or_null("Objetos_Tarefas/Planta3") as TarefaInterativa

	_verificar(gerente != null and player != null and hud != null and casa != null and clima != null, "Nós centrais ausentes na cena world.tscn.")
	_verificar(planta1 != null and planta2 != null and planta3 != null, "Plantas de tarefas ausentes na cena.")

	if _falhas.size() > 0:
		quit(1)
		return

	# 1. Validação de Filtro e Camadas
	var filtro := hud.obter_filtro_delusio()
	_verificar(filtro != null, "FiltroDelusioControlador não encontrado no HUD.")
	_verificar(hud.layer == 1, "HUD deve estar configurado na layer 1 para ficar sobre o filtro.")
	_verificar(filtro.layer == 0, "FiltroDelusio deve estar na layer 0 para processar o mundo 3D sem afetar a UI.")

	var mat_filtro := filtro.obter_material_filtro()
	_verificar(mat_filtro != null, "Material do filtro não foi instanciado.")
	if mat_filtro:
		_verificar(mat_filtro.shader == preload("res://shaders/post_process/filtro_delusio.gdshader"), "Shader incorreto no FiltroDelusio.")

	# 2. Estado Inicial: DIA (0)
	print("\n--- [1] Teste Estado DIA (0) ---")
	_verificar(gerente.horario_atual == 0, "GameManager não iniciou no horário DIA (0).")
	_verificar(clima.estado_atual == 0, "ClimaAmbiente não iniciou no estado DIA (0).")
	_verificar(is_equal_approx(env.fog_density, 0.0045), "Fog density incorreta para DIA (esperado ~0.0045, atual %f)." % env.fog_density)
	_verificar(dir_light.light_color == Color("#ffe6bf"), "Cor da luz direcional incorreta para DIA.")
	_verificar(is_equal_approx(dir_light.light_energy, 1.05), "Energia da luz solar incorreta para DIA.")
	_verificar(is_equal_approx(filtro.peso_noite_atual, 0.0), "Peso da noite no filtro deve ser 0.0 no DIA.")
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 0.25), "Luzes da casa devem estar em 0.25 no DIA.")
	_verificar(not env.glow_enabled, "Glow deve iniciar desativado no DIA.")
	print("OK: Estado DIA verificado.")

	# 3. Progressão para TARDE (1) ao concluir (tarefas_totais - 1) tarefas
	print("\n--- [2] Teste Transição para TARDE (1) ---")
	planta1.interagir() # Direto (sem player) para simulação rápida
	planta2.interagir()
	if gerente.tarefas_concluidas < gerente.tarefas_totais - 1:
		planta3.interagir()
	while gerente.tarefas_concluidas < gerente.tarefas_totais - 1:
		gerente.concluir_tarefa()

	_verificar(gerente.tarefas_concluidas == gerente.tarefas_totais - 1, "Deveriam haver %d tarefas concluídas." % (gerente.tarefas_totais - 1))
	_verificar(gerente.horario_atual == 1, "GameManager deveria ter progredido para horário TARDE (1).")
	_verificar(clima.estado_atual == 1, "ClimaAmbiente deveria estar em TARDE (1).")
	_verificar(is_equal_approx(env.fog_density, 0.016), "Fog density incorreta para TARDE (esperado ~0.016, atual %f)." % env.fog_density)
	_verificar(dir_light.light_color == Color("#e67e38"), "Cor da luz direcional incorreta para TARDE.")
	_verificar(is_equal_approx(dir_light.light_energy, 0.75), "Energia da luz solar incorreta para TARDE.")
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 0.85), "Luzes da casa devem estar em 0.85 na TARDE.")
	_verificar(is_equal_approx(filtro._peso_noite_alvo, 0.35), "Alvo de peso da noite no filtro deve ser 0.35 na TARDE.")
	filtro.definir_estado_horario(1, true)
	_verificar(is_equal_approx(filtro.peso_noite_atual, 0.35), "Peso noite atual deve ser 0.35 na TARDE.")
	_verificar(not env.glow_enabled, "Glow deve permanecer desativado na TARDE.")
	print("OK: Estado TARDE verificado.")

	# 4. Progressão para NOITE (2) ao concluir a tarefa final
	print("\n--- [3] Teste Transição para NOITE (2) ---")
	if not planta3.concluida:
		planta3.interagir()
	else:
		gerente.concluir_tarefa("caixa_da_agua")

	_verificar(gerente.tarefas_concluidas == gerente.tarefas_totais, "Deveriam haver %d tarefas concluídas." % gerente.tarefas_totais)
	_verificar(gerente.horario_atual == 2, "GameManager deveria ter progredido para horário NOITE (2).")
	_verificar(clima.estado_atual == 2, "ClimaAmbiente deveria estar em NOITE (2).")
	_verificar(is_equal_approx(env.fog_density, 0.020), "Fog density incorreta para NOITE (esperado ~0.020, atual %f)." % env.fog_density)
	_verificar(env.fog_density >= 0.018 and env.fog_density <= 0.024, "Fog density da NOITE fora da faixa 0.018..0.024 (atual %f)." % env.fog_density)
	_verificar(dir_light.light_color == Color("#6482ad"), "Cor da luz direcional incorreta para NOITE.")
	_verificar(is_equal_approx(dir_light.light_energy, 0.46), "Energia da luz lunar incorreta para NOITE.")
	_verificar(dir_light.light_energy >= 0.40 and dir_light.light_energy <= 0.52, "Energia da luz lunar fora da faixa 0.40..0.52 (atual %f)." % dir_light.light_energy)
	_verificar(env.ambient_light_color == Color("#24334d"), "Cor ambiente incorreta para NOITE.")
	_verificar(is_equal_approx(env.ambient_light_energy, 0.58), "Energia ambiente incorreta para NOITE.")
	_verificar(env.ambient_light_energy >= 0.52 and env.ambient_light_energy <= 0.65, "Energia ambiente fora da faixa 0.52..0.65 (atual %f)." % env.ambient_light_energy)
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 1.45), "Luzes da casa devem estar em 1.45 na NOITE.")
	_verificar(is_equal_approx(filtro._peso_noite_alvo, 1.0), "Alvo de peso da noite no filtro deve ser 1.0 na NOITE.")
	_verificar(is_equal_approx(filtro._tensao_base_horario, 0.32), "Tensão base da noite deve ser 0.32 (atual %f)." % filtro._tensao_base_horario)
	_verificar(filtro._tensao_base_horario >= 0.30 and filtro._tensao_base_horario <= 0.35, "Tensão base da noite fora da faixa 0.30..0.35.")
	filtro.definir_estado_horario(2, true)
	_verificar(is_equal_approx(filtro.peso_noite_atual, 1.0), "Peso noite atual deve ser 1.0 na NOITE.")
	_verificar(env.glow_enabled, "Glow deve ter ativado na cama na NOITE.")
	print("OK: Estado NOITE verificado.")

	# 5. Reatividade Psicológica do Filtro e Lanterna
	print("\n--- [4] Teste de Reatividade Psicológica e Lanterna ---")
	var tensao_inicial := filtro.nivel_tensao_atual
	filtro.registrar_impulso_tensao(0.42)
	_verificar(filtro.nivel_tensao_atual > tensao_inicial, "Impulso de tensão não elevou nivel_tensao_atual do filtro.")

	_verificar(player.luz_lanterna != null, "Luz da lanterna do player não encontrada.")
	if player.luz_lanterna:
		_verificar(player.luz_lanterna.light_color == Player.COR_LANTERNA_PADRAO, "Luz da lanterna não recebeu a cor halógena padrão.")
		_verificar(is_equal_approx(player.calcular_fator_instabilidade_lanterna(35.0), 1.0), "Fator de instabilidade deveria ser 1.0 para distâncias >= 26m.")
		_verificar(player.calcular_fator_instabilidade_lanterna(10.0) < 1.0, "Fator de instabilidade deveria diminuir para distâncias < 26m.")
		_verificar(player.calcular_fator_instabilidade_lanterna(0.0) >= 0.35, "Fator de instabilidade não deve cair abaixo de 0.35.")
	print("OK: Reatividade psicológica e lanterna verificadas.")

	# 6. Reset ao Dormir: Retorno a DIA (0)
	print("\n--- [5] Teste de Reset ao Dormir ---")
	gerente.concluir_vigilia_domestica()
	gerente.tentar_dormir()

	_verificar(gerente.dia_atual == 2, "Dia não avançou para 2 após dormir.")
	_verificar(gerente.tarefas_concluidas == 0, "Tarefas concluídas não foram zeradas para o novo dia.")
	_verificar(gerente.horario_atual == 0, "GameManager não retornou a DIA (0) após dormir.")
	_verificar(clima.estado_atual == 0, "ClimaAmbiente não retornou a DIA (0) após dormir.")
	_verificar(is_equal_approx(env.fog_density, 0.0045), "Fog density não retornou ao nível de DIA.")
	_verificar(dir_light.light_color == Color("#ffe6bf"), "Cor da luz não retornou a DIA.")
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 0.25), "Luzes da casa não retornaram a 0.25 no novo dia.")
	_verificar(not env.glow_enabled, "Glow da cama deve ser desativado no novo dia.")
	filtro.definir_estado_horario(0, true)
	_verificar(is_equal_approx(filtro.peso_noite_atual, 0.0), "Filtro não resetou peso_noite_atual para 0.0 no novo dia.")
	print("OK: Reset do novo dia verificado.")

	mundo.queue_free()

	if _falhas.is_empty():
		print("\nOK: Todos os testes do sistema de atmosfera, iluminação e filtro Delusio passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes de atmosfera:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)
