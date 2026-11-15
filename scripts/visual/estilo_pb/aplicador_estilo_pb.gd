class_name AplicadorEstiloPB
extends RefCounted

const SHADER_MATERIAL := preload("res://shaders/estilo_pb/material_pb.gdshader")
const SHADER_CONTORNO := preload("res://shaders/estilo_pb/contorno_pb.gdshader")

var _estados: Dictionary = {}


func aplicar_arvore(raiz: Node, parametros: Dictionary = {}) -> bool:
	if not is_instance_valid(raiz):
		push_warning("Estilo PB: a raiz precisa ser um Node válido.")
		return false
	var itens: Array[MeshInstance3D] = []
	_coletar_itens(raiz, itens)
	var quantidade_aplicada := 0
	for item in itens:
		if aplicar(item, parametros):
			quantidade_aplicada += 1
	return quantidade_aplicada > 0


func restaurar_arvore(raiz: Node) -> bool:
	if not is_instance_valid(raiz):
		return false
	var itens: Array[MeshInstance3D] = []
	_coletar_itens(raiz, itens)
	var quantidade_restaurada := 0
	for item in itens:
		if restaurar(item):
			quantidade_restaurada += 1
	return quantidade_restaurada > 0


func _coletar_itens(no: Node, itens: Array[MeshInstance3D]) -> void:
	if no is MeshInstance3D:
		itens.append(no as MeshInstance3D)
	for filho in no.get_children():
		_coletar_itens(filho, itens)


func aplicar(item: MeshInstance3D, parametros: Dictionary = {}) -> bool:
	_limpar_estados_obsoletos()
	if not is_instance_valid(item) or item.mesh == null:
		push_warning("Estilo PB: o item precisa ser um MeshInstance3D válido com malha.")
		return false
	var id := item.get_instance_id()
	if _estados.has(id):
		return true

	var n_superficies := item.mesh.get_surface_count()
	if n_superficies == 0:
		push_warning("Estilo PB: a malha não contém superfícies.")
		return false

	var origem := {
		"malha": item.mesh,
		"material_override": item.material_override,
		"overrides": [],
		"materiais": [],
		"instalados": [],
	}
	for i in n_superficies:
		var override_superficie := item.get_surface_override_material(i)
		origem.overrides.append(override_superficie)
		var material: Material = item.material_override
		if material == null:
			material = override_superficie
		if material == null:
			material = item.mesh.surface_get_material(i)
		origem.materiais.append(material)

	for i in n_superficies:
		var material_origem: Material = origem.materiais[i]
		if material_origem is ShaderMaterial:
			push_warning("Estilo PB: ShaderMaterial na superfície %d não pode ser convertido com segurança; será tratado sem textura/tinta de origem." % i)
		var resultado := _criar_shader_material(material_origem, item.mesh, i, parametros, _criar_shader_contorno(parametros))
		item.set_surface_override_material(i, resultado)
		origem.instalados.append(resultado)
	item.material_override = null
	_estados[id] = {"item": weakref(item), "origem": origem}
	return true


func restaurar(item: MeshInstance3D) -> bool:
	_limpar_estados_obsoletos()
	if not is_instance_valid(item):
		return false
	var id := item.get_instance_id()
	if not _estados.has(id):
		return false
	var estado: Dictionary = _estados[id]
	var origem: Dictionary = estado.origem
	if item.material_override == null:
		item.material_override = origem.material_override
	if item.mesh != null:
		var malha_original: Mesh = origem.malha
		var quantidade_superficies := mini(item.mesh.get_surface_count(), malha_original.get_surface_count())
		quantidade_superficies = mini(quantidade_superficies, origem.instalados.size())
		for i in quantidade_superficies:
			if item.get_surface_override_material(i) == origem.instalados[i]:
				item.set_surface_override_material(i, origem.overrides[i])
	_estados.erase(id)
	return true


func _limpar_estados_obsoletos() -> void:
	for id in _estados.keys():
		var estado: Dictionary = _estados[id]
		var referencia: WeakRef = estado.item
		if referencia.get_ref() == null:
			_estados.erase(id)


