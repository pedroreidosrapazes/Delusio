extends SceneTree

## Teste Automatizado Headless do Rondante Avançado:
## Unificação de animações reais (WALKCYCLE, WALL PEEK, Desnorteado, AtacarGarras, BaterChao),
## Navegação agnóstica (PontoRonda, Path3D, RayCast3D), Pressão Dinâmica (Spawn/Despawn),
## Oclusão 3D, Busca Frustrada, Ataque Garras e Pista Diegética.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DO RONDANTE AVANÇADO (AGNÓSTICO & ANIMAÇÕES REAIS) ===\n")

	await _teste_1_modelo_3d_e_animacoes_unificadas()
	await _teste_2_navegacao_agnostica_wall_peek_e_desvio()
	await _teste_3_pressao_dinamica_spawn_despawn()
	await _teste_4_oclusao_3d_busca_frustrada_e_ataque_garras()
	_teste_5_documento_rondante()
	await _teste_6_colisao_paredes_deslizamento_e_anti_atravessamento()

	if _falhas.is_empty():
		print("\nOK: Todos os testes avançados do Rondante passaram com sucesso!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas nos testes:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_modelo_3d_e_animacoes_unificadas() -> void:
	print("--- [1] Teste do Modelo 3D e AnimationLibrary Unificada ---")
	var cena := load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene
	_verificar(cena != null, "Deveria carregar scenes/monsters/rondante_fazenda.tscn.")
	if cena == null:
		return

	var rondante := cena.instantiate() as RondanteFazenda
	root.add_child(rondante)
	await process_frame

	_verificar(rondante.modelo_pivot != null, "RondanteFazenda deve possuir ModeloPivot.")
	if rondante.modelo_pivot != null:
		_verificar(is_equal_approx(rondante.modelo_pivot.scale.x, 0.28), "Escala de ModeloPivot deve ser normalizada (~0.28 para altura ~2.45m).")
		_verificar(rondante.modelo_pivot.get_node_or_null("RIG-Monstro") != null, "ModeloPivot deve conter RIG-Monstro.")
		_verificar(rondante.modelo_pivot.find_children("*", "Camera3D", true, false).is_empty(), "Câmeras extras do Blender devem ter sido removidas.")
		_verificar(rondante.modelo_pivot.find_child("Cube", true, false) == null, "Cubo de referência do WALL PEEK.blend não deve estar na malha.")

	var ap := rondante.anim_player
	_verificar(ap != null, "AnimationPlayerUnificado deve ser criado em ModeloPivot.")
	if ap != null:
		for anim_esperada in [&"walkcycle", &"wall_peek", &"desnorteado", &"atacar_garras", &"bater_chao"]:
			_verificar(ap.has_animation(anim_esperada), "AnimationLibrary deve conter '%s'." % anim_esperada)
		if ap.has_animation(&"walkcycle"):
			_verificar(ap.get_animation(&"walkcycle").loop_mode == Animation.LOOP_LINEAR, "Animação 'walkcycle' deve estar configurada com LOOP_LINEAR.")

	_verificar(rondante.visual_placeholder != null and not rondante.visual_placeholder.visible, "Com modelo 3D real carregado, VisualPlaceholder deve permanecer oculto.")

	rondante.queue_free()
	await process_frame
	print("OK: Modelo 3D, escala, limpeza de cena e 5 animações reais validados.")


func _criar_mapa_sintetico() -> Dictionary:
	var mapa := Node3D.new()
	mapa.name = "MapaSinteticoTeste"
	root.add_child(mapa)

	# Chão amplo
	var chao := StaticBody3D.new()
	var col_chao := CollisionShape3D.new()
	var box_chao := BoxShape3D.new()
	box_chao.size = Vector3(120.0, 1.0, 120.0)
	col_chao.shape = box_chao
	chao.add_child(col_chao)
	chao.position = Vector3(0.0, -0.5, 0.0)
	mapa.add_child(chao)

	# Player mínimo para testes fora de world.tscn
	var player := Player.new()
	player.name = "PlayerTeste"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0.0, 1.7, 0.0)
	player.add_child(cam)
	var rc := RayCast3D.new()
	rc.name = "RayCast3D"
	rc.target_position = Vector3(0.0, 0.0, -2.5)
	cam.add_child(rc)
	var fl := Node3D.new()
	fl.name = "Flashlight"
	var spot := SpotLight3D.new()
	spot.name = "SpotLight3D"
	fl.add_child(spot)
	cam.add_child(fl)
	var col_p := CollisionShape3D.new()
	var cap_p := CapsuleShape3D.new()
	col_p.shape = cap_p
	player.add_child(col_p)
	mapa.add_child(player)
	player.camera = cam
	player.global_position = Vector3(0.0, 0.0, 0.0)

	return {"mapa": mapa, "player": player}


