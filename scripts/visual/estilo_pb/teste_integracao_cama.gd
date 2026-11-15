extends SceneTree

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error(mensagem)


func _material_estilo(cama: MeshInstance3D) -> ShaderMaterial:
	if cama.get_surface_override_material_count() == 0:
		return null
	return cama.get_surface_override_material(0) as ShaderMaterial


func _executar() -> void:
	var cena := load("res://scenes/world.tscn") as PackedScene
	if cena == null:
		push_error("Não foi possível carregar scenes/world.tscn")
		quit(1)
		return
	var mundo := cena.instantiate()
	root.add_child(mundo)
	current_scene = mundo
	await process_frame
	await process_frame

	var gerente := mundo.get_node("GameManager") as GameManager
	var casa := mundo.get_node("Casa _final-col") as CasaControlador
	var cama := casa.find_child("cama", true, false) as MeshInstance3D
	var corpo_cama := cama.find_child("StaticBody3D", true, false) as StaticBody3D if cama != null else null
	var ambiente := mundo.get_node("WorldEnvironment") as WorldEnvironment
	_verificar(gerente != null and casa != null and cama != null and ambiente != null, "Cama, casa, GameManager ou ambiente ausente na cena real.")
	if _falhas.size() > 0:
		quit(1)
		return

	var material_original := cama.mesh.surface_get_material(0)
	_verificar(cama.get_surface_override_material(0) == null, "A cama já iniciou com override de superfície.")
	_verificar(not ambiente.environment.glow_enabled, "O teste espera Glow desligado inicialmente no mundo.")
	_verificar(corpo_cama != null and corpo_cama.get_script() == load("res://scripts/interactables/cama.gd"), "O corpo interativo da cama não foi sincronizado.")
	_verificar(gerente.tarefas_concluidas == 0, "O dia não começou com contador de tarefas zerado.")

	var caixa_1 := mundo.get_node("Objetos_Tarefas/Planta1") as TarefaInterativa
	var caixa_2 := mundo.get_node("Objetos_Tarefas/Planta2") as TarefaInterativa
	var caixa_3 := mundo.get_node("Objetos_Tarefas/Planta3") as TarefaInterativa
	var hud := mundo.get_node("Hud/LabelTarefas") as Label
	_verificar(caixa_1 != null and caixa_2 != null and caixa_3 != null, "Uma das três tarefas interativas não foi carregada.")
	_verificar(hud != null, "O label de tarefas não foi carregado.")

	# As duas primeiras caixas não devem mudar a aparência, e dormir ainda é bloqueado.
	caixa_1.interagir()
	caixa_2.interagir()
	corpo_cama.interagir()
	_verificar(gerente.dia_atual == 1 and gerente.tarefas_concluidas == 2, "A tentativa de dormir antes da terceira tarefa não foi bloqueada.")
	_verificar(hud.text.contains("pendentes"), "O HUD não mostrou o aviso de tarefas pendentes ao tentar dormir cedo.")
	_verificar(cama.get_surface_override_material(0) == null, "O material mudou antes de concluir as três caixas.")
	_verificar(not ambiente.environment.glow_enabled, "Glow ativou antes de concluir as três caixas.")
	await create_timer(3.1).timeout
	_verificar(hud.text.contains("Tarefas: 2 / 3"), "O HUD não voltou ao progresso das duas primeiras caixas após o aviso.")

	# A terceira caixa ativa o material na malha da cama, preservando o corpo de interação.
	caixa_3.interagir()
	_verificar(hud.text.contains("durma na cama"), "O HUD não instruiu o jogador a ir dormir após a terceira caixa.")
	var material_ativo := _material_estilo(cama)
	_verificar(material_ativo != null, "O estilo PB não foi aplicado ao concluir a terceira caixa.")
	if material_ativo != null:
		_verificar(material_ativo.shader == preload("res://shaders/estilo_pb/material_pb.gdshader"), "A cama não recebeu o shader preto e branco esperado.")
		_verificar(material_ativo.next_pass != null, "O contorno animado não foi aplicado à cama.")
		_verificar(material_ativo.get_shader_parameter("textura_original") == material_original.albedo_texture, "O shader não manteve a textura atlas da cama.")
		_verificar(material_ativo.get_shader_parameter("usar_extracao_automatica") == true, "A extração das linhas da textura não foi ativada.")
	_verificar(ambiente.environment.glow_enabled, "Glow não ativou junto com o efeito da cama.")
	_verificar(corpo_cama != null and corpo_cama.get_script() == load("res://scripts/interactables/cama.gd"), "A interação da cama foi perdida ao aplicar o efeito.")

	# Dormir inicia o próximo dia e precisa restaurar override e Glow.
	gerente.tentar_dormir()
	await process_frame
	_verificar(gerente.tarefas_concluidas == 0, "O próximo dia não zerou tarefas.")
	_verificar(hud.text.contains("Tarefas: 0 / 3"), "O HUD não foi reiniciado para o novo dia.")
	_verificar(cama.get_surface_override_material(0) == null, "O material original da cama não foi restaurado ao dormir.")
	_verificar(cama.mesh.surface_get_material(0) == material_original, "O material de origem da cama mudou.")
	_verificar(not ambiente.environment.glow_enabled, "Glow não foi restaurado ao começar o próximo dia.")

	# Reaplicar em um segundo ciclo detecta estado antigo ou referências duplicadas.
	caixa_1.interagir()
	caixa_2.interagir()
	caixa_3.interagir()
	_verificar(_material_estilo(cama) != null and ambiente.environment.glow_enabled, "O segundo ciclo não reativou o efeito.")
	corpo_cama.interagir()
	await process_frame
	_verificar(cama.get_surface_override_material(0) == null and not ambiente.environment.glow_enabled, "O segundo ciclo não restaurou o estado inicial.")

	if _falhas.is_empty():
		print("OK: integração da cama passou em dois ciclos de 3 tarefas, com shader, extração, Glow e restauração.")
		quit(0)
	else:
		quit(1)
