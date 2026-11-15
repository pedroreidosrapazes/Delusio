extends SceneTree

const Aplicador := preload("res://scripts/visual/estilo_pb/aplicador_estilo_pb.gd")


func _initialize() -> void:
	call_deferred("_executar")


func _criar_malha_duas_superficies() -> ArrayMesh:
	var malha := ArrayMesh.new()
	for deslocamento in [0.0, 2.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.FORWARD)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(Vector3(deslocamento, 0.0, 0.0))
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(Vector3(deslocamento + 1.0, 0.0, 0.0))
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(Vector3(deslocamento, 1.0, 0.0))
		st.commit(malha)
	return malha


func _material(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	var gradiente := Gradient.new()
	gradiente.set_color(0, cor)
	gradiente.set_color(1, Color.WHITE)
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	material.albedo_texture = textura
	return material


func _executar() -> void:
	var falhas: Array[String] = []
	var aplicador := Aplicador.new()
	if aplicador.aplicar(null):
		falhas.append("aplicar(null) deveria retornar false")

	var malha := _criar_malha_duas_superficies()
	var original_a := _material(Color.RED)
	var original_b := _material(Color.BLUE)
	malha.surface_set_material(0, original_a)
	malha.surface_set_material(1, original_b)
	var item := MeshInstance3D.new()
	item.mesh = malha
	var override_superficie := _material(Color.YELLOW)
	item.set_surface_override_material(1, override_superficie)
	var override_0_antes := item.get_surface_override_material(0)
	var mascaras := {0: original_a.albedo_texture, 1: override_superficie.albedo_texture}
	if not aplicador.aplicar(item, {"alpha_cutout_threshold": 0.37, "mascaras_por_superficie": mascaras}):
		falhas.append("aplicação da malha multi-superfície falhou")
	else:
		var pb0 := item.get_surface_override_material(0) as ShaderMaterial
		var pb1 := item.get_surface_override_material(1) as ShaderMaterial
		if pb0 == null or pb1 == null:
			falhas.append("cada superfície deveria receber ShaderMaterial")
		elif pb0 == pb1:
			falhas.append("superfícies devem ter materiais independentes")
		elif pb0.get_shader_parameter("tem_textura") != true:
			falhas.append("textura da superfície não foi preservada")
		elif pb0.get_shader_parameter("usar_alpha") != false or (pb0.next_pass as ShaderMaterial).get_shader_parameter("usar_alpha") != false:
			falhas.append("material opaco não deve recortar o alpha da textura")
		elif pb0.get_shader_parameter("textura_original") != original_a.albedo_texture or pb1.get_shader_parameter("textura_original") != override_superficie.albedo_texture:
			falhas.append("material ativo distinto por superfície não foi respeitado")
		elif pb0.get_shader_parameter("mascara_detalhes") != original_a.albedo_texture or pb1.get_shader_parameter("mascara_detalhes") != override_superficie.albedo_texture:
			falhas.append("máscaras configuradas por superfície não foram atribuídas")
		elif not is_equal_approx(pb0.get_shader_parameter("alpha_cutout_threshold"), 0.37):
			falhas.append("limiar alpha customizado não foi aplicado")
		if not aplicador.aplicar(item, {"limiar_borda": 1.6}):
			falhas.append("aplicação repetida deveria ser idempotente")
		if item.get_surface_override_material(0) != pb0:
			falhas.append("aplicação repetida substituiu os materiais já instalados")
		if pb0.get_shader_parameter("limiar_borda") != null:
			falhas.append("aplicação repetida não deve adicionar parâmetros à instância ativa")
		var outro := MeshInstance3D.new()
		outro.mesh = malha
		aplicador.aplicar(outro)
		if pb0 == outro.get_surface_override_material(0):
			falhas.append("instâncias diferentes não podem compartilhar ShaderMaterial")
		aplicador.restaurar(outro)
		outro.free()
		if not aplicador.restaurar(item):
			falhas.append("restauração deveria retornar true")
		if item.material_override != null:
			falhas.append("material_override inicialmente null deveria continuar null")
		if item.get_surface_override_material(0) != override_0_antes:
			falhas.append("override da superfície 0 não foi restaurado")
		if item.get_surface_override_material(1) != override_superficie:
			falhas.append("override da superfície 1 não foi restaurado")
		if aplicador.restaurar(item):
			falhas.append("restauração repetida deveria retornar false")
		item.free()

	var item_com_override := MeshInstance3D.new()
	item_com_override.mesh = malha
	var override_global := _material(Color.GREEN)
	override_global.albedo_color.a = 0.61
	override_global.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	override_global.alpha_scissor_threshold = 0.23
	var superficie_ignorada := _material(Color.RED)
	item_com_override.set_surface_override_material(1, superficie_ignorada)
	item_com_override.material_override = override_global
	if not aplicador.aplicar(item_com_override):
		falhas.append("fluxo com material_override global falhou ao aplicar")
	else:
		var pb_global := item_com_override.get_surface_override_material(0) as ShaderMaterial
		if pb_global.get_shader_parameter("textura_original") != override_global.albedo_texture:
			falhas.append("material_override global deve prevalecer sobre o override de superfície")
		if pb_global.get_shader_parameter("cor_base") != override_global.albedo_color:
			falhas.append("cor do material_override global não foi copiada")
		if not is_equal_approx(pb_global.get_shader_parameter("alpha_cutout_threshold"), 0.23):
			falhas.append("alpha scissor original não foi preservado")
		var contorno_global := pb_global.next_pass as ShaderMaterial
		if contorno_global.get_shader_parameter("usar_alpha") != true:
			falhas.append("material com alpha deve recortar o casco externo")
		if not is_equal_approx(contorno_global.get_shader_parameter("alpha_cor_base"), 0.61):
			falhas.append("alpha da cor base não foi aplicado ao casco externo")
		if not is_equal_approx(contorno_global.get_shader_parameter("alpha_cutout_threshold"), 0.23):
			falhas.append("alpha cutout não foi aplicado ao casco externo")
		if not aplicador.restaurar(item_com_override):
			falhas.append("fluxo com material_override global falhou ao restaurar")
		if item_com_override.material_override != override_global:
			falhas.append("material_override global não foi restaurado")
		if item_com_override.get_surface_override_material(1) != superficie_ignorada:
			falhas.append("override de superfície foi perdido ao restaurar o override global")
	item_com_override.free()

	var raiz := Node3D.new()
	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = malha
	var grupo := Node3D.new()
	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = malha
	raiz.add_child(mesh_a)
	raiz.add_child(grupo)
	grupo.add_child(mesh_b)
	if not aplicador.aplicar_arvore(raiz):
		falhas.append("aplicar_arvore deveria alcançar MeshInstance3D aninhados")
	elif mesh_a.get_surface_override_material(0) == null or mesh_b.get_surface_override_material(0) == null:
		falhas.append("aplicar_arvore não aplicou materiais em todos os descendentes")
	elif mesh_a.get_surface_override_material(0) == mesh_b.get_surface_override_material(0):
		falhas.append("aplicar_arvore compartilhou material entre itens distintos")
	if not aplicador.restaurar_arvore(raiz):
		falhas.append("restaurar_arvore deveria restaurar os descendentes")
	if mesh_a.get_surface_override_material(0) != null or mesh_b.get_surface_override_material(0) != null:
		falhas.append("restaurar_arvore não restaurou os overrides originais")
	raiz.free()

	var item_modificado := MeshInstance3D.new()
	item_modificado.mesh = malha
	var override_original := _material(Color.RED)
	item_modificado.material_override = override_original
	if aplicador.aplicar(item_modificado):
		var override_externo := _material(Color.CYAN)
		var superficie_externa := _material(Color.MAGENTA)
		item_modificado.material_override = override_externo
		item_modificado.set_surface_override_material(0, superficie_externa)
		aplicador.restaurar(item_modificado)
		if item_modificado.material_override != override_externo:
			falhas.append("restauração apagou um material_override externo novo")
		if item_modificado.get_surface_override_material(0) != superficie_externa:
			falhas.append("restauração apagou um override de superfície externo novo")
	else:
		falhas.append("não foi possível instalar no item de teste com alterações ao vivo")
	item_modificado.free()

	var item_malha_trocada := MeshInstance3D.new()
	item_malha_trocada.mesh = malha
	item_malha_trocada.set_surface_override_material(0, original_a)
	if aplicador.aplicar(item_malha_trocada):
		item_malha_trocada.mesh = BoxMesh.new()
		if not aplicador.restaurar(item_malha_trocada):
			falhas.append("restauração após troca de malha deveria concluir")
		if item_malha_trocada.get_surface_override_material(0) != original_a:
			falhas.append("slot correspondente da malha trocada não foi restaurado")
	else:
		falhas.append("aplicação na malha antes da troca falhou")
	item_malha_trocada.free()

	var item_sem_malha := MeshInstance3D.new()
	item_sem_malha.mesh = malha
	if aplicador.aplicar(item_sem_malha):
		item_sem_malha.mesh = null
		if not aplicador.restaurar(item_sem_malha):
			falhas.append("restauração com mesh=null deveria concluir sem erro")
	else:
		falhas.append("aplicação para o teste mesh=null falhou")
	item_sem_malha.free()

	var st_sem_uv := SurfaceTool.new()
	st_sem_uv.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_sem_uv.set_normal(Vector3.FORWARD)
	st_sem_uv.add_vertex(Vector3.ZERO)
	st_sem_uv.add_vertex(Vector3.RIGHT)
	st_sem_uv.add_vertex(Vector3.UP)
	var malha_sem_uv := st_sem_uv.commit()
	var item_sem_uv := MeshInstance3D.new()
	item_sem_uv.mesh = malha_sem_uv
	if not aplicador.aplicar(item_sem_uv):
		falhas.append("malha sem UV deve aplicar com aviso e sem erro")
	elif item_sem_uv.get_surface_override_material(0) == null:
		falhas.append("ShaderMaterial não foi instalado na malha sem UV")
	aplicador.restaurar(item_sem_uv)
	item_sem_uv.free()

	var aplicador_com_itens_liberados := Aplicador.new()
	for _i in 2:
		var item_temporario := MeshInstance3D.new()
		item_temporario.mesh = malha
		aplicador_com_itens_liberados.aplicar(item_temporario)
		item_temporario.free()
	var sobrevivente := MeshInstance3D.new()
	sobrevivente.mesh = malha
	aplicador_com_itens_liberados.aplicar(sobrevivente)
	if aplicador_com_itens_liberados._estados.size() != 1:
		falhas.append("entradas weakref obsoletas não foram limpas")
	aplicador_com_itens_liberados.restaurar(sobrevivente)
	sobrevivente.free()

	if falhas.is_empty():
		print("OK: aplicação multi-superfície, independência, alpha, idempotência, restauração e null")
		quit(0)
	else:
		for falha in falhas:
			push_error(falha)
		quit(1)