func _teste_2_navegacao_agnostica_wall_peek_e_desvio() -> void:
	print("\n--- [2] Teste de Navegação Agnóstica (PontoRonda, Path3D, Wall Peek e RayCast) ---")
	var ctx := _criar_mapa_sintetico()
	var mapa := ctx["mapa"] as Node3D
	var player := ctx["player"] as Player
	player.global_position = Vector3(-40.0, 0.0, -40.0) # Longe para isolar patrulha

	var p1 := PontoRonda.new()
	p1.tipo_ponto = PontoRonda.TipoPonto.PATRULHA
	p1.zona_nome = "celeiro"
	mapa.add_child(p1)
	p1.global_position = Vector3(10.0, 0.0, 0.0)

	var p_peek := PontoRonda.new()
	p_peek.tipo_ponto = PontoRonda.TipoPonto.WALL_PEEK
	p_peek.tempo_espreita = 0.6
	mapa.add_child(p_peek)
	p_peek.global_position = Vector3(4.0, 0.0, 0.0)

	# Path3D alternativo
	var path := Path3D.new()
	path.add_to_group("rotas_rondante")
	var curve := Curve3D.new()
	curve.add_point(Vector3(0.0, 0.0, 10.0))
	curve.add_point(Vector3(12.0, 0.0, 10.0))
	path.curve = curve
	mapa.add_child(path)

	var rondante := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa.add_child(rondante)
	await physics_frame

	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	rondante.ativar()

	var wps := rondante.obter_waypoints()
	_verificar(wps.size() == 1 and wps[0].distance_to(p1.global_position) < 0.1, "Rondante deve descobrir dinamicamente PontoRonda do novo mapa.")
	_verificar(rondante.pontos_wall_peek.size() == 1, "Rondante deve descobrir pontos de WALL_PEEK.")
	_verificar(rondante._waypoints_path3d.size() >= 2, "Rondante deve amostrar Path3D no grupo 'rotas_rondante'.")

	# Anda em direção a p1 passando por p_peek -> entra em ESPREITA_QUINA
	for i in range(10):
		rondante.processar_ia(0.25)
		if rondante.estado_atual == RondanteFazenda.Estado.ESPREITA_QUINA:
			break

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.ESPREITA_QUINA, "Ao passar por PontoRonda WALL_PEEK, deve entrar em ESPREITA_QUINA (atual: %d)." % rondante.estado_atual)
	_verificar(rondante.anim_player.current_animation == &"wall_peek", "Durante ESPREITA_QUINA, animação ativa deve ser 'wall_peek'.")

	# Termina tempo de espreita -> retorna a PATRULHA
	rondante.processar_ia(0.8)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Após concluir wall peek, deve retornar para PATRULHA.")

	mapa.queue_free()
	await process_frame
	print("OK: Navegação agnóstica, Path3D e ESPREITA_QUINA validados.")


