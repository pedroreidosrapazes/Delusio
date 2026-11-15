class_name MenuEscolhaMedicamentos
extends Control

## Menu de Escolha de Medicamentos ao Acordar.
## Exibe 2 vidros de Petri 3D nítidos no HUD com física interativa de mouse
## enquanto o cenário ao fundo é desfocado pelo Filtro Delusio.

signal escolha_feita(opcao: int, resultado: Dictionary)

const CENA_PLACA_PETRI := "res://assets/medicamentos e placa/PLACA DE PETRI.blend"

var filtro_delusio: FiltroDelusioControlador = null
var gerenciador: GerenciadorMedicamentos = null
var vidros_atuais: Dictionary = {}

var pivo_esq: Node3D = null
var pivo_dir: Node3D = null
var pilulas_rb_esq: Array[RigidBody3D] = []
var pilulas_rb_dir: Array[RigidBody3D] = []

var subviewport_esq: SubViewport = null
var subviewport_dir: SubViewport = null

var label_efeitos_esq: Label = null
var label_efeitos_dir: Label = null
var label_receita: Label = null
var btn_esq: Button = null
var btn_dir: Button = null
var btn_ambos: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir_interface()


func _construir_interface() -> void:
	# Fundo semi-transparente escuro para realçar as caixas nítidas
	var fundo := ColorRect.new()
	fundo.name = "FundoSemiTransparente"
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.04, 0.05, 0.07, 0.55)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# Container Principal Vertical
	var vbox_principal := VBoxContainer.new()
	vbox_principal.name = "VBoxPrincipal"
	vbox_principal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox_principal.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_principal.add_theme_constant_override("separation", 16)
	add_child(vbox_principal)

	# Título do Menu
	var label_titulo := Label.new()
	label_titulo.text = "DESPERTAR - ESCOLHA DE MEDICAMENTOS"
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.add_theme_font_size_override("font_size", 22)
	label_titulo.add_theme_color_override("font_color", Color("#ffe3a8"))
	vbox_principal.add_child(label_titulo)

	# HBox dos Vidros 3D e Opções
	var hbox_vidros := HBoxContainer.new()
	hbox_vidros.name = "HBoxVidros"
	hbox_vidros.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_vidros.add_theme_constant_override("separation", 36)
	vbox_principal.add_child(hbox_vidros)

	# --- PAINEL ESQUERDO ---
	var vbox_esq := VBoxContainer.new()
	vbox_esq.custom_minimum_size = Vector2(320, 360)
	vbox_esq.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_vidros.add_child(vbox_esq)

	var vp_cont_esq := SubViewportContainer.new()
	vp_cont_esq.custom_minimum_size = Vector2(300, 220)
	vp_cont_esq.stretch = true
	vbox_esq.add_child(vp_cont_esq)

	subviewport_esq = SubViewport.new()
	subviewport_esq.size = Vector2i(300, 220)
	subviewport_esq.own_world_3d = true
	subviewport_esq.transparent_bg = true
	subviewport_esq.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_cont_esq.add_child(subviewport_esq)

	pivo_esq = _configurar_cenario_3d(subviewport_esq)

	label_efeitos_esq = Label.new()
	label_efeitos_esq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_efeitos_esq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_efeitos_esq.add_theme_font_size_override("font_size", 13)
	vbox_esq.add_child(label_efeitos_esq)

	btn_esq = Button.new()
	btn_esq.text = "Tomar Vidro Esquerdo"
	btn_esq.custom_minimum_size = Vector2(240, 36)
	btn_esq.pressed.connect(func(): escolher(0))
	vbox_esq.add_child(btn_esq)

	# --- PAINEL CENTRAL (RECEITA & HIGH ROLLER) ---
	var vbox_centro := VBoxContainer.new()
	vbox_centro.custom_minimum_size = Vector2(280, 360)
	vbox_centro.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_centro.add_theme_constant_override("separation", 14)
	hbox_vidros.add_child(vbox_centro)

	var panel_receita := PanelContainer.new()
	panel_receita.custom_minimum_size = Vector2(260, 180)
	vbox_centro.add_child(panel_receita)

	var vbox_rec := VBoxContainer.new()
	panel_receita.add_child(vbox_rec)

	var label_rec_tit := Label.new()
	label_rec_tit.text = "Receita Médica & Traits"
	label_rec_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_rec_tit.add_theme_font_size_override("font_size", 14)
	label_rec_tit.add_theme_color_override("font_color", Color("#e6c875"))
	vbox_rec.add_child(label_rec_tit)

	label_receita = Label.new()
	label_receita.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_receita.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_receita.add_theme_font_size_override("font_size", 12)
	vbox_rec.add_child(label_receita)

	btn_ambos = Button.new()
	btn_ambos.text = "Tomar Ambos os Vidros\n[High Roller]"
	btn_ambos.custom_minimum_size = Vector2(240, 48)
	btn_ambos.pressed.connect(func(): escolher(2))
	vbox_centro.add_child(btn_ambos)

	# --- PAINEL DIREITO ---
	var vbox_dir := VBoxContainer.new()
	vbox_dir.custom_minimum_size = Vector2(320, 360)
	vbox_dir.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_vidros.add_child(vbox_dir)

	var vp_cont_dir := SubViewportContainer.new()
	vp_cont_dir.custom_minimum_size = Vector2(300, 220)
	vp_cont_dir.stretch = true
	vbox_dir.add_child(vp_cont_dir)

	subviewport_dir = SubViewport.new()
	subviewport_dir.size = Vector2i(300, 220)
	subviewport_dir.own_world_3d = true
	subviewport_dir.transparent_bg = true
	subviewport_dir.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_cont_dir.add_child(subviewport_dir)

	pivo_dir = _configurar_cenario_3d(subviewport_dir)

	label_efeitos_dir = Label.new()
	label_efeitos_dir.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_efeitos_dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_efeitos_dir.add_theme_font_size_override("font_size", 13)
	vbox_dir.add_child(label_efeitos_dir)

	btn_dir = Button.new()
	btn_dir.text = "Tomar Vidro Direito"
	btn_dir.custom_minimum_size = Vector2(240, 36)
	btn_dir.pressed.connect(func(): escolher(1))
	vbox_dir.add_child(btn_dir)


