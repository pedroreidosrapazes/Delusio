extends SceneTree

## Teste Automatizado Headless — Fase 4 (Áudio, OST Dinâmica, 46 SFX Plug-and-Play e Partículas GPUParticles3D):
## Valida:
## 1. Layout de AudioBuses (Master, Musica, Ambiente, SFX) e fallback em BancoAudioDelusio
## 2. Catálogo completo dos 46 SFX plug-and-play (streams WAV válidos, loop no vazamento, helpers 2D e 3D)
## 3. Tema musical do MainMenu no bus Musica (Delusio Tema Menu v1 Export 1.wav)
## 4. GerenciadorAudioMundo: troca dinâmica de OSTs por horário/dia/casa/caçada/fusível/game over e atenuação do vento
## 5. SFX 3D e GPUParticles3D nos atores e interativos do mundo

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DA FASE 4: ÁUDIO, OST DINÂMICA E PARTÍCULAS 3D ===\n")

	_teste_1_buses_audio()
	await _teste_2_main_menu_musica()

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

	_teste_3_catalogo_46_sfx(mundo)

	var gerente := mundo.get_node_or_null("GameManager") as GameManager
	var player := mundo.get_node_or_null("CharacterBody3D") as Player
	var silhueta := mundo.get_node_or_null("shilhueta") as Silhueta
	var rondante := mundo.get_node_or_null("RondanteFazenda") as RondanteFazenda

	_verificar(gerente != null and player != null and silhueta != null and rondante != null, "Nós principais ausentes em world.tscn.")

	if gerente != null and player != null and silhueta != null and rondante != null:
		_teste_4_gerenciador_ost_e_vento(mundo, gerente, player, silhueta, rondante)
		_teste_5_sfx_e_particulas_mundo(mundo, gerente, player, silhueta, rondante)

	mundo.queue_free()
	await process_frame
	await process_frame
	BancoAudioDelusio.limpar_cache()

	if _falhas.is_empty():
		print("\nOK: Todos os testes da Fase 4 (Áudio, OST Dinâmica e Partículas 3D) passaram!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas na Fase 4:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_buses_audio() -> void:
	print("--- [1] Teste dos AudioBuses (Master, Musica, Ambiente, SFX) ---")
	_verificar(AudioServer.get_bus_index(&"Master") != -1, "AudioBus 'Master' deve existir.")
	_verificar(AudioServer.get_bus_index(&"Musica") != -1, "AudioBus 'Musica' deve existir no default_bus_layout.tres.")
	_verificar(AudioServer.get_bus_index(&"Ambiente") != -1, "AudioBus 'Ambiente' deve existir no default_bus_layout.tres.")
	_verificar(AudioServer.get_bus_index(&"SFX") != -1, "AudioBus 'SFX' deve existir no default_bus_layout.tres.")
	_verificar(BancoAudioDelusio.resolver_bus(&"SFX") == &"SFX", "resolver_bus(&'SFX') deve retornar &'SFX'.")
	_verificar(BancoAudioDelusio.resolver_bus(&"Musica") == &"Musica", "resolver_bus(&'Musica') deve retornar &'Musica'.")
	_verificar(BancoAudioDelusio.resolver_bus(&"BusInexistente") == &"Master", "resolver_bus para bus inexistente deve fazer fallback para &'Master'.")


func _teste_2_main_menu_musica() -> void:
	print("--- [2] Teste da Música Tema no MainMenu ---")
	var cena_menu := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_verificar(cena_menu != null, "Não foi possível carregar res://scenes/ui/main_menu.tscn.")
	if cena_menu == null:
		return

	var menu := cena_menu.instantiate()
	root.add_child(menu)
	await process_frame

	var musica_menu := menu.get_node_or_null("MusicaMenu") as AudioStreamPlayer
	_verificar(musica_menu != null, "MainMenu deve possuir nó MusicaMenu (AudioStreamPlayer).")
	if musica_menu != null:
		_verificar(musica_menu.bus == &"Musica", "MusicaMenu deve rotear no bus 'Musica'.")
		_verificar(musica_menu.stream != null, "MusicaMenu deve ter stream carregado.")
		if musica_menu.stream != null:
			_verificar(
				musica_menu.stream.resource_path == "res://assets/audio/musicas/musica_tema/Delusio Tema Menu v1 Export 1.wav",
				"MusicaMenu deve usar 'Delusio Tema Menu v1 Export 1.wav'."
			)

	menu.queue_free()
	await process_frame


func _teste_3_catalogo_46_sfx(mundo: Node3D) -> void:
	print("--- [3] Teste do BancoAudioDelusio (46 IDs plug-and-play e helpers 2D/3D) ---")
	BancoAudioDelusio.limpar_cache()
	_verificar(BancoAudioDelusio.IDS_SFX.size() == 46, "IDS_SFX deve conter exatamente 46 IDs (atual: %d)." % BancoAudioDelusio.IDS_SFX.size())

	for id_sfx in BancoAudioDelusio.IDS_SFX:
		var stream := BancoAudioDelusio.obter_sfx(id_sfx)
		_verificar(stream != null, "SFX '&%s' retornou stream nulo." % String(id_sfx))
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			_verificar(wav.data.size() > 0, "SFX '&%s' gerou AudioStreamWAV vazio." % String(id_sfx))
			if id_sfx == &"vazamento_agua_loop":
				_verificar(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "vazamento_agua_loop deve possuir LOOP_FORWARD.")

	var player_2d := BancoAudioDelusio.tocar_2d(mundo, &"ui_click", -6.0, 0.02)
	_verificar(player_2d != null, "BancoAudioDelusio.tocar_2d deve criar e retornar AudioStreamPlayer.")
	if player_2d != null:
		_verificar(player_2d.bus == &"SFX", "Player 2D padrão deve usar bus 'SFX'.")
		_verificar(player_2d.stream != null, "Player 2D deve receber stream válido.")

	var player_3d := BancoAudioDelusio.tocar_3d(mundo, &"rondante_garras", Vector3(2.0, 1.0, 2.0), -2.0, 20.0, 0.04)
	_verificar(player_3d != null, "BancoAudioDelusio.tocar_3d deve criar e retornar AudioStreamPlayer3D.")
	if player_3d != null:
		_verificar(player_3d.bus == &"SFX", "Player 3D padrão deve usar bus 'SFX'.")
		_verificar(player_3d.stream != null, "Player 3D deve receber stream válido.")


func _teste_4_gerenciador_ost_e_vento(
	_mundo: Node3D,
	gerente: GameManager,
	player: Player,
	silhueta: Silhueta,
	rondante: RondanteFazenda
) -> void:
	print("--- [4] Teste do GerenciadorAudioMundo (OSTs Dinâmicas e Vento Ambiente) ---")
	var g_audio := get_first_node_in_group("gerenciador_audio_mundo") as GerenciadorAudioMundo
	_verificar(g_audio != null, "GerenciadorAudioMundo deve estar presente e no grupo 'gerenciador_audio_mundo'.")
	if g_audio == null:
		return

	_verificar(g_audio._audio_vento != null, "GerenciadorAudioMundo deve possuir _audio_vento.")
	if g_audio._audio_vento != null:
		_verificar(g_audio._audio_vento.bus == &"Ambiente", "_audio_vento deve usar bus 'Ambiente'.")
		_verificar(g_audio._audio_vento.stream != null, "_audio_vento deve carregar sfx_vento_ambiente.mp3.")
		if g_audio._audio_vento.stream != null:
			_verificar(
				g_audio._audio_vento.stream.resource_path == GerenciadorAudioMundo.SFX_VENTO_AMBIENTE,
				"_audio_vento deve usar %s." % GerenciadorAudioMundo.SFX_VENTO_AMBIENTE
			)

	var dia_orig := gerente.dia_atual
	var horario_orig := gerente.horario_atual
	var pos_orig := player.global_position
	var casa_ctrl := get_first_node_in_group("casa_controlador") as CasaControlador
	var zona_breu := get_first_node_in_group("zona_breu_noturno") as ZonaBreuNoturno

	# Posição garantida fora de casa e fora do breu
	var pos_fora := Vector3(0.0, 1.0, 10.0)
	for candidato in [Vector3(0.0, 1.0, 10.0), Vector3(12.0, 1.0, 10.0), Vector3(0.0, 1.0, -6.0)]:
		var em_casa := casa_ctrl != null and casa_ctrl.contem_ponto_interno(candidato)
		var em_breu := zona_breu != null and zona_breu.contem_ponto(candidato)
		if not em_casa and not em_breu:
			pos_fora = candidato
			break
	player.global_position = pos_fora

	# Rotação OST Dia 1 (OST-7), Dia 2 (OST-3), Dia 3 (OST-1)
	gerente.jogo_encerrado = false
	gerente.horario_atual = 0
	gerente.dia_atual = 1
	g_audio.avaliar_estado_musical(true)
	g_audio._atualizar_volume_vento(0.0, true)
	_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.DIA, "Estado DIA esperado no horário 0.")
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_DIA[0], "Dia 1 deve usar OST-7.")
	_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -16.0), "Vento fora de casa de dia deve ser -16 dB.")

	gerente.dia_atual = 2
	g_audio.avaliar_estado_musical(true)
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_DIA[1], "Dia 2 deve usar OST-3 (livre do menu).")

	gerente.dia_atual = 3
	g_audio.avaliar_estado_musical(true)
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_DIA[2], "Dia 3 deve usar OST-1.")

	# Tarde (OST-2)
	gerente.horario_atual = 1
	g_audio.avaliar_estado_musical(true)
	g_audio._atualizar_volume_vento(0.0, true)
	_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.TARDE, "Estado TARDE esperado no horário 1.")
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_TARDE, "Tarde deve usar OST-2.")
	_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -13.0), "Vento à tarde fora deve ser -13 dB.")

	# Noite Externa (OST-4)
	gerente.horario_atual = 2
	if zona_breu != null:
		zona_breu.jogador_no_breu = false
	g_audio.avaliar_estado_musical(true)
	g_audio._atualizar_volume_vento(0.0, true)
	_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.NOITE_EXTERNA, "Noite fora de casa deve entrar em NOITE_EXTERNA.")
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_NOITE_EXTERNA, "Noite externa deve usar OST-4.")
	_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -10.0), "Vento à noite fora deve ser -10 dB.")

	# Casa Vigília (OST-5) e atenuação indoor do vento
	if casa_ctrl != null:
		player.global_position = casa_ctrl.to_global(Vector3(0.0, 1.0, 0.0))
		g_audio.avaliar_estado_musical(true)
		g_audio._atualizar_volume_vento(0.0, true)
		_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.CASA_VIGILIA, "Jogador dentro de casa à noite deve usar CASA_VIGILIA.")
		_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_CASA_VIGILIA, "Casa vigília deve usar OST-5.")
		_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -24.0), "Vento dentro de casa deve atenuar para -24 dB.")

	# Zona Breu intensifica vento para -6 dB
	if zona_breu != null:
		var lanterna_antes := player.esta_com_lanterna_acesa()
		if not lanterna_antes:
			player.selecionar_slot(0)
			player.alternar_lanterna()
		player.global_position = zona_breu.global_position
		zona_breu.jogador_no_breu = true
		g_audio._atualizar_volume_vento(0.0, true)
		_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -6.0), "Vento na ZonaBreuNoturno deve subir para -6 dB.")
		zona_breu.jogador_no_breu = false
		if player.esta_com_lanterna_acesa() != lanterna_antes:
			player.alternar_lanterna()

	# Caçada (OST-6)
	player.global_position = pos_fora
	rondante.ativa = true
	rondante.estado_atual = RondanteFazenda.Estado.CACADA
	g_audio.avaliar_estado_musical(true)
	_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.CACADA, "Rondante em CACADA deve acionar EstadoMusica.CACADA.")
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_CACADA, "Caçada deve usar OST-6.")
	rondante.ativa = false
	rondante.estado_atual = RondanteFazenda.Estado.PATRULHA

	# Queda de Fusível (OST-8 Curto-circuito)
	if gerente.diretor_eventos_noite != null:
		gerente.diretor_eventos_noite.queda_fusivel_ativa = true
		g_audio.avaliar_estado_musical(true)
		_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.QUEDA_FUSIVEL, "Queda de fusível deve acionar QUEDA_FUSIVEL.")
		_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_CURTO_CIRCUITO, "Queda de fusível deve usar OST-8 Curto-circuito.")
		gerente.diretor_eventos_noite.queda_fusivel_ativa = false

	# Game Over (OST-8 Versão completa) e abafamento do vento
	gerente.jogo_encerrado = true
	g_audio.avaliar_estado_musical(true)
	g_audio._atualizar_volume_vento(0.0, true)
	_verificar(g_audio.estado_musica_atual == GerenciadorAudioMundo.EstadoMusica.GAME_OVER, "Game Over deve acionar EstadoMusica.GAME_OVER.")
	_verificar(g_audio.caminho_faixa_atual == GerenciadorAudioMundo.OST_GAME_OVER, "Game Over deve usar OST-8 Versão completa.")
	_verificar(is_equal_approx(g_audio.volume_vento_alvo_db, -32.0), "Vento em Game Over deve cair para -32 dB.")

	# Restaurar estado base
	gerente.jogo_encerrado = false
	gerente.dia_atual = dia_orig
	gerente.horario_atual = horario_orig
	player.global_position = pos_orig
	silhueta.desativar()
	g_audio.avaliar_estado_musical(true)
	g_audio._atualizar_volume_vento(0.0, true)