func _teste_3_pressao_dinamica_spawn_despawn() -> void:
	print("\n--- [3] Teste do Ciclo Pressão Dinâmica (EM_ESPERA -> Spawn -> RETIRANDO -> Despawn) ---")
	var ctx := _criar_mapa_sintetico()
	var mapa := ctx["mapa"] as Node3D
	var player := ctx["player"] as Player
	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.look_at(Vector3(0.0, 0.0, -10.0), Vector3.UP) # Olhando para -Z

	var p_frente := PontoRonda.new()
	p_frente.tipo_ponto = PontoRonda.TipoPonto.ENTRADA_SAIDA
	mapa.add_child(p_frente)
	p_frente.global_position = Vector3(0.0, 0.0, -25.0) # Dentro da visão do jogador

	var p_costas := PontoRonda.new()
	p_costas.tipo_ponto = PontoRonda.TipoPonto.ENTRADA_SAIDA
	mapa.add_child(p_costas)
	p_costas.global_position = Vector3(0.0, 0.0, 26.0) # Atrás do jogador (fora da visão)

	var rondante := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	var cfg := CriaturaConfig.criar_padrao_rondante_pressao()
	cfg.limiar_pressao_entrada = 40.0
	cfg.duracao_ronda_min = 2.0
	cfg.duracao_ronda_max = 2.0
	cfg.distancia_min_spawn_jogador = 20.0
	rondante.config = cfg
	mapa.add_child(rondante)
	await physics_frame

	rondante.ativar()
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.EM_ESPERA, "No modo PRESSAO_DINAMICA, Rondante deve iniciar em EM_ESPERA.")
	_verificar(not rondante.visible, "Em EM_ESPERA, Rondante deve ficar oculto fora de cena.")

	# Acumula ruído suficiente -> deve spawnar no ponto atrás do jogador
	rondante.receber_estimulo_sonoro(Vector3(0.0, 0.0, 0.0), 30.0)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.INVESTIGANDO or rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Ao atingir limiar de pressão, Rondante deve entrar em cena.")
	_verificar(rondante.visible, "Ao entrar por pressão, Rondante deve ficar visível.")
	_verificar(rondante.global_position.distance_to(p_costas.global_position) < 2.0, "Spawn por pressão deve escolher entrada fora da visão da câmera (costas).")

	# Força estado PATRULHA e esgota tempo_ronda_restante -> RETIRANDO -> EM_ESPERA
	rondante.mudar_estado(RondanteFazenda.Estado.PATRULHA)
	rondante.tempo_ronda_restante = 0.2
	rondante.processar_ia(0.3)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.RETIRANDO, "Ao esgotar tempo de ronda, deve iniciar RETIRANDO.")

	rondante.global_position = rondante._destino_retirada
	rondante.processar_ia(0.1)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.EM_ESPERA and not rondante.visible, "Ao atingir ponto de saída, deve despawnar para EM_ESPERA.")

	mapa.queue_free()
	await process_frame
	print("OK: Ciclo completo de Pressão Dinâmica validado.")