func _configurar_cenario_3d(viewport: SubViewport) -> Node3D:
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.8, 1.3), Vector3.ZERO, Vector3.UP)

	var luz := DirectionalLight3D.new()
	viewport.add_child(luz)
	luz.look_at_from_position(Vector3(1.0, 3.0, 2.0), Vector3.ZERO, Vector3.UP)
	luz.light_color = Color("#fff4e0")
	luz.light_energy = 1.2

	var pivo := Node3D.new()
	pivo.name = "PivoVidro"
	viewport.add_child(pivo)

	# Tenta carregar modelo da Placa de Petri
	var modelo_petri: Node3D = null
	if ResourceLoader.exists(CENA_PLACA_PETRI):
		var cena_placa := load(CENA_PLACA_PETRI) as PackedScene
		if cena_placa != null:
			modelo_petri = cena_placa.instantiate() as Node3D
			if modelo_petri != null:
				_normalizar_escala_modelo(modelo_petri, 1.55)
				pivo.add_child(modelo_petri)

	if modelo_petri == null:
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.8
		cyl.bottom_radius = 0.8
		cyl.height = 0.12
		mesh_inst.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.90, 0.95, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mesh_inst.material_override = mat
		pivo.add_child(mesh_inst)

	# Colisão da base e bordas cilíndricas para conter os RigidBodies dentro do vidro
	var base_corpo := StaticBody3D.new()
	var base_col := CollisionShape3D.new()
	var shape_cil := CylinderShape3D.new()
	shape_cil.radius = 0.85
	shape_cil.height = 0.1
	base_col.shape = shape_cil
	base_col.position.y = -0.05
	base_corpo.add_child(base_col)

	var num_paredes := 12
	var raio_borda := 0.78
	for i in range(num_paredes):
		var ang := (TAU / float(num_paredes)) * float(i)
		var parede_col := CollisionShape3D.new()
		var parede_box := BoxShape3D.new()
		parede_box.size = Vector3(0.48, 0.45, 0.08)
		parede_col.shape = parede_box
		parede_col.position = Vector3(cos(ang) * raio_borda, 0.18, sin(ang) * raio_borda)
		parede_col.rotation.y = -ang + PI * 0.5
		base_corpo.add_child(parede_col)

	pivo.add_child(base_corpo)

	return pivo


