extends SceneTree

## Teste Automatizado Headless — Menu Principal como Entrada e Seleção de Modos:
## Verifica project.godot, botões de Modo Endless e Modo História [Em Breve],
## bloqueio informativo do Modo História ainda em desenvolvimento e propagação para GameManager.

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DO MENU PRINCIPAL E SELEÇÃO DE MODOS ===\n")

	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_verificar(main_scene == "res://scenes/ui/main_menu.tscn", "A cena inicial do projeto deve ser res://scenes/ui/main_menu.tscn (atual: %s)." % main_scene)

	var cena_menu := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_verificar(cena_menu != null, "Não foi possível carregar res://scenes/ui/main_menu.tscn.")
	if cena_menu != null:
		var menu := cena_menu.instantiate() as MainMenu
		_verificar(menu != null, "Instância raiz de main_menu.tscn deve ser MainMenu.")
		if menu != null:
			root.add_child(menu)
			await process_frame

			var btn_endless := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoModoEndless") as Button
			var btn_historia := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoModoHistoria") as Button
			var btn_config := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoConfiguracoes") as Button
			var btn_sair := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/BotoesContainer/BotaoSair") as Button
			var lbl_desc := menu.get_node_or_null("MenuPrincipal/ColunaEsquerda/LabelDescricaoModo") as Label

			_verificar(btn_endless != null and btn_historia != null and btn_config != null and btn_sair != null, "Todos os botões principais (Endless, História, Config, Sair) devem existir em main_menu.tscn.")
			_verificar(lbl_desc != null, "LabelDescricaoModo deve existir abaixo dos botões principais.")
			_verificar(not menu.modo_historia_disponivel, "Modo História deve iniciar bloqueado (modo_historia_disponivel == false).")

			var iniciou_historia := menu.iniciar_modo_historia()
			_verificar(not iniciou_historia, "iniciar_modo_historia() deve retornar false enquanto em desenvolvimento.")
			if lbl_desc != null:
				_verificar(lbl_desc.text.contains("Modo História ainda em desenvolvimento"), "LabelDescricaoModo deve explicar que o Modo História está em desenvolvimento.")

			menu.queue_free()
			await process_frame

	GameManager.definir_modo_jogo(GameManager.ModoJogo.ENDLESS)
	var cena_mundo := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena_mundo != null, "Não foi possível carregar res://scenes/levels/world.tscn.")
	if cena_mundo != null:
		var mundo := cena_mundo.instantiate()
		root.add_child(mundo)
		current_scene = mundo
		await process_frame

		var gerente := mundo.get_node_or_null("GameManager") as GameManager
		_verificar(gerente != null, "GameManager deve existir em world.tscn.")
		if gerente != null:
			_verificar(gerente.modo_jogo == GameManager.ModoJogo.ENDLESS, "GameManager deve herdar ModoJogo.ENDLESS.")
			_verificar(gerente.esta_em_modo_endless(), "esta_em_modo_endless() deve retornar true.")
			_verificar(gerente.obter_nome_modo_jogo() == "MODO ENDLESS", "obter_nome_modo_jogo() deve retornar 'MODO ENDLESS'.")

		mundo.queue_free()
		await process_frame

	if _falhas.is_empty():
		print("\nOK: Menu principal como entrada, Modo Endless, Modo História [Em Breve] e propagação ao GameManager validados!")
		quit(0)
	else:
		push_error("\nERRO: %d falhas encontradas:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)