func _teste_4_oclusao_3d_busca_frustrada_e_ataque_garras() -> void:
	print("\n--- [4] Teste de Oclusão 3D, Busca Frustrada, Desnorteado e Ataque Garras ---")
	var ctx := _criar_mapa_sintetico()
	var mapa := ctx["mapa"] as Node3D
	var player := ctx["player"] as Player

	var rondante := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	var cfg := CriaturaConfig.criar_padrao_rondante()
	cfg.tempo_tolerancia_esconderijo = 1.5
	rondante.config = cfg
	mapa.add_child(rondante)
	await physics_frame

	rondante.ativar()
	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	rondante.look_at(Vector3(0.0, 0.0, -10.0), Vector3.UP)
	player.global_position = Vector3(0.0, 0.0, -8.0)

	# 1. Parede sólida bloqueia visão
	var parede := StaticBody3D.new()
	var col_par := CollisionShape3D.new()
	var box_par := BoxShape3D.new()
	box_par.size = Vector3(6.0, 5.0, 0.5)
	col_par.shape = box_par
	parede.add_child(col_par)
	mapa.add_child(parede)
	parede.global_position = Vector3(0.0, 2.0, -4.0)
	await physics_frame

	_verificar(not rondante.pode_ver_jogador(player), "Parede sólida entre Rondante e Player deve impedir detecção visual.")

	# Remove parede -> detecta jogador e entra em CACADA
	parede.queue_free()
	await physics_frame
	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	player.global_position = Vector3(0.0, 0.0, -8.0)
	rondante.look_at(player.global_position, Vector3.UP)
	rondante.processar_ia(0.1)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.CACADA, "Sem obstáculo no cone de visão, deve entrar em CACADA (atual: %d)." % rondante.estado_atual)
	_verificar(rondante.anim_player.current_animation == &"walkcycle", "Em CACADA, animação deve ser 'walkcycle'.")

	# 2. Jogador entra em Esconderijo no escuro fora da vista -> BUSCA_FRUSTRADA -> PATRULHA
	var esc := Esconderijo.new()
	mapa.add_child(esc)
	esc.global_position = Vector3(20.0, 0.0, -8.0)
	player.global_position = esc.global_position
	player._luz_lanterna_acesa = false
	esc.entrar(player)
	rondante.ultima_posicao_vista_jogador = rondante.global_position + Vector3(0.0, 0.0, -0.5)
	rondante.processar_ia(0.1)

	_verificar(rondante.estado_atual == RondanteFazenda.Estado.BUSCA_FRUSTRADA, "Ao chegar no último ponto visto e não encontrar o jogador escondido, deve entrar em BUSCA_FRUSTRADA (atual: %d)." % rondante.estado_atual)
	_verificar(rondante.anim_player.current_animation == &"bater_chao", "Em BUSCA_FRUSTRADA, animação deve ser 'bater_chao'.")

	rondante.processar_ia(cfg.tempo_tolerancia_esconderijo + 0.2)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.PATRULHA, "Após BUSCA_FRUSTRADA sem sucesso, deve voltar para PATRULHA.")

	esc.sair(player)

	# 3. Ataque Garras e captura sem softlock
	rondante.mudar_estado(RondanteFazenda.Estado.PATRULHA)
	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	player.global_position = Vector3(0.0, 0.0, -1.2)
	rondante.look_at(player.global_position, Vector3.UP)
	var capturou := {"ok": false}
	rondante.jogador_capturado.connect(func(_m, _p): capturou["ok"] = true)

	rondante.processar_ia(0.05) # PATRULHA -> CACADA -> ATAQUE_GARRAS
	if rondante.estado_atual == RondanteFazenda.Estado.CACADA:
		rondante.processar_ia(0.05)
	_verificar(rondante.estado_atual == RondanteFazenda.Estado.ATAQUE_GARRAS, "A curta distância na caçada, deve iniciar ATAQUE_GARRAS (atual: %d)." % rondante.estado_atual)
	_verificar(rondante.anim_player.current_animation == &"atacar_garras", "Animação de ataque deve ser 'atacar_garras'.")

	rondante.processar_ia(rondante.duracao_ataque_garras + 0.1)
	_verificar(capturou["ok"], "Ao concluir janela do golpe com jogador ao alcance, deve emitir jogador_capturado.")
	_verificar(not paused, "Captura do Rondante não deve travar o SceneTree.")

	mapa.queue_free()
	await process_frame
	print("OK: Oclusão 3D, BUSCA_FRUSTRADA, BaterChaoAnim e ATAQUE_GARRAS validados.")


func _teste_5_documento_rondante() -> void:
	print("\n--- [5] Teste do Documento Diegético do Rondante ---")
	var cena_doc := load("res://scenes/props/documento_rondante.tscn") as PackedScene
	_verificar(cena_doc != null, "Deveria carregar scenes/props/documento_rondante.tscn.")
	if cena_doc != null:
		var inst := cena_doc.instantiate() as DocumentoLeitura
		_verificar(inst != null and inst.documento_id == &"diario_celeiro", "DocumentoRondante deve possuir documento_id = 'diario_celeiro'.")
		_verificar(inst != null and not inst.texto_conteudo.to_lower().contains("lorem ipsum"), "DocumentoRondante deve possuir texto real do jogo.")
		if inst != null:
			inst.free()
	print("OK: Documento diegético do Rondante validado.")


func _criar_parede_teste(pai: Node3D, pos: Vector3, tamanho: Vector3) -> StaticBody3D:
	var parede := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	col.shape = box
	parede.add_child(col)
	pai.add_child(parede)
	parede.global_position = pos
	return parede