func _normalizar_escala_modelo(no_raiz: Node3D, diametro_alvo: float) -> void:
	var maior_extensao := 0.0
	for filho in no_raiz.find_children("*", "MeshInstance3D", true, false):
		if filho is MeshInstance3D and (filho as MeshInstance3D).mesh != null:
			var aabb := (filho as MeshInstance3D).get_aabb()
			var tam := aabb.size * (filho as Node3D).scale
			maior_extensao = maxf(maior_extensao, maxf(tam.x, maxf(tam.y, tam.z)))
	if maior_extensao > 0.0001:
		var fator := diametro_alvo / maior_extensao
		no_raiz.scale = Vector3.ONE * fator


func _limpar_pilulas_pivo(pivo: Node3D, lista_rb: Array[RigidBody3D]) -> void:
	for rb in lista_rb:
		if is_instance_valid(rb):
			rb.queue_free()
	lista_rb.clear()


func _criar_pilula_3d(id: StringName, pos_local: Vector3) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.position = pos_local

	var dados: Dictionary = {}
	if gerenciador != null and gerenciador.CATALOGO.has(id):
		dados = gerenciador.CATALOGO[id]

	rb.mass = float(dados.get("massa", 1.0))
	var mat_fis := PhysicsMaterial.new()
	mat_fis.friction = float(dados.get("atrito", 0.5))
	mat_fis.bounce = 0.15
	rb.physics_material_override = mat_fis

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.12, 0.35)
	col.shape = box
	rb.add_child(col)

	var modelo_inst: Node3D = null
	var caminho_modelo: String = dados.get("modelo", "")
	if caminho_modelo != "" and ResourceLoader.exists(caminho_modelo):
		var packed := load(caminho_modelo) as PackedScene
		if packed != null:
			modelo_inst = packed.instantiate() as Node3D
			if modelo_inst != null:
				_normalizar_escala_modelo(modelo_inst, 0.34)
				rb.add_child(modelo_inst)

	if modelo_inst == null:
		var fallback_mesh := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.08
		cap.height = 0.28
		fallback_mesh.mesh = cap
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color.WHITE if not dados.get("raro", false) else Color.BLACK
		fallback_mesh.material_override = sm
		rb.add_child(fallback_mesh)

	return rb


