extends SceneTree

## Teste Automatizado Headless — Fase 5 (Cadernos 3D nos Menus, Animações e Configurações):
## Valida:
## 1. diario_menu.glb com Skeleton3D (4 ossos) e AnimationPlayer (RIG_DiarioAction) + caderno_dobrado_tasks.glb
## 2. ConfiguracoesUsuario (persistência e aplicação nos 4 buses + brilho + sensibilidade_mouse)
## 3. MenuPausa com SubViewport 3D do Diário, Modo Híbrido, sliders extras e PROCESS_MODE_ALWAYS
## 4. PainelListaTarefas [X] com SubViewport 3D do Caderno Dobrado
## 5. MainMenu intacto + sincronização de configurações preservando demais chaves

const CAMINHO_CFG_TMP: String = "user://teste_fase5_config_tmp.cfg"
var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _limpar_cfg_tmp() -> void:
	var real: String = ProjectSettings.globalize_path(CAMINHO_CFG_TMP)
	if FileAccess.file_exists(real):
		DirAccess.remove_absolute(real)


func _executar() -> void:
	print("=== INICIANDO TESTES DA FASE 5: CADERNOS 3D NOS MENUS E CONFIGURAÇÕES ===\n")
	_limpar_cfg_tmp()

	_teste_1_modelos_3d_cadernos()
	_teste_2_configuracoes_usuario()

	GameManager.definir_modo_jogo(GameManager.ModoJogo.ENDLESS)
	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Não foi possível carregar res://scenes/levels/world.tscn.")
	if cena != null:
		var mundo := cena.instantiate() as Node3D
		root.add_child(mundo)
		current_scene = mundo
		await process_frame
		await physics_frame

		var hud := mundo.get_node_or_null("Hud") as HUD
		var player := mundo.get_node_or_null("CharacterBody3D") as Player
		var pausas := mundo.find_children("*", "MenuPausa", true, false)
		var menu_pausa := (pausas[0] as MenuPausa) if not pausas.is_empty() else null

		_verificar(hud != null and player != null and menu_pausa != null, "HUD, Player ou MenuPausa ausentes em world.tscn.")
		if hud != null and player != null and menu_pausa != null:
			_teste_3_menu_pausa_diario_3d(menu_pausa, player)
			_teste_4_lista_tarefas_caderno_dobrado(hud)

		ConfiguracoesUsuario.aplicar_todas(ConfiguracoesUsuario.valores_padrao(), self, false)
		mundo.queue_free()
		await process_frame
		await process_frame

	await _teste_5_main_menu_intacto_e_sync()

	ConfiguracoesUsuario.aplicar_todas(ConfiguracoesUsuario.valores_padrao(), self, false)
	_limpar_cfg_tmp()

	if _falhas.is_empty():
		print("\nOK: Todos os testes da Fase 5 (Cadernos 3D nos Menus e Configurações) passaram!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas na Fase 5:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)


func _teste_1_modelos_3d_cadernos() -> void:
	print("--- [1] Teste dos Modelos 3D (diario_menu.glb com RIG + caderno_dobrado_tasks.glb) ---")
	var cena_diario := load("res://assets/ui/diario_menu.glb") as PackedScene
	_verificar(cena_diario != null, "diario_menu.glb deve carregar como PackedScene.")
	if cena_diario != null:
		var inst_d := cena_diario.instantiate()
		var anim_d := inst_d.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_verificar(anim_d != null, "diario_menu.glb deve importar AnimationPlayer com a animação do .blend.")
		if anim_d != null:
			var achou_anim := anim_d.has_animation("RIG_DiarioAction") or anim_d.has_animation("Abrir")
			_verificar(achou_anim, "AnimationPlayer do Diário deve conter RIG_DiarioAction ou Abrir.")
			if achou_anim:
				var nome_a: String = "Abrir" if anim_d.has_animation("Abrir") else "RIG_DiarioAction"
				_verificar(anim_d.get_animation(nome_a).length > 0.05, "Animação de abertura do Diário deve ter duração > 0.05s.")
		var skel := inst_d.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel == null:
			for c in inst_d.find_children("*", "Skeleton3D", true, false):
				skel = c as Skeleton3D
				break
		_verificar(skel != null, "diario_menu.glb deve conter Skeleton3D do RIG_Diario.")
		if skel != null:
			for osso in ["Root", "Lombada", "Pagina.L", "Pagina.R"]:
				_verificar(skel.find_bone(osso) != -1, "Skeleton3D deve conter o osso '%s'." % osso)
		inst_d.free()

	var cena_caderno := load("res://assets/ui/caderno_dobrado_tasks.glb") as PackedScene
	_verificar(cena_caderno != null, "caderno_dobrado_tasks.glb deve carregar como PackedScene.")
	if cena_caderno != null:
		var inst_c := cena_caderno.instantiate()
		_verificar(inst_c.find_child("Caderno_Frente", true, false) != null, "caderno_dobrado_tasks.glb deve conter Caderno_Frente.")
		_verificar(inst_c.find_child("Caderno_Mola", true, false) != null, "caderno_dobrado_tasks.glb deve conter Caderno_Mola.")
		_verificar(inst_c.find_child("Caderno_Verso", true, false) != null, "caderno_dobrado_tasks.glb deve conter Caderno_Verso.")
		inst_c.free()


func _teste_2_configuracoes_usuario() -> void:
	print("--- [2] Teste de Persistência ConfiguracoesUsuario ---")
	_limpar_cfg_tmp()
	var padrao: Dictionary = ConfiguracoesUsuario.carregar(CAMINHO_CFG_TMP)
	_verificar(is_equal_approx(float(padrao["volume_master"]), 100.0), "Padrão volume_master deve ser 100.")
	_verificar(is_equal_approx(float(padrao["brilho"]), 1.0), "Padrão brilho deve ser 1.0.")
	_verificar(is_equal_approx(float(padrao["sensibilidade_mouse"]), 0.002), "Padrão sensibilidade_mouse deve ser 0.002.")

	var custom: Dictionary = {
		"volume_master": 50.0,
		"volume_musica": 25.0,
		"volume_ambiente": 80.0,
		"volume_sfx": 0.0,
		"tela_cheia": true,
		"vsync": false,
		"brilho": 1.25,
		"sensibilidade_mouse": 0.004
	}
	var err: int = ConfiguracoesUsuario.salvar(custom, CAMINHO_CFG_TMP)
	_verificar(err == OK, "ConfiguracoesUsuario.salvar deve retornar OK.")

	var recarregado: Dictionary = ConfiguracoesUsuario.carregar(CAMINHO_CFG_TMP)
	_verificar(is_equal_approx(float(recarregado["volume_master"]), 50.0), "volume_master salvo deve recarregar como 50.")
	_verificar(is_equal_approx(float(recarregado["volume_musica"]), 25.0), "volume_musica salvo deve recarregar como 25.")
	_verificar(is_equal_approx(float(recarregado["volume_ambiente"]), 80.0), "volume_ambiente salvo deve recarregar como 80.")
	_verificar(is_equal_approx(float(recarregado["volume_sfx"]), 0.0), "volume_sfx salvo deve recarregar como 0.")
	_verificar(bool(recarregado["tela_cheia"]) == true, "tela_cheia salva deve recarregar como true.")
	_verificar(bool(recarregado["vsync"]) == false, "vsync salvo deve recarregar como false.")
	_verificar(is_equal_approx(float(recarregado["brilho"]), 1.25), "brilho salvo deve recarregar como 1.25.")
	_verificar(is_equal_approx(float(recarregado["sensibilidade_mouse"]), 0.004), "sensibilidade_mouse salva deve recarregar como 0.004.")

	ConfiguracoesUsuario.aplicar_todas(recarregado, self, false)
	_verificar(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Bus SFX com volume 0 deve ficar mutado.")
	ConfiguracoesUsuario.aplicar_todas(ConfiguracoesUsuario.valores_padrao(), self, false)
	_verificar(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Bus SFX restaurado deve desmutar.")
	_limpar_cfg_tmp()


func _teste_3_menu_pausa_diario_3d(mp: MenuPausa, player: Player) -> void:
	print("--- [3] Teste do MenuPausa sobre Diário 3D e Configurações ---")
	mp.caminho_config = CAMINHO_CFG_TMP
	_verificar(mp.sub_viewport_diario != null and mp.sub_viewport_diario.transparent_bg, "MenuPausa deve ter SubViewport 3D transparente.")
	_verificar(mp.diario_modelo != null, "MenuPausa deve instanciar DiarioModelo.")
	_verificar(mp._anim_diario != null and not mp._nome_anim_abrir.is_empty(), "MenuPausa deve detectar AnimationPlayer e ação de abrir do Diário.")
	if mp._anim_diario != null:
		_verificar(mp._anim_diario.process_mode == Node.PROCESS_MODE_ALWAYS, "AnimationPlayer do Diário deve usar PROCESS_MODE_ALWAYS.")
	_verificar(mp.camada_paginas != null, "MenuPausa deve possuir CamadaPaginas em modo híbrido.")

	var sfx_papel := BancoAudioDelusio.tocar_2d(mp, &"papel_abrir")
	_verificar(sfx_papel != null and sfx_papel.process_mode == Node.PROCESS_MODE_ALWAYS, "SFX papel_abrir deve rodar em PROCESS_MODE_ALWAYS durante pausa.")

	mp.pausar_jogo()
	_verificar(paused == true, "pausar_jogo() deve pausar a SceneTree.")
	_verificar(mp.visible and mp.painel_pausa.visible and not mp.painel_configuracoes.visible, "MenuPausa deve abrir em PainelPausa sobre a página direita.")

	mp._on_botao_configuracoes_pressed()
	_verificar(mp.painel_configuracoes.visible and not mp.painel_pausa.visible, "Botão Configurações deve alternar para PainelConfiguracoes.")

	_verificar(mp.slider_musica != null and mp.slider_ambiente != null and mp.slider_sfx != null, "Sliders individuais de Musica/Ambiente/SFX devem existir.")
	_verificar(mp.slider_sensibilidade != null, "Slider de Sensibilidade do Mouse deve existir.")
	if mp.slider_musica != null:
		mp.slider_musica.value = 60.0
	if mp.slider_sfx != null:
		mp.slider_sfx.value = 0.0
	if mp.slider_sensibilidade != null:
		mp.slider_sensibilidade.value = 0.0036
	mp.slider_brilho.value = 1.2

	_verificar(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Alterar SliderSFX para 0 deve mutar o bus SFX.")
	_verificar(is_equal_approx(player.sensibilidade_mouse, 0.0036), "SliderSensibilidade deve atualizar Player.sensibilidade_mouse ao vivo.")
	var salvo: Dictionary = ConfiguracoesUsuario.carregar(CAMINHO_CFG_TMP)
	_verificar(is_equal_approx(float(salvo["volume_musica"]), 60.0), "SliderMusica deve persistir no arquivo de configuração.")
	_verificar(is_equal_approx(float(salvo["brilho"]), 1.2), "SliderBrilho deve persistir no arquivo de configuração.")

	mp._on_botao_voltar_pausa_pressed()
	_verificar(mp.painel_pausa.visible and not mp.painel_configuracoes.visible, "Voltar deve retornar a PainelPausa.")

	mp.retomar_jogo(true)
	_verificar(not paused and not mp.visible, "retomar_jogo(true) deve despausar e ocultar MenuPausa.")


func _teste_4_lista_tarefas_caderno_dobrado(hud: HUD) -> void:
	print("--- [4] Teste do PainelListaTarefas [X] com Caderno Dobrado 3D ---")
	var painel := hud.obter_painel_lista_tarefas()
	_verificar(painel != null, "HUD deve conter PainelListaTarefas.")
	if painel == null:
		return

	_verificar(painel._sub_viewport != null and painel._sub_viewport.transparent_bg, "PainelListaTarefas deve usar SubViewport transparente.")
	var mod_caderno := painel._pivot_caderno.find_child("CadernoDobradoModelo", true, false) if painel._pivot_caderno != null else null
	_verificar(mod_caderno != null, "PainelListaTarefas deve instanciar caderno_dobrado_tasks.glb.")
	_verificar(not painel.esta_aberta() and not painel.visible, "Caderno de Tarefas deve iniciar fechado.")

	hud.alternar_lista_tarefas()
	_verificar(painel.esta_aberta() and painel.visible, "alternar_lista_tarefas() deve abrir o caderno dobrado.")

	hud.alternar_lista_tarefas()
	_verificar(not painel.esta_aberta() and not painel.visible, "alternar_lista_tarefas() novamente deve fechar o caderno dobrado.")


func _teste_5_main_menu_intacto_e_sync() -> void:
	print("--- [5] Teste do MainMenu Intacto e Sincronização ConfiguracoesUsuario ---")
	ConfiguracoesUsuario.salvar({
		"volume_master": 70.0,
		"volume_musica": 85.0,
		"volume_ambiente": 90.0,
		"volume_sfx": 85.0,
		"brilho": 1.15,
		"sensibilidade_mouse": 0.003
	}, CAMINHO_CFG_TMP)

	var cena_menu := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_verificar(cena_menu != null, "Não foi possível carregar main_menu.tscn.")
	if cena_menu == null:
		return

	var menu := cena_menu.instantiate() as MainMenu
	menu.caminho_config = CAMINHO_CFG_TMP
	root.add_child(menu)
	await process_frame

	menu._inicializar_valores_ui()
	_verificar(menu.botao_modo_endless != null and menu.botao_modo_historia != null, "Botões do MainMenu devem permanecer intactos.")
	_verificar(menu.musica_menu != null, "MusicaMenu deve permanecer intacta no MainMenu.")
	_verificar(is_equal_approx(menu.audio_slider.value, 0.70), "MainMenu audio_slider deve carregar volume_master / 100.")
	_verificar(is_equal_approx(menu.brilho_slider.value, 1.15), "MainMenu brilho_slider deve carregar brilho salvo.")

	menu.audio_slider.value = 0.90
	menu._on_audio_slider_value_changed(0.90)
	var apos: Dictionary = ConfiguracoesUsuario.carregar(CAMINHO_CFG_TMP)
	_verificar(is_equal_approx(float(apos["volume_master"]), 90.0), "MainMenu deve salvar volume_master atualizado.")
	_verificar(is_equal_approx(float(apos["volume_sfx"]), 85.0), "MainMenu não deve sobrescrever volume_sfx configurado na pausa.")

	menu.queue_free()
	await process_frame
