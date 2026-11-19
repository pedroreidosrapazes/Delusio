extends SceneTree

## Teste Automatizado Headless — Fase 1:
## Nivelamento da Casa _final-col, Spawn Interno, 5 Luzes Diretas por Cômodo,
## Exceção de Lanterna Dentro de Casa e Esqueleto Modular do Mapa Enxuto.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DA FASE 1: CASA, ILUMINAÇÃO E MAPA ENXUTO ===\n")

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
	var casa := mundo.get_node_or_null("Casa _final-col") as CasaControlador
	var rondante := mundo.get_node_or_null("RondanteFazenda") as RondanteFazenda
	var planta1 := mundo.get_node_or_null("Objetos_Tarefas/Planta1") as TarefaInterativa

	_verificar(gerente != null and player != null and casa != null and rondante != null and planta1 != null, "Nós centrais obrigatórios ausentes em world.tscn.")

	if _falhas.is_empty():
		_teste_1_casa_nivelada_e_spawn_interno(casa, player)
		_teste_2_iluminacao_interna_e_queda_energia(gerente, casa)
		_teste_3_excecao_lanterna_dentro_casa(gerente, casa, player, planta1)
		_teste_4_layout_mapa_e_pontos_ronda(mundo, casa, rondante)

	mundo.queue_free()
	await process_frame

	if _falhas.is_empty():
		print("\nOK: Todos os testes da Fase 1 (Casa, Iluminação e Mapa Enxuto) passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes da Fase 1:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_casa_nivelada_e_spawn_interno(casa: CasaControlador, player: Player) -> void:
	print("--- [1] Teste de Nivelamento da Casa e Spawn Interno ---")
	_verificar(absf(casa.rotation_degrees.x) <= 0.01, "Casa _final-col não deve ter inclinação no eixo X (atual: %.4f)." % casa.rotation_degrees.x)
	_verificar(absf(casa.rotation_degrees.z) <= 0.01, "Casa _final-col não deve ter inclinação no eixo Z (atual: %.4f)." % casa.rotation_degrees.z)
	_verificar(is_equal_approx(casa.rotation_degrees.y, -90.0), "Casa _final-col deve estar alinhada em -90° no eixo Y (atual: %.2f)." % casa.rotation_degrees.y)
	_verificar(casa.position.y >= 0.57, "Casa _final-col deve estar assentada acima do terreno 0.57 (atual: %.4f)." % casa.position.y)

	_verificar(casa.is_in_group("casa_controlador"), "CasaControlador deve pertencer ao grupo 'casa_controlador'.")
	_verificar(casa.contem_ponto_interno(player.global_position), "Player deve iniciar dentro da Casa _final-col.")
	_verificar(player.global_position.y >= 0.57 and player.global_position.y <= 1.2, "Player deve iniciar na altura válida do piso interno.")
	_verificar(not player.test_move(player.global_transform, Vector3(0.0, 0.01, 0.0)), "Player não pode iniciar penetrando paredes ou móveis.")
	print("OK: Casa nivelada em -90° e spawn interno validados.")


func _teste_2_iluminacao_interna_e_queda_energia(gerente: GameManager, casa: CasaControlador) -> void:
	print("\n--- [2] Teste das 5 Luzes Internas Diretas e Queda de Energia ---")
	var luzes := casa.obter_luzes_internas()
	_verificar(luzes.size() == 5, "CasaControlador deve criar exatamente 5 OmniLight3D internas (atual: %d)." % luzes.size())

	for luz in luzes:
		_verificar(luz.get_parent() == casa, "Luz '%s' deve ser filha direta de Casa _final-col." % luz.name)
		_verificar(luz.position.y <= 1.35, "Luz '%s' deve ficar abaixo do teto local (y <= 1.35, atual: %.2f)." % [luz.name, luz.position.y])

	casa.atualizar_iluminacao_horario(0)
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 0.25), "Energia base DIA deve ser 0.25.")
	casa.atualizar_iluminacao_horario(1)
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 0.85), "Energia base TARDE deve ser 0.85.")
	casa.atualizar_iluminacao_horario(2)
	_verificar(is_equal_approx(casa.obter_energia_base_luzes(), 1.45), "Energia base NOITE deve ser 1.45.")

	casa.definir_queda_energia(true)
	for luz in luzes:
		_verificar(is_equal_approx(luz.light_energy, 0.08), "Na queda de energia, '%s' deve cair para 0.08." % luz.name)

	casa.definir_queda_energia(false)
	_verificar(is_equal_approx(luzes[0].light_energy, 1.45), "Após encerrar queda de energia à noite, luzes devem voltar para 1.45.")
	gerente.horario_atual = 0
	casa.atualizar_iluminacao_horario(0)
	print("OK: 5 luzes internas e resposta à queda de energia validadas.")