func _teste_6_colisao_paredes_deslizamento_e_anti_atravessamento() -> void:
	print("\n--- [6] Teste de Colisão Física com Paredes, Deslizamento e Anti-Atravessamento ---")

	# 1. Bloqueio físico direto contra parede sólida (14m x 4m x 0.25m em z = -4.0)
	var ctx1 := _criar_mapa_sintetico()
	var mapa1 := ctx1["mapa"] as Node3D
	var player1 := ctx1["player"] as Player
	player1.global_position = Vector3(-40.0, 0.0, -40.0)
	var parede_larga := _criar_parede_teste(mapa1, Vector3(0.0, 2.0, -4.0), Vector3(14.0, 4.0, 0.25))

	var rondante := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa1.add_child(rondante)
	await physics_frame

	rondante.ativar()
	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	rondante.usar_desvio_obstaculo_raycast = false
	for _i in range(24):
		rondante._mover_para(Vector3(0.0, 0.0, -10.0), 5.2, 0.25)
	_verificar(rondante.global_position.z > -3.6, "Sem desvio, colisão física deve impedir Rondante de atravessar parede larga (z atual: %.3f)." % rondante.global_position.z)

	# Também em INVESTIGANDO e CACADA com delta alto (0.25s)
	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	rondante.usar_desvio_obstaculo_raycast = true
	rondante.ultima_posicao_som = Vector3(0.0, 0.0, -10.0)
	rondante.tempo_investigacao_restante = 4.0
	rondante.mudar_estado(RondanteFazenda.Estado.INVESTIGANDO)
	for _i in range(4):
		rondante.processar_ia(0.25)
	_verificar(rondante.global_position.z > -3.6, "Em INVESTIGANDO com delta alto, Rondante não pode tunelar pela parede (z atual: %.3f)." % rondante.global_position.z)

	rondante.global_position = Vector3(0.0, 0.0, 0.0)
	rondante.ultima_posicao_vista_jogador = Vector3(0.0, 0.0, -10.0)
	rondante.tempo_tolerancia_esconderijo_restante = 4.0
	rondante.mudar_estado(RondanteFazenda.Estado.CACADA)
	for _i in range(4):
		rondante.processar_ia(0.25)
	_verificar(rondante.global_position.z > -3.6, "Em CACADA com delta alto, Rondante não pode tunelar pela parede (z atual: %.3f)." % rondante.global_position.z)
	parede_larga.queue_free()
	mapa1.queue_free()
	await process_frame

	# 2. Contorno e deslizamento em parede finita (largura 3.6m em z = -4.0)
	var ctx2 := _criar_mapa_sintetico()
	var mapa2 := ctx2["mapa"] as Node3D
	var player2 := ctx2["player"] as Player
	player2.global_position = Vector3(-50.0, 0.0, -50.0)
	_criar_parede_teste(mapa2, Vector3(0.0, 2.0, -4.0), Vector3(3.6, 4.0, 0.25))

	var wp_alvo := PontoRonda.new()
	wp_alvo.tipo_ponto = PontoRonda.TipoPonto.PATRULHA
	mapa2.add_child(wp_alvo)
	wp_alvo.global_position = Vector3(0.0, 0.0, -10.0)

	var rondante2 := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa2.add_child(rondante2)
	await physics_frame

	rondante2.ativar()
	rondante2.usar_desvio_obstaculo_raycast = true
	rondante2.global_position = Vector3(0.0, 0.0, 0.0)
	var penetrou_parede_finita := false
	for _i in range(180):
		rondante2.processar_ia(0.05)
		if absf(rondante2.global_position.x) < 1.75 and absf(rondante2.global_position.z - (-4.0)) < 0.30:
			penetrou_parede_finita = true
			break
		if rondante2.global_position.z < -6.0:
			break
	_verificar(not penetrou_parede_finita, "Rondante não deve penetrar a parede finita durante o contorno.")
	_verificar(rondante2.global_position.z < -6.0, "Rondante deve contornar parede finita de 3.6m e seguir até z < -6.0 (z atual: %.3f)." % rondante2.global_position.z)
	mapa2.queue_free()
	await process_frame

	# 3. Impossibilidade de ver ou capturar através de parede fina (0.2m em z = -2.0)
	var ctx3 := _criar_mapa_sintetico()
	var mapa3 := ctx3["mapa"] as Node3D
	var player3 := ctx3["player"] as Player
	_criar_parede_teste(mapa3, Vector3(0.0, 2.0, -2.0), Vector3(8.0, 4.0, 0.2))

	var rondante3 := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa3.add_child(rondante3)
	await physics_frame

	rondante3.ativar()
	rondante3.global_position = Vector3(0.0, 0.0, -1.35)
	rondante3.look_at(Vector3(0.0, 0.0, -5.0), Vector3.UP)
	player3.global_position = Vector3(0.0, 0.0, -2.30)

	_verificar(not rondante3.pode_ver_jogador(player3), "Parede fina (0.2m) deve bloquear visão mesmo com jogador encostado do outro lado.")
	_verificar(not rondante3._esta_no_alcance_captura(player3), "Parede fina deve impedir alcance de captura através da parede.")

	var capturou_parede := {"ok": false}
	rondante3.jogador_capturado.connect(func(_m, _p): capturou_parede["ok"] = true)
	rondante3._iniciar_ataque_garras(player3)
	rondante3.processar_ia(rondante3.duracao_ataque_garras + 0.1)
	_verificar(not capturou_parede["ok"], "Concluir ATAQUE_GARRAS através de parede fechada NÃO deve capturar o jogador.")
	mapa3.queue_free()
	await process_frame

	# 4. Recuo de ATORDOADO_LUZ bloqueado por parede traseira
	var ctx4 := _criar_mapa_sintetico()
	var mapa4 := ctx4["mapa"] as Node3D
	var player4 := ctx4["player"] as Player
	_criar_parede_teste(mapa4, Vector3(0.0, 2.0, 1.0), Vector3(8.0, 4.0, 0.25))

	var rondante4 := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa4.add_child(rondante4)
	await physics_frame

	rondante4.ativar()
	rondante4.global_position = Vector3(0.0, 0.0, 0.35)
	player4.global_position = Vector3(0.0, 0.0, -4.0)
	player4.camera.look_at(rondante4.global_position + Vector3(0.0, 1.5, 0.0), Vector3.UP)
	player4._luz_lanterna_acesa = true
	player4._atualizar_aparencia_lanterna()
	rondante4.cooldown_atordoamento_restante = 0.0
	rondante4.receber_foco_lanterna(rondante4.tempo_foco_para_atordoar + 0.1)
	_verificar(rondante4.estado_atual == RondanteFazenda.Estado.ATORDOADO_LUZ, "Rondante deve entrar em ATORDOADO_LUZ no teste de recuo contra parede.")
	var passos_stun := int(ceilf(rondante4.duracao_atordoamento_luz / 0.1))
	for _i in range(passos_stun):
		rondante4.processar_ia(0.1)
	_verificar(rondante4.global_position.z < 0.75, "Recuo em ATORDOADO_LUZ deve ser barrado pela parede traseira em z = 1.0 (z atual: %.3f)." % rondante4.global_position.z)
	mapa4.queue_free()
	await process_frame

	# 5. Anti-softlock em som emitido atrás de sala totalmente fechada
	var ctx5 := _criar_mapa_sintetico()
	var mapa5 := ctx5["mapa"] as Node3D
	var player5 := ctx5["player"] as Player
	player5.global_position = Vector3(-45.0, 0.0, -45.0)
	_criar_parede_teste(mapa5, Vector3(0.0, 2.0, -6.0), Vector3(8.5, 4.0, 0.3))
	_criar_parede_teste(mapa5, Vector3(0.0, 2.0, -14.0), Vector3(8.5, 4.0, 0.3))
	_criar_parede_teste(mapa5, Vector3(-4.0, 2.0, -10.0), Vector3(0.3, 4.0, 8.5))
	_criar_parede_teste(mapa5, Vector3(4.0, 2.0, -10.0), Vector3(0.3, 4.0, 8.5))

	var rondante5 := (load("res://scenes/monsters/rondante_fazenda.tscn") as PackedScene).instantiate() as RondanteFazenda
	mapa5.add_child(rondante5)
	await physics_frame

	rondante5.ativar()
	rondante5.global_position = Vector3(0.0, 0.0, 0.0)
	rondante5.receber_estimulo_sonoro(Vector3(0.0, 0.0, -10.0), 30.0)
	_verificar(rondante5.estado_atual == RondanteFazenda.Estado.INVESTIGANDO, "Som dentro de sala fechada deve iniciar INVESTIGANDO.")
	for _i in range(90):
		rondante5.processar_ia(0.1)
		if rondante5.estado_atual == RondanteFazenda.Estado.PATRULHA:
			break
	_verificar(rondante5.global_position.z > -5.7, "Rondante deve permanecer fora da sala fechada (z atual: %.3f)." % rondante5.global_position.z)
	_verificar(rondante5.estado_atual == RondanteFazenda.Estado.PATRULHA, "Após ficar bloqueado tentando investigar sala fechada, deve retornar a PATRULHA sem softlock (estado: %d)." % rondante5.estado_atual)
	mapa5.queue_free()
	await process_frame

	print("OK: Colisão física com paredes, contorno, visão/captura bloqueadas, recuo e anti-softlock validados.")