func _criar_shader_material(material_origem: Material, malha: Mesh, indice: int, parametros: Dictionary, contorno: ShaderMaterial) -> ShaderMaterial:
	var resultado := ShaderMaterial.new()
	resultado.shader = SHADER_MATERIAL
	var textura: Texture2D
	var cor := Color.WHITE
	var escala_uv := Vector3.ONE
	var offset_uv := Vector3.ZERO
	var alpha_cutout := 0.5
	var usar_alpha := false
	if material_origem is BaseMaterial3D:
		var base := material_origem as BaseMaterial3D
		textura = base.albedo_texture
		cor = base.albedo_color
		escala_uv = base.uv1_scale
		offset_uv = base.uv1_offset
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			usar_alpha = true
			push_warning("Estilo PB: material com transparência será aproximado por alpha cutout; blending e ordenação de objetos transparentes não são preservados.")
		if base is StandardMaterial3D and base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			alpha_cutout = (base as StandardMaterial3D).alpha_scissor_threshold
	else:
		push_warning("Estilo PB: material de origem não é BaseMaterial3D; usando branco como cor base.")
	
	var arrays: Array = malha.surface_get_arrays(indice)
	var uv1: Variant = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV else null
	if not (uv1 is PackedVector2Array) or (uv1 as PackedVector2Array).is_empty():
		push_warning("Estilo PB: a superfície %d não possui UV1; a textura e máscara não terão amostragem correta." % indice)
	resultado.set_shader_parameter("textura_original", textura)
	resultado.set_shader_parameter("tem_textura", textura != null)
	resultado.set_shader_parameter("cor_base", cor)
	resultado.set_shader_parameter("tamanho_textura", Vector2(textura.get_width(), textura.get_height()) if textura != null else Vector2.ONE)
	resultado.set_shader_parameter("uv1_scale", escala_uv)
	resultado.set_shader_parameter("uv1_offset", offset_uv)
	resultado.set_shader_parameter("alpha_cutout_threshold", parametros.get("alpha_cutout_threshold", alpha_cutout))
	resultado.set_shader_parameter("usar_alpha", usar_alpha)
	resultado.set_shader_parameter("usar_extracao_automatica", parametros.get("usar_extracao_automatica", true))
	var mascara: Variant = parametros.get("mascara_detalhes")
	var mascaras_por_superficie: Dictionary = parametros.get("mascaras_por_superficie", {})
	if mascaras_por_superficie.has(indice):
		mascara = mascaras_por_superficie[indice]
	elif mascaras_por_superficie.has(str(indice)):
		mascara = mascaras_por_superficie[str(indice)]
	resultado.set_shader_parameter("mascara_detalhes", mascara)
	resultado.set_shader_parameter("tem_mascara_detalhes", mascara is Texture2D)
	for chave in ["limiar_luminancia", "forca_linhas", "limiar_borda", "escala_amostragem", "escala_automatica", "contraste_mascara", "intensidade_rim", "largura_rim", "realcar_areas_claras"]:
		if parametros.has(chave):
			resultado.set_shader_parameter(chave, parametros[chave])
	contorno.set_shader_parameter("textura_alpha", textura)
	contorno.set_shader_parameter("tem_textura_alpha", textura != null)
	contorno.set_shader_parameter("usar_alpha", usar_alpha)
	contorno.set_shader_parameter("alpha_cor_base", cor.a)
	contorno.set_shader_parameter("alpha_cutout_threshold", parametros.get("alpha_cutout_threshold", alpha_cutout))
	contorno.set_shader_parameter("uv1_scale", escala_uv)
	contorno.set_shader_parameter("uv1_offset", offset_uv)
	resultado.next_pass = contorno
	return resultado


func _criar_shader_contorno(parametros: Dictionary) -> ShaderMaterial:
	var contorno := ShaderMaterial.new()
	contorno.shader = SHADER_CONTORNO
	for chave in ["espessura_contorno", "intensidade_faixa", "largura_faixa", "velocidade_faixa", "escala_faixa", "intensidade_glow"]:
		if parametros.has(chave):
			contorno.set_shader_parameter(chave, parametros[chave])
	return contorno
