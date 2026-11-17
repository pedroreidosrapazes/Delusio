extends SceneTree

var _falhas: Array[String] = []


func _initialize() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error("FALHA: " + mensagem)


func _executar() -> void:
	print("=== INICIANDO TESTES DOS DOCUMENTOS NA MESA ===")

	var cena := load("res://scenes/levels/world.tscn") as PackedScene
	_verificar(cena != null, "Deveria carregar res://scenes/levels/world.tscn.")
	if cena == null:
		quit(1)
		return

	var world := cena.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var casa := world.get_node_or_null("Casa _final-col") as Node3D
	_verificar(casa != null, "Nó 'Casa _final-col' deveria existir em world.tscn.")

	var doc := world.get_node_or_null("Casa _final-col/DocumentoMesa") as DocumentoLeitura
	var jornal := world.get_node_or_null("Casa _final-col/JornalMesa") as DocumentoLeitura
	_verificar(doc != null, "Nó 'DocumentoMesa' (DocumentoLeitura) deveria existir em Casa _final-col.")
	_verificar(jornal != null, "Nó 'JornalMesa' (DocumentoLeitura) deveria existir em Casa _final-col.")

	if doc != null and jornal != null:
		_verificar(doc.pode_interagir(), "DocumentoMesa deveria estar interagível.")
		_verificar(jornal.pode_interagir(), "JornalMesa deveria estar interagível.")
		_verificar(doc.documento_id == &"bilhete_caseiro" and not doc.texto_conteudo.strip_edges().is_empty(), "DocumentoMesa deveria conter o conteúdo do bilhete do caseiro.")
		_verificar(jornal.documento_id == &"jornal_silhueta" and not jornal.texto_conteudo.strip_edges().is_empty(), "JornalMesa deveria conter o conteúdo do jornal da fazenda.")
		_verificar(not ("lorem ipsum" in doc.texto_conteudo.to_lower()) and not ("lorem ipsum" in jornal.texto_conteudo.to_lower()), "Documentos na mesa não devem mais conter placeholder Lorem Ipsum.")

		# Verifica posição sobre o tampo da mesaJantar-col (Y ~ 0.393, X in [2.63..3.20], Z in [-0.92..-0.23])
		_verificar(is_equal_approx(doc.position.y, 0.3932), "DocumentoMesa Y incorreto: %.4f" % doc.position.y)
		_verificar(is_equal_approx(jornal.position.y, 0.3932), "JornalMesa Y incorreto: %.4f" % jornal.position.y)
		_verificar(doc.position.x > 2.75 and doc.position.x < 3.15, "DocumentoMesa fora da faixa X da mesa.")
		_verificar(jornal.position.x > 2.75 and jornal.position.x < 3.15, "JornalMesa fora da faixa X da mesa.")
		_verificar(doc.position.distance_to(jornal.position) > 0.25, "DocumentoMesa e JornalMesa não deveriam se sobrepor.")

		# Verifica malha importada e colisor
		var doc_meshes := doc.find_children("*", "MeshInstance3D", true, false)
		var jornal_meshes := jornal.find_children("*", "MeshInstance3D", true, false)
		_verificar(not doc_meshes.is_empty(), "DocumentoMesa deveria conter MeshInstance3D do GLB.")
		_verificar(not jornal_meshes.is_empty(), "JornalMesa deveria conter MeshInstance3D do GLB.")

		var doc_col := doc.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var jornal_col := jornal.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_verificar(doc_col != null and doc_col.shape != null, "DocumentoMesa deveria ter CollisionShape3D válido.")
		_verificar(jornal_col != null and jornal_col.shape != null, "JornalMesa deveria ter CollisionShape3D válido.")

		# Verifica HUD + PainelLeituraDocumento
		var hud := world.get_node_or_null("Hud") as HUD
		var player := world.get_node_or_null("CharacterBody3D") as Player
		_verificar(hud != null, "HUD deveria existir.")
		_verificar(player != null, "Player deveria existir.")

		var painel := hud.obter_painel_leitura() if hud else null
		_verificar(painel != null, "PainelLeituraDocumento deveria existir na HUD.")
		if painel != null:
			_verificar(not painel.visible, "PainelLeituraDocumento deveria iniciar oculto.")
			_verificar(painel.is_in_group("modal_cursor_ui"), "PainelLeituraDocumento deveria estar no grupo 'modal_cursor_ui'.")

			# Simula interação com a folha
			doc.interagir(player)
			_verificar(painel.visible, "PainelLeituraDocumento deveria abrir ao interagir com DocumentoMesa.")
			_verificar(painel._label_titulo.text == doc.titulo_documento, "Título do painel deveria corresponder ao DocumentoMesa.")
			_verificar(painel._label_texto.text == doc.texto_conteudo, "Texto do painel deveria corresponder ao DocumentoMesa.")

			painel.fechar()
			_verificar(not painel.visible, "PainelLeituraDocumento deveria fechar após chamar fechar().")

			# Simula interação com o jornal
			jornal.interagir(player)
			_verificar(painel.visible, "PainelLeituraDocumento deveria abrir ao interagir com JornalMesa.")
			_verificar(painel._label_titulo.text == jornal.titulo_documento, "Título do painel deveria corresponder ao JornalMesa.")
			_verificar(painel._label_texto.text == jornal.texto_conteudo, "Texto do painel deveria corresponder ao JornalMesa.")
			painel.fechar()

		# Testa RayCast3D do Player mirando diretamente em cima de cada item
		if player != null and player.camera != null and player.raycast != null:
			for alvo in [doc, jornal]:
				var alvo_pos := (alvo as Node3D).global_position + Vector3(0.0, 0.02, 0.0)
				player.global_position = alvo_pos + Vector3(0.0, 0.1, 1.0)
				player.camera.look_at(alvo_pos, Vector3.UP)
				await physics_frame
				player.raycast.force_raycast_update()
				_verificar(player.raycast.is_colliding(), "RayCast3D deveria colidir ao mirar em " + alvo.name)
				if player.raycast.is_colliding():
					_verificar(player.raycast.get_collider() == alvo, "RayCast3D deveria atingir " + alvo.name)

	world.queue_free()
	await process_frame

	if _falhas.is_empty():
		print("OK: Todos os testes dos documentos interativos na mesa passaram!")
		quit(0)
	else:
		push_error("ERRO: %d falhas encontradas:" % _falhas.size())
		for f in _falhas:
			push_error(" - " + f)
		quit(1)