func abrir(vidros: Dictionary = {}) -> void:
	if gerenciador == null:
		var gerente := GameManager.instance
		if gerente != null:
			gerenciador = gerente.gerenciador_medicamentos

	if vidros.is_empty():
		if gerenciador != null:
			vidros_atuais = gerenciador.sortear_vidros_manha()
	else:
		vidros_atuais = vidros.duplicate(true)

	_popular_vidros()
	_atualizar_textos()

	visible = true
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(1.0, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func fechar() -> void:
	visible = false
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(0.0, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _popular_vidros() -> void:
	if pivo_esq:
		_limpar_pilulas_pivo(pivo_esq, pilulas_rb_esq)
		var lista_esq = vidros_atuais.get("esquerda", [])
		var posicoes := [Vector3(-0.25, 0.08, 0.0), Vector3(0.25, 0.08, 0.0)]
		for i in range(mini(lista_esq.size(), posicoes.size())):
			var rb := _criar_pilula_3d(lista_esq[i], posicoes[i])
			pivo_esq.add_child(rb)
			pilulas_rb_esq.append(rb)

	if pivo_dir:
		_limpar_pilulas_pivo(pivo_dir, pilulas_rb_dir)
		var lista_dir = vidros_atuais.get("direita", [])
		var posicoes := [Vector3(-0.25, 0.08, 0.0), Vector3(0.25, 0.08, 0.0)]
		for i in range(mini(lista_dir.size(), posicoes.size())):
			var rb := _criar_pilula_3d(lista_dir[i], posicoes[i])
			pivo_dir.add_child(rb)
			pilulas_rb_dir.append(rb)


func _gerar_texto_efeitos(ids: Array) -> String:
	var linhas: Array[String] = []
	for id in ids:
		if gerenciador != null and gerenciador.CATALOGO.has(id):
			var dados = gerenciador.CATALOGO[id]
			linhas.append("• " + String(dados.get("nome", "Comprimido")))
			linhas.append("  [+] " + String(dados.get("buff", "")))
			linhas.append("  [-] " + String(dados.get("debuff", "")))
	return "\n".join(linhas)


func _atualizar_textos() -> void:
	if label_efeitos_esq:
		label_efeitos_esq.text = _gerar_texto_efeitos(vidros_atuais.get("esquerda", []))
	if label_efeitos_dir:
		label_efeitos_dir.text = _gerar_texto_efeitos(vidros_atuais.get("direita", []))

	if label_receita and gerenciador:
		var nivel_hr := "+".repeat(mini(gerenciador.streak_high_roller, 5)) if gerenciador.streak_high_roller > 0 else "Nenhuma"
		var texto_rec := "Tolerância Química: " + nivel_hr + "\n\n"
		if gerenciador.traits_ativos.is_empty():
			texto_rec += "Nenhum trait ativo.\n(Arrisque ambos os vidros para desbloquear)"
		else:
			texto_rec += "Traits Ativos:\n"
			for t_id in gerenciador.traits_ativos:
				if gerenciador.TRAITS_CATALOGO.has(t_id):
					var dt = gerenciador.TRAITS_CATALOGO[t_id]
					texto_rec += "• " + dt["nome"] + "\n  " + dt["descricao"] + "\n"
		label_receita.text = texto_rec


func atualizar_inclinacao_mouse(pos_mouse_norm: Vector2, delta: float) -> void:
	var alvo_x := clampf(-pos_mouse_norm.y * 0.42, -0.42, 0.42)
	var alvo_z := clampf(pos_mouse_norm.x * 0.42, -0.42, 0.42)

	if pivo_esq != null:
		pivo_esq.rotation.x = lerpf(pivo_esq.rotation.x, alvo_x, clampf(delta * 8.0, 0.0, 1.0))
		pivo_esq.rotation.z = lerpf(pivo_esq.rotation.z, alvo_z, clampf(delta * 8.0, 0.0, 1.0))
	if pivo_dir != null:
		pivo_dir.rotation.x = lerpf(pivo_dir.rotation.x, alvo_x, clampf(delta * 8.0, 0.0, 1.0))
		pivo_dir.rotation.z = lerpf(pivo_dir.rotation.z, alvo_z, clampf(delta * 8.0, 0.0, 1.0))

	var forca := Vector3(alvo_z * 6.0, 0.0, -alvo_x * 6.0)
	for rb in pilulas_rb_esq:
		if is_instance_valid(rb):
			rb.sleeping = false
			rb.apply_central_force(forca)
	for rb in pilulas_rb_dir:
		if is_instance_valid(rb):
			rb.sleeping = false
			rb.apply_central_force(forca)


func _process(delta: float) -> void:
	if not visible:
		return

	var vp_size := get_viewport_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		var m_pos := get_viewport().get_mouse_position()
		var norm_x := clampf((m_pos.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
		var norm_y := clampf((m_pos.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)
		atualizar_inclinacao_mouse(Vector2(norm_x, norm_y), delta)


func escolher(opcao: int) -> Dictionary:
	var resultado: Dictionary = {}
	if gerenciador != null:
		resultado = gerenciador.aplicar_escolha(opcao, vidros_atuais)

	escolha_feita.emit(opcao, resultado)
	fechar()
	return resultado