func _teste_3_excecao_lanterna_dentro_casa(gerente: GameManager, casa: CasaControlador, player: Player, planta1: TarefaInterativa) -> void:
	print("\n--- [3] Teste de Interações Dentro de Casa Sem Lanterna à Noite ---")
	gerente.horario_atual = 2
	casa.atualizar_iluminacao_horario(2)
	casa.definir_queda_energia(false)

	player._luz_lanterna_acesa = false
	player._atualizar_aparencia_lanterna()
	_verificar(not player.esta_com_lanterna_acesa(), "Lanterna deve estar apagada para o teste.")
	_verificar(casa.esta_area_iluminada_interna(player), "Casa deve reconhecer Player dentro da área iluminada interna com energia ativa.")

	var no_porta_entrada := casa.find_child("portaEntrada", true, false)
	var porta_comp: PortaEntrada = null
	if no_porta_entrada != null:
		for f in no_porta_entrada.get_children():
			if f is PortaEntrada:
				porta_comp = f as PortaEntrada
				break
	_verificar(porta_comp != null, "PortaEntrada deve estar sincronizada na Casa _final-col.")
	if porta_comp != null:
		_verificar(not porta_comp.exigir_lanterna_a_noite, "PortaEntrada não deve exigir lanterna à noite.")

	var no_cama := casa.find_child("cama", true, false)
	var cama_comp: Cama = null
	if no_cama != null:
		for f in no_cama.get_children():
			if f is Cama:
				cama_comp = f as Cama
				break
	_verificar(cama_comp != null, "Cama deve estar sincronizada na Casa _final-col.")
	if cama_comp != null:
		_verificar(not cama_comp.exigir_lanterna_a_noite, "Cama não deve exigir lanterna à noite.")

	var radio_comp := gerente.radio as Radio
	_verificar(radio_comp != null, "Radio deve estar sincronizado no GameManager.")
	if radio_comp != null:
		_verificar(not radio_comp.exigir_lanterna_a_noite, "Radio não deve exigir lanterna à noite.")

	# Testa Interactable genérico dentro da casa (com exigir_lanterna_a_noite = true)
	var inter_interno := Interactable.new()
	inter_interno.name = "TesteInterativoInterno"
	inter_interno.exigir_lanterna_a_noite = true
	casa.add_child(inter_interno)
	inter_interno.position = Vector3(0.0, 0.5, 0.0)

	var contagem := {"usos": 0}
	inter_interno.interagiu.connect(func(_j): contagem["usos"] += 1)

	inter_interno.interagir(player)
	_verificar(contagem["usos"] == 1, "Interactable dentro da casa iluminada deve funcionar à noite com lanterna apagada.")

	casa.definir_queda_energia(true)
	_verificar(not casa.esta_area_iluminada_interna(player), "Com queda de energia, área interna não deve ser considerada iluminada.")
	inter_interno.interagir(player)
	_verificar(contagem["usos"] == 1, "Durante queda de energia sem lanterna, Interactable genérico deve voltar a bloquear.")

	casa.definir_queda_energia(false)
	inter_interno.queue_free()

	# Tarefa externa continua exigindo lanterna à noite
	planta1.interagir(player)
	_verificar(not planta1.concluida and not player.esta_em_interacao_sequencia(), "Tarefa externa (Planta1) deve continuar bloqueada à noite sem lanterna.")
	print("OK: Exceção de lanterna dentro de casa (e bloqueio em queda/área externa) validados.")


func _teste_4_layout_mapa_e_pontos_ronda(mundo: Node3D, casa: CasaControlador, rondante: RondanteFazenda) -> void:
	print("\n--- [4] Teste do LayoutMapaFase1, ZonaBreuNoturno ao Sul e PontoRonda ---")
	var layout := mundo.get_node_or_null("LayoutMapaFase1") as Node3D
	_verificar(layout != null, "Nó organizador 'LayoutMapaFase1' deve existir em world.tscn.")
	if layout == null:
		return

	var hook_janela := layout.get_node_or_null("Setor1_CasaPatio/HookJanelaVigilia") as Marker3D
	var hook_luz := layout.get_node_or_null("Setor1_CasaPatio/HookCaixaDeLuz") as Marker3D
	var hook_celeiro := layout.get_node_or_null("Setor3_PerimetroCeleiro/HookCeleiro") as Marker3D
	var zona_breu := layout.get_node_or_null("Setor4_ZonaBreuNoturno/ZonaBreuNoturno") as Area3D

	_verificar(hook_janela != null, "HookJanelaVigilia deve existir em Setor1_CasaPatio.")
	_verificar(hook_luz != null, "HookCaixaDeLuz deve existir em Setor1_CasaPatio.")
	_verificar(hook_celeiro != null, "HookCeleiro deve existir em Setor3_PerimetroCeleiro.")
	_verificar(zona_breu != null and zona_breu.is_in_group("zona_breu_noturno"), "ZonaBreuNoturno (Area3D no grupo 'zona_breu_noturno') deve existir.")
	if zona_breu != null:
		_verificar(zona_breu.global_position.z > casa.global_position.z, "ZonaBreuNoturno deve ficar reservada ao Sul (+Z) da Casa _final-col.")

	rondante.atualizar_rotas_do_mapa(true)
	_verificar(rondante.pontos_patrulha.size() >= 4, "RondanteFazenda deve descobrir >= 4 PontoRonda de PATRULHA (atual: %d)." % rondante.pontos_patrulha.size())
	_verificar(rondante.pontos_wall_peek.size() >= 2, "RondanteFazenda deve descobrir >= 2 PontoRonda de WALL_PEEK (atual: %d)." % rondante.pontos_wall_peek.size())
	_verificar(rondante.pontos_entrada_saida.size() >= 2, "RondanteFazenda deve descobrir >= 2 PontoRonda de ENTRADA_SAIDA (atual: %d)." % rondante.pontos_entrada_saida.size())
	print("OK: LayoutMapaFase1, ZonaBreuNoturno ao Sul e PontoRonda validados.")
