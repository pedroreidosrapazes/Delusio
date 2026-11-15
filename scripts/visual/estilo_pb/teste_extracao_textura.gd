extends SceneTree

const SHADER_PB := preload("res://shaders/estilo_pb/material_pb.gdshader")
const DIMENSAO := 64

var _falhas: Array[String] = []
var _quadros: Array[MeshInstance3D] = []


func _initialize() -> void:
	call_deferred("_executar")


func _textura(tipo: String) -> Texture2D:
	var imagem := Image.create(DIMENSAO, DIMENSAO, false, Image.FORMAT_RGBA8)
	for y in DIMENSAO:
		for x in DIMENSAO:
			var cor := Color(0.035, 0.035, 0.035, 1.0)
			match tipo:
				"plana":
					cor = Color(0.035, 0.035, 0.035, 1.0)
				"baixo_contraste":
					cor = Color(0.035, 0.035, 0.035, 1.0) if (x / 8) % 2 == 0 else Color(0.16, 0.16, 0.16, 1.0)
				"isoluminante":
					# Vermelho e verde com luminância linear aproximada igual.
					cor = Color(0.50, 0.0, 0.0, 1.0) if (x / 8) % 2 == 0 else Color(0.0, 0.274, 0.0, 1.0)
			imagem.set_pixel(x, y, cor)
	return ImageTexture.create_from_image(imagem)


func _adicionar_cartao(pai: Node3D, tipo: String, x: float) -> MeshInstance3D:
	var cartao := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 1.8)
	cartao.mesh = quad
	cartao.position = Vector3(x, 0.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = SHADER_PB
	material.set_shader_parameter("textura_original", _textura(tipo))
	material.set_shader_parameter("tem_textura", true)
	material.set_shader_parameter("tamanho_textura", Vector2(DIMENSAO, DIMENSAO))
	material.set_shader_parameter("limiar_borda", 0.5)
	material.set_shader_parameter("escala_automatica", true)
	material.set_shader_parameter("intensidade_rim", 0.0)
	cartao.material_override = material
	pai.add_child(cartao)
	return cartao


func _contar_linhas(imagem: Image, cartao: MeshInstance3D) -> Dictionary:
	var camera := get_root().get_camera_3d()
	var centro := camera.unproject_position(cartao.global_position)
	var canto := camera.unproject_position(cartao.global_position + Vector3(0.9, 0.9, 0.0))
	var raio_x: int = roundi(abs(canto.x - centro.x))
	var raio_y: int = roundi(abs(canto.y - centro.y))
	var brancos := 0
	var pixels := 0
	for y in range(maxi(0, roundi(centro.y) - raio_y), mini(imagem.get_height(), roundi(centro.y) + raio_y)):
		for x in range(maxi(0, roundi(centro.x) - raio_x), mini(imagem.get_width(), roundi(centro.x) + raio_x)):
			pixels += 1
			if imagem.get_pixel(x, y).r > 0.55:
				brancos += 1
	return {"brancos": brancos, "pixels": pixels, "proporcao": float(brancos) / maxf(float(pixels), 1.0)}


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)
		push_error(mensagem)


func _executar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 8.0)
	camera.current = true
	mundo.add_child(camera)
	_quadros.append(_adicionar_cartao(mundo, "plana", -2.2))
	_quadros.append(_adicionar_cartao(mundo, "baixo_contraste", 0.0))
	_quadros.append(_adicionar_cartao(mundo, "isoluminante", 2.2))
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var imagem := root.get_texture().get_image()
	var plana := _contar_linhas(imagem, _quadros[0])
	var baixo_contraste := _contar_linhas(imagem, _quadros[1])
	var isoluminante := _contar_linhas(imagem, _quadros[2])
	print("Extração RGB perceptual: plana=%s, baixo_contraste=%s, isoluminante=%s" % [plana, baixo_contraste, isoluminante])
	_verificar(plana.proporcao < 0.005, "Textura uniforme gerou linhas; reduza falso positivo.")
	_verificar(baixo_contraste.proporcao > 0.02, "O padrão escuro de baixo contraste não gerou linhas internas suficientes.")
	_verificar(isoluminante.proporcao > 0.02, "O padrão cromático isoluminante não gerou linhas internas suficientes.")
	if _falhas.is_empty():
		print("OK: extração distingue textura plana, detalhes escuros e bordas cromáticas isoluminantes.")
		quit(0)
	else:
		quit(1)