func _teste_5_sfx_e_particulas_mundo(
	mundo: Node3D,
	gerente: GameManager,
	player: Player,
	silhueta: Silhueta,
	rondante: RondanteFazenda
) -> void:
	print("--- [5] Teste de SFX 3D e GPUParticles3D nos Atores e Interativos ---")

	# RondanteFazenda streams e bus
	_verificar(rondante.audio_passos != null and rondante.audio_passos.stream != null, "Rondante.audio_passos deve ter stream SFX.")
	_verificar(rondante.audio_vocalizacao != null and rondante.audio_vocalizacao.stream != null, "Rondante.audio_vocalizacao deve ter stream SFX.")
	if rondante.audio_passos != null:
		_verificar(rondante.audio_passos.bus == &"SFX", "Rondante.audio_passos deve usar bus 'SFX'.")
	if rondante.audio_vocalizacao != null:
		_verificar(rondante.audio_vocalizacao.bus == &"SFX", "Rondante.audio_vocalizacao deve usar bus 'SFX'.")

	# Silhueta audio + particulas sombra toggle
	_verificar(silhueta.audio_silhueta != null and silhueta.audio_silhueta.stream != null, "Silhueta.audio_silhueta deve ter stream inicial.")
	if silhueta.audio_silhueta != null:
		_verificar(silhueta.audio_silhueta.bus == &"SFX", "Silhueta.audio_silhueta deve usar bus 'SFX'.")
	_verificar(silhueta.particulas_sombra != null, "Silhueta deve possuir ParticulasSombraSilhueta (GPUParticles3D).")
	if silhueta.particulas_sombra != null:
		_verificar(not silhueta.particulas_sombra.emitting, "ParticulasSombraSilhueta devem iniciar desligadas em INATIVO.")
		silhueta._mudar_estado(Silhueta.Estado.AMEACA_LANTERNA)
		_verificar(silhueta.particulas_sombra.emitting, "ParticulasSombraSilhueta devem emitir em AMEACA_LANTERNA.")
		silhueta.desativar()
		_verificar(not silhueta.particulas_sombra.emitting, "ParticulasSombraSilhueta devem desligar ao chamar desativar().")

	# Dispara noite em Vigília Doméstica para criar marcadores do DiretorEventosNoite e rastros investigativos
	gerente.tarefas_concluidas = gerente.tarefas_totais
	gerente.modo_noturno = GameManager.ModoNoturno.VIGILIA_DOMESTICA
	gerente.iniciar_evento_terror()

	# DiretorEventosNoite 3 marcadores SFX 3D
	var diretor := gerente.diretor_eventos_noite
	_verificar(diretor != null, "DiretorEventosNoite deve existir no GameManager.")
	if diretor != null:
		for nome_m in ["PortaJanelaCasa", "MadeiraCeleiro", "GalhosAtrasJogador"]:
			var marcador := diretor.marcadores_som.get(nome_m, null) as Marker3D
			_verificar(marcador != null, "DiretorEventosNoite deve criar marcador '%s'." % nome_m)
			if marcador != null:
				var audio_m := marcador.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
				_verificar(audio_m != null and audio_m.stream != null, "Marcador '%s' deve ter AudioStreamPlayer3D com stream carregado." % nome_m)
				if audio_m != null:
					_verificar(audio_m.bus == &"SFX", "Marcador '%s' deve usar bus 'SFX'." % nome_m)

	# Player partículas de poeira da lanterna
	_verificar(player.particulas_poeira_lanterna != null, "Player deve possuir ParticulasPoeiraLanterna.")
	if player.particulas_poeira_lanterna != null:
		var horario_prev := gerente.horario_atual
		player.selecionar_slot(0)
		if not player.esta_com_lanterna_acesa():
			player.alternar_lanterna()
		gerente.horario_atual = 2
		player._atualizar_particulas_lanterna()
		_verificar(player.particulas_poeira_lanterna.emitting, "Poeira da lanterna deve emitir à noite com lanterna acesa.")
		player.alternar_lanterna()
		_verificar(not player.particulas_poeira_lanterna.emitting, "Poeira da lanterna deve parar ao apagar a lanterna.")
		gerente.horario_atual = horario_prev

	# CaixaDaAguaTarefa
	var caixa_agua := _buscar_primeiro_por_tipo(mundo, CaixaDaAguaTarefa) as CaixaDaAguaTarefa
	_verificar(caixa_agua != null, "CaixaDaAguaTarefa deve existir em world.tscn.")
	if caixa_agua != null:
		var p_agua := caixa_agua.get_node_or_null("ParticulasVazamentoAgua") as GPUParticles3D
		var a_agua := caixa_agua.get_node_or_null("AudioVazamento3D") as AudioStreamPlayer3D
		_verificar(p_agua != null and p_agua.emitting, "CaixaDaAguaTarefa deve iniciar com ParticulasVazamentoAgua emitindo.")
		_verificar(a_agua != null and a_agua.stream != null and a_agua.bus == &"SFX", "CaixaDaAguaTarefa deve possuir AudioVazamento3D no bus SFX.")
		caixa_agua._aplicar_estado_visual(true)
		_verificar(p_agua != null and not p_agua.emitting, "CaixaDaAguaTarefa deve desligar ParticulasVazamentoAgua quando consertada.")
		caixa_agua._aplicar_estado_visual(false)

	# CaixaFusiveis
	var caixa_fusiveis := get_first_node_in_group("caixas_fusiveis") as CaixaFusiveis
	if caixa_fusiveis == null:
		caixa_fusiveis = _buscar_primeiro_por_tipo(mundo, CaixaFusiveis) as CaixaFusiveis
	_verificar(caixa_fusiveis != null, "CaixaFusiveis deve existir em world.tscn.")
	if caixa_fusiveis != null:
		var p_faiscas := caixa_fusiveis.get_node_or_null("ParticulasFaiscasEletricas") as GPUParticles3D
		_verificar(p_faiscas != null and not p_faiscas.emitting, "ParticulasFaiscasEletricas devem iniciar desligadas.")
		if p_faiscas != null:
			caixa_fusiveis.atualizar_faiscas(1)
			_verificar(p_faiscas.emitting, "ParticulasFaiscasEletricas devem emitir durante queda de fusível.")
			caixa_fusiveis.atualizar_faiscas(0)
			_verificar(not p_faiscas.emitting, "ParticulasFaiscasEletricas devem desligar após religar fusível.")

	# RastroInvestigativo
	var rastro := get_first_node_in_group("rastros_vigilia") as RastroInvestigativo
	if rastro == null:
		rastro = _buscar_primeiro_por_tipo(mundo, RastroInvestigativo) as RastroInvestigativo
	_verificar(rastro != null, "RastroInvestigativo deve existir em world.tscn.")
	if rastro != null:
		var p_rastro := rastro.get_node_or_null("ParticulasRastro") as GPUParticles3D
		_verificar(p_rastro != null and p_rastro.emitting, "RastroInvestigativo deve ter ParticulasRastro emitindo antes da inspeção.")
		rastro._executar_interacao(player)
		_verificar(p_rastro != null and not p_rastro.emitting, "RastroInvestigativo deve parar ParticulasRastro após inspeção.")

	# ItemColetavel
	var item := get_first_node_in_group("itens_coletaveis") as ItemColetavel
	if item == null:
		item = _buscar_primeiro_por_tipo(mundo, ItemColetavel) as ItemColetavel
	_verificar(item != null, "ItemColetavel deve existir em world.tscn.")
	if item != null:
		var p_item := item.get_node_or_null("ParticulasBrilhoItem") as GPUParticles3D
		_verificar(p_item != null and p_item.emitting, "ItemColetavel deve ter ParticulasBrilhoItem emitindo.")

	# ZonaBreuNoturno
	var zona_breu := get_first_node_in_group("zona_breu_noturno") as ZonaBreuNoturno
	_verificar(zona_breu != null, "ZonaBreuNoturno deve existir em world.tscn.")
	if zona_breu != null:
		var p_breu := zona_breu.get_node_or_null("ParticulasBreuSul") as GPUParticles3D
		_verificar(p_breu != null and p_breu.emitting, "ZonaBreuNoturno deve possuir ParticulasBreuSul emitindo.")


func _buscar_primeiro_por_tipo(raiz: Node, tipo: Variant) -> Node:
	if raiz == null:
		return null
	if is_instance_of(raiz, tipo):
		return raiz
	for filho in raiz.get_children():
		var achado := _buscar_primeiro_por_tipo(filho, tipo)
		if achado != null:
			return achado
	return null
