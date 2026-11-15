extends SceneTree


func _initialize() -> void:
	call_deferred("_executar")


func _executar() -> void:
	var limiar := 0.55
	var args := OS.get_cmdline_user_args()
	for argumento in args:
		if argumento.begins_with("limiar="):
			limiar = argumento.get_slice("=", 1).to_float()
	var cena := load("res://scenes/demos/estilo_pb/demo_estilo_pb.tscn") as PackedScene
	if cena == null:
		push_error("Cena de demonstração do rádio indisponível.")
		quit(1)
		return
	var demo := cena.instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	var radio := demo.find_child("Objeto_Demo_Estilo_PB", true, false) as MeshInstance3D
	if radio == null:
		push_error("A demonstração não carregou a malha do rádio.")
		quit(1)
		return
	var material := radio.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		push_error("A demonstração do rádio não recebeu o material PB.")
		quit(1)
		return
	material.set_shader_parameter("usar_extracao_automatica", true)
	material.set_shader_parameter("tem_mascara_detalhes", false)
	material.set_shader_parameter("limiar_borda", limiar)
	RenderingServer.force_draw(false)
	await process_frame
	var imagem := root.get_texture().get_image()
	var destino := OS.get_environment("TEMP").path_join("estilo_pb_radio_auto_%0.2f.png" % limiar)
	var erro := imagem.save_png(destino)
	if erro != OK:
		push_error("Falha ao salvar captura do rádio: %s" % error_string(erro))
		quit(1)
		return
	print("OK: extração automática do rádio renderizada sem máscara manual; limiar=%0.2f; captura: %s" % [limiar, destino])
	quit(0)
