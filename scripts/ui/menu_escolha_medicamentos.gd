class_name MenuEscolhaMedicamentos
extends Control

## Menu de Escolha de Medicamentos ao Acordar.
## Exibe 2 vidros de Petri 3D em acrílico cinza translúcido com física real
## e inclinação independente guiada pelo cursor enquanto o fundo é desfocado.

signal escolha_feita(opcao: int, resultado: Dictionary)

const CENA_PLACA_PETRI := "res://assets/medicamentos_e_placa/PLACA DE PETRI.blend"
const GRUPO_MODAL_CURSOR := "modal_cursor_ui"

const DIAMETRO_PETRI_ALVO := 1.65
const RAZAO_FUNDO_INTERNO_PETRI := 0.206 # 0.0824 / 0.40 medido na malha original do .blend
const MAX_INCLINACAO_RAD := 0.40
const FORCA_ROLAGEM_BASE := 7.5
const TAMANHO_SUBVIEWPORT := Vector2i(360, 270)

var filtro_delusio: FiltroDelusioControlador = null
var gerenciador: GerenciadorMedicamentos = null
var vidros_atuais: Dictionary = {}

var pivo_esq: Node3D = null
var pivo_dir: Node3D = null
var pilulas_rb_esq: Array[RigidBody3D] = []
var pilulas_rb_dir: Array[RigidBody3D] = []

var vp_cont_esq: SubViewportContainer = null
var vp_cont_dir: SubViewportContainer = null
var subviewport_esq: SubViewport = null
var subviewport_dir: SubViewport = null

var label_efeitos_esq: Label = null
var label_efeitos_dir: Label = null
var label_receita: Label = null
var btn_esq: Button = null
var btn_dir: Button = null
var btn_ambos: Button = null

var _cursor_na_janela: bool = true


func _ready() -> void:
	add_to_group(GRUPO_MODAL_CURSOR)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir_interface()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_cursor_na_janela = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_cursor_na_janela = false


func definir_cursor_na_janela(dentro: bool) -> void:
	_cursor_na_janela = dentro


func esta_cursor_na_janela() -> bool:
	return _cursor_na_janela


func _construir_interface() -> void:
	var fundo := ColorRect.new()
	fundo.name = "FundoSemiTransparente"
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.03, 0.035, 0.045, 0.62)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.name = "MargemPrincipal"
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 36)
	margem.add_theme_constant_override("margin_right", 36)
	margem.add_theme_constant_override("margin_top", 28)
	margem.add_theme_constant_override("margin_bottom", 24)
	add_child(margem)

	var vbox_principal := VBoxContainer.new()
	vbox_principal.name = "VBoxPrincipal"
	vbox_principal.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_principal.add_theme_constant_override("separation", 14)
	margem.add_child(vbox_principal)

	# Topo narrativo (inspirado no mockup)
	var label_titulo := Label.new()
	label_titulo.name = "LabelTitulo"
	label_titulo.text = "Qual eu deveria tomar mesmo?"
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.add_theme_font_size_override("font_size", 28)
	label_titulo.add_theme_color_override("font_color", Color("#f0ebe1"))
	vbox_principal.add_child(label_titulo)

	# Centro: 2 vidros 3D em destaque lado a lado, sem bloco largo separando
	var hbox_vidros := HBoxContainer.new()
	hbox_vidros.name = "HBoxVidros"
	hbox_vidros.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_vidros.add_theme_constant_override("separation", 34)
	vbox_principal.add_child(hbox_vidros)

	# --- COLUNA VIDRO ESQUERDO ---
	var coluna_esq := _criar_coluna_vidro(true)
	hbox_vidros.add_child(coluna_esq)

	# --- COLUNA VIDRO DIREITO ---
	var coluna_dir := _criar_coluna_vidro(false)
	hbox_vidros.add_child(coluna_dir)

	# Abaixo e centralizado entre os dois botões: Ambos
	var vbox_ambos := VBoxContainer.new()
	vbox_ambos.name = "VBoxAmbos"
	vbox_ambos.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_ambos.add_theme_constant_override("separation", 4)
	vbox_principal.add_child(vbox_ambos)

	var center_ambos := CenterContainer.new()
	vbox_ambos.add_child(center_ambos)

	btn_ambos = Button.new()
	btn_ambos.name = "BotaoAmbos"
	btn_ambos.text = "Ambos"
	btn_ambos.custom_minimum_size = Vector2(236, 44)
	_estilizar_botao_escolha(btn_ambos, true)
	btn_ambos.pressed.connect(func(): escolher(2))
	center_ambos.add_child(btn_ambos)

	var hint_ambos := Label.new()
	hint_ambos.name = "LabelHintAmbos"
	hint_ambos.text = "High Roller · Aumenta tolerância química"
	hint_ambos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_ambos.add_theme_font_size_override("font_size", 11)
	hint_ambos.add_theme_color_override("font_color", Color("#bba777"))
	vbox_ambos.add_child(hint_ambos)

	# Rodapé discreto para tolerância química & traits ativos
	var center_rodape := CenterContainer.new()
	vbox_principal.add_child(center_rodape)

	label_receita = Label.new()
	label_receita.name = "LabelReceitaRodape"
	label_receita.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_receita.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_receita.custom_minimum_size = Vector2(680, 0)
	label_receita.add_theme_font_size_override("font_size", 12)
	label_receita.add_theme_color_override("font_color", Color("#9fa6b2"))
	center_rodape.add_child(label_receita)


func _criar_coluna_vidro(eh_esquerdo: bool) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxEsquerdo" if eh_esquerdo else "VBoxDireito"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	var vp_cont := SubViewportContainer.new()
	vp_cont.name = "SubViewportContainerEsq" if eh_esquerdo else "SubViewportContainerDir"
	vp_cont.custom_minimum_size = Vector2(TAMANHO_SUBVIEWPORT)
	vp_cont.stretch = true
	vbox.add_child(vp_cont)

	var sv := SubViewport.new()
	sv.name = "SubViewportEsq" if eh_esquerdo else "SubViewportDir"
	sv.size = TAMANHO_SUBVIEWPORT
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	vp_cont.add_child(sv)

	var pivo := _configurar_cenario_3d(sv)

	var label_ef := Label.new()
	label_ef.name = "LabelEfeitosEsq" if eh_esquerdo else "LabelEfeitosDir"
	label_ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_ef.custom_minimum_size = Vector2(340, 56)
	label_ef.add_theme_font_size_override("font_size", 13)
	label_ef.add_theme_color_override("font_color", Color("#d8dde6"))
	vbox.add_child(label_ef)

	var center_btn := CenterContainer.new()
	vbox.add_child(center_btn)

	var btn := Button.new()
	btn.name = "BotaoVidroEsquerdo" if eh_esquerdo else "BotaoVidroDireito"
	btn.text = "Vidro Esquerdo" if eh_esquerdo else "Vidro Direito"
	btn.custom_minimum_size = Vector2(228, 42)
	_estilizar_botao_escolha(btn, false)
	btn.pressed.connect(func(): escolher(0 if eh_esquerdo else 1))
	center_btn.add_child(btn)

	if eh_esquerdo:
		vp_cont_esq = vp_cont
		subviewport_esq = sv
		pivo_esq = pivo
		label_efeitos_esq = label_ef
		btn_esq = btn
	else:
		vp_cont_dir = vp_cont
		subviewport_dir = sv
		pivo_dir = pivo
		label_efeitos_dir = label_ef
		btn_dir = btn

	return vbox


func _estilizar_botao_escolha(btn: Button, destaque: bool) -> void:
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color("#ece6d8") if destaque else Color("#e1e5ec"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#24211b") if destaque else Color("#1b1f26")
	normal.border_color = Color("#8f784b") if destaque else Color("#4b5463")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#312c22") if destaque else Color("#262c36")
	hover.border_color = Color("#bfa269") if destaque else Color("#79869c")

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#17191e")

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)


func _criar_material_acrilico_petri() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.27, 0.31, 0.34)
	mat.roughness = 0.12
	mat.metallic = 0.0
	mat.metallic_specular = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat


func _aplicar_material_acrilico_petri(no_raiz: Node3D) -> void:
	var mat := _criar_material_acrilico_petri()
	for filho in no_raiz.find_children("*", "MeshInstance3D", true, false):
		if filho is MeshInstance3D:
			var mi := filho as MeshInstance3D
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _configurar_cenario_3d(viewport: SubViewport) -> Node3D:
	# WorldEnvironment dedicado (luz ambiente controlada e neutra para preservar as pílulas)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironmentVidro"
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.22, 0.26)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	viewport.add_child(world_env)

	var camera := Camera3D.new()
	camera.name = "CameraVidro"
	camera.fov = 46.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.75, 1.10), Vector3(0.0, 0.06, 0.0), Vector3.UP)

	# Iluminação de estúdio suave: luz principal inclinada + leve luz de contorno
	var luz_principal := DirectionalLight3D.new()
	luz_principal.name = "LuzPrincipalEstudio"
	viewport.add_child(luz_principal)
	luz_principal.look_at_from_position(Vector3(1.8, 2.8, 1.4), Vector3.ZERO, Vector3.UP)
	luz_principal.light_color = Color(0.95, 0.93, 0.89)
	luz_principal.light_energy = 0.82
	luz_principal.shadow_enabled = false

	var luz_contorno := DirectionalLight3D.new()
	luz_contorno.name = "LuzContornoEstudio"
	viewport.add_child(luz_contorno)
	luz_contorno.look_at_from_position(Vector3(-1.8, 1.3, -1.6), Vector3.ZERO, Vector3.UP)
	luz_contorno.light_color = Color(0.66, 0.75, 0.88)
	luz_contorno.light_energy = 0.38
	luz_contorno.shadow_enabled = false

	var pivo := Node3D.new()
	pivo.name = "PivoVidro"
	viewport.add_child(pivo)

	# Corpo cinemático do prato para transmitir inclinação real às cápsulas (irmãs do pivô)
	var prato_corpo := AnimatableBody3D.new()
	prato_corpo.name = "PratoFisico"
	prato_corpo.sync_to_physics = true
	var mat_prato := PhysicsMaterial.new()
	mat_prato.friction = 0.28
	mat_prato.bounce = 0.15
	prato_corpo.physics_material_override = mat_prato

	var altura_fundo_interno := DIAMETRO_PETRI_ALVO * 0.2 * RAZAO_FUNDO_INTERNO_PETRI # ~0.068m

	# Instancia PLACA DE PETRI.blend e aplica material de acrílico cinza translúcido
	var modelo_petri: Node3D = null
	if ResourceLoader.exists(CENA_PLACA_PETRI):
		var cena_placa := load(CENA_PLACA_PETRI) as PackedScene
		if cena_placa != null:
			modelo_petri = cena_placa.instantiate() as Node3D
			if modelo_petri != null:
				var aabb_norm := _normalizar_escala_modelo(modelo_petri, DIAMETRO_PETRI_ALVO, false)
				if aabb_norm.size.y > 0.001:
					altura_fundo_interno = aabb_norm.size.y * RAZAO_FUNDO_INTERNO_PETRI
				_aplicar_material_acrilico_petri(modelo_petri)
				pivo.add_child(modelo_petri)

	if modelo_petri == null:
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = DIAMETRO_PETRI_ALVO * 0.5
		cyl.bottom_radius = DIAMETRO_PETRI_ALVO * 0.5
		cyl.height = 0.08
		mesh_inst.mesh = cyl
		mesh_inst.position.y = 0.04
		mesh_inst.material_override = _criar_material_acrilico_petri()
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivo.add_child(mesh_inst)
		altura_fundo_interno = 0.08

	# Colisão interna alinhada com a face interna do vidro de Petri (pílulas repousam SOBRE ela)
	var base_col := CollisionShape3D.new()
	base_col.name = "ColisaoFundoInterno"
	var shape_cil := CylinderShape3D.new()
	shape_cil.radius = DIAMETRO_PETRI_ALVO * 0.5
	shape_cil.height = 0.08
	base_col.shape = shape_cil
	base_col.position.y = altura_fundo_interno - (shape_cil.height * 0.5)
	prato_corpo.add_child(base_col)

	var num_paredes := 16
	var raio_borda := DIAMETRO_PETRI_ALVO * 0.478
	for i in range(num_paredes):
		var ang := (TAU / float(num_paredes)) * float(i)
		var parede_col := CollisionShape3D.new()
		parede_col.name = "ColisaoParede_%d" % i
		var parede_box := BoxShape3D.new()
		parede_box.size = Vector3(0.36, 0.42, 0.08)
		parede_col.shape = parede_box
		parede_col.position = Vector3(cos(ang) * raio_borda, altura_fundo_interno + 0.17, sin(ang) * raio_borda)
		parede_col.rotation.y = -ang + PI * 0.5
		prato_corpo.add_child(parede_col)

	pivo.add_child(prato_corpo)

	return pivo


func _calcular_aabb_combinada(no_raiz: Node3D) -> AABB:
	var tem_aabb := false
	var aabb_total := AABB()
	for filho in no_raiz.find_children("*", "MeshInstance3D", true, false):
		if not (filho is MeshInstance3D):
			continue
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		var aabb_local := mi.get_aabb()
		var xform := Transform3D.IDENTITY
		var atual: Node = mi
		while atual != null and atual != no_raiz:
			if atual is Node3D:
				xform = (atual as Node3D).transform * xform
			atual = atual.get_parent()
		var p := aabb_local.position
		var s := aabb_local.size
		var cantos: Array[Vector3] = [
			p,
			p + Vector3(s.x, 0.0, 0.0),
			p + Vector3(0.0, s.y, 0.0),
			p + Vector3(0.0, 0.0, s.z),
			p + Vector3(s.x, s.y, 0.0),
			p + Vector3(s.x, 0.0, s.z),
			p + Vector3(0.0, s.y, s.z),
			p + s
		]
		for corner in cantos:
			var pt := xform * corner
			if not tem_aabb:
				aabb_total = AABB(pt, Vector3.ZERO)
				tem_aabb = true
			else:
				aabb_total = aabb_total.expand(pt)
	return aabb_total


func _normalizar_escala_modelo(no_raiz: Node3D, extensao_alvo: float, centralizar_y: bool = true) -> AABB:
	var aabb := _calcular_aabb_combinada(no_raiz)
	var maior_extensao := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if maior_extensao <= 0.0001:
		return AABB()
	var fator := extensao_alvo / maior_extensao
	no_raiz.scale = Vector3.ONE * fator
	var centro := aabb.get_center() * fator
	if centralizar_y:
		no_raiz.position = -centro
	else:
		no_raiz.position = Vector3(-centro.x, -aabb.position.y * fator, -centro.z)
	return AABB(aabb.position * fator, aabb.size * fator)


func _limpar_pilulas(lista_rb: Array[RigidBody3D]) -> void:
	for rb in lista_rb:
		if is_instance_valid(rb):
			rb.queue_free()
	lista_rb.clear()


func _criar_colisao_pilula(tam: Vector3) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var max_xz := maxf(tam.x, tam.z)
	var min_xz := minf(tam.x, tam.z)

	if max_xz >= maxf(min_xz, 0.01) * 1.25:
		var cap := CapsuleShape3D.new()
		var raio := clampf(minf(tam.y, min_xz) * 0.5, 0.055, 0.11)
		cap.radius = raio
		cap.height = maxf(max_xz, raio * 2.0 + 0.01)
		col.shape = cap
		if tam.x >= tam.z:
			col.rotation.z = PI * 0.5
		else:
			col.rotation.x = PI * 0.5
	else:
		var esf := SphereShape3D.new()
		esf.radius = clampf(tam.y * 0.52, 0.065, 0.12)
		col.shape = esf

	return col


func _criar_pilula_3d(id: StringName, pos_mundo_vp: Vector3) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "Pilula_%s" % String(id)
	rb.position = pos_mundo_vp
	rb.continuous_cd = true
	rb.can_sleep = false
	rb.linear_damp = 0.25
	rb.angular_damp = 0.35

	var dados: Dictionary = {}
	if gerenciador != null and gerenciador.CATALOGO.has(id):
		dados = gerenciador.CATALOGO[id]

	rb.mass = float(dados.get("massa", 1.0))
	var mat_fis := PhysicsMaterial.new()
	mat_fis.friction = clampf(float(dados.get("atrito", 0.38)), 0.18, 0.55)
	mat_fis.bounce = 0.22
	rb.physics_material_override = mat_fis

	var modelo_inst: Node3D = null
	var tam_col := Vector3(0.34, 0.15, 0.16)
	var caminho_modelo: String = dados.get("modelo", "")
	if caminho_modelo != "" and ResourceLoader.exists(caminho_modelo):
		var packed := load(caminho_modelo) as PackedScene
		if packed != null:
			modelo_inst = packed.instantiate() as Node3D
			if modelo_inst != null:
				var aabb_norm := _normalizar_escala_modelo(modelo_inst, 0.38, true)
				if aabb_norm.size.length() > 0.001:
					tam_col = aabb_norm.size
				rb.add_child(modelo_inst)

	if modelo_inst == null:
		var fallback_mesh := MeshInstance3D.new()
		if String(id).contains("redondo"):
			var cyl_mesh := CylinderMesh.new()
			cyl_mesh.top_radius = 0.12
			cyl_mesh.bottom_radius = 0.12
			cyl_mesh.height = 0.08
			fallback_mesh.mesh = cyl_mesh
			tam_col = Vector3(0.24, 0.08, 0.24)
		else:
			var cap_mesh := CapsuleMesh.new()
			cap_mesh.radius = 0.08
			cap_mesh.height = 0.30
			fallback_mesh.mesh = cap_mesh
			fallback_mesh.rotation.z = PI * 0.5
			tam_col = Vector3(0.30, 0.16, 0.16)
		var sm := StandardMaterial3D.new()
		if dados.has("cor_placeholder") and dados["cor_placeholder"] is Color:
			sm.albedo_color = dados["cor_placeholder"] as Color
		else:
			sm.albedo_color = Color.WHITE if not dados.get("raro", false) else Color.BLACK
		fallback_mesh.material_override = sm
		rb.add_child(fallback_mesh)

	rb.add_child(_criar_colisao_pilula(tam_col))
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

	if pivo_esq != null:
		pivo_esq.rotation = Vector3.ZERO
	if pivo_dir != null:
		pivo_dir.rotation = Vector3.ZERO
	if subviewport_esq != null:
		subviewport_esq.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	if subviewport_dir != null:
		subviewport_dir.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE

	_popular_vidros()
	_atualizar_textos()

	visible = true
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(1.0, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func fechar() -> void:
	visible = false
	if subviewport_esq != null:
		subviewport_esq.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if subviewport_dir != null:
		subviewport_dir.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if filtro_delusio != null:
		filtro_delusio.definir_desfoque_fundo(0.0, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _popular_vidros() -> void:
	var posicoes := [
		Vector3(-0.24, 0.22, -0.05),
		Vector3(0.24, 0.22, 0.06)
	]

	if subviewport_esq != null:
		_limpar_pilulas(pilulas_rb_esq)
		var lista_esq = vidros_atuais.get("esquerda", [])
		for i in range(mini(lista_esq.size(), posicoes.size())):
			var rb := _criar_pilula_3d(lista_esq[i], posicoes[i])
			rb.rotation.y = -0.35 if i == 0 else 0.45
			subviewport_esq.add_child(rb)
			pilulas_rb_esq.append(rb)

	if subviewport_dir != null:
		_limpar_pilulas(pilulas_rb_dir)
		var lista_dir = vidros_atuais.get("direita", [])
		for i in range(mini(lista_dir.size(), posicoes.size())):
			var rb := _criar_pilula_3d(lista_dir[i], posicoes[i])
			rb.rotation.y = 0.40 if i == 0 else -0.30
			subviewport_dir.add_child(rb)
			pilulas_rb_dir.append(rb)


func _gerar_texto_efeitos(ids: Array) -> String:
	var linhas: Array[String] = []
	for id in ids:
		if gerenciador != null and gerenciador.CATALOGO.has(id):
			var dados = gerenciador.CATALOGO[id]
			linhas.append("• +" + String(dados.get("buff", "")) + "  |  -" + String(dados.get("debuff", "")))
	return "\n".join(linhas)


func _atualizar_textos() -> void:
	if label_efeitos_esq:
		label_efeitos_esq.text = _gerar_texto_efeitos(vidros_atuais.get("esquerda", []))
	if label_efeitos_dir:
		label_efeitos_dir.text = _gerar_texto_efeitos(vidros_atuais.get("direita", []))

	if label_receita and gerenciador:
		var nivel_hr := "+".repeat(mini(gerenciador.streak_high_roller, 5)) if gerenciador.streak_high_roller > 0 else "Nenhuma"
		var partes: Array[String] = ["Tolerância Química: " + nivel_hr]
		if not gerenciador.traits_ativos.is_empty():
			var nomes_traits: Array[String] = []
			for t_id in gerenciador.traits_ativos:
				if gerenciador.TRAITS_CATALOGO.has(t_id):
					nomes_traits.append(String(gerenciador.TRAITS_CATALOGO[t_id]["nome"]))
			if not nomes_traits.is_empty():
				partes.append("Traits: " + ", ".join(nomes_traits))
		label_receita.text = "  ·  ".join(partes)


static func calcular_norm_relativo_ao_centro(pos_mouse_px: Vector2, rect_cont: Rect2) -> Vector2:
	if rect_cont.size.x <= 0.0 or rect_cont.size.y <= 0.0:
		return Vector2.ZERO
	var centro := rect_cont.get_center()
	var raio_sens := maxf(rect_cont.size.x, rect_cont.size.y) * 0.65
	var delta_px := (pos_mouse_px - centro) / maxf(raio_sens, 1.0)
	return Vector2(clampf(delta_px.x, -1.0, 1.0), clampf(delta_px.y, -1.0, 1.0))


func _aplicar_inclinacao_no_pivo(pivo: Node3D, lista_rb: Array[RigidBody3D], pos_norm: Vector2, delta: float) -> void:
	if pivo == null:
		return
	# Parte mais baixa do vidro acompanha o cursor:
	# Direita (+x) -> rotation.z < 0; Esquerda (-x) -> rotation.z > 0
	# Baixo (+y) -> rotation.x > 0; Cima (-y) -> rotation.x < 0
	var alvo_x := clampf(pos_norm.y * MAX_INCLINACAO_RAD, -MAX_INCLINACAO_RAD, MAX_INCLINACAO_RAD)
	var alvo_z := clampf(-pos_norm.x * MAX_INCLINACAO_RAD, -MAX_INCLINACAO_RAD, MAX_INCLINACAO_RAD)
	var peso := clampf(delta * 8.5, 0.0, 1.0)

	pivo.rotation.x = lerpf(pivo.rotation.x, alvo_x, peso)
	pivo.rotation.z = lerpf(pivo.rotation.z, alvo_z, peso)

	var forca := Vector3(-pivo.rotation.z * FORCA_ROLAGEM_BASE, 0.0, pivo.rotation.x * FORCA_ROLAGEM_BASE)
	for rb in lista_rb:
		if is_instance_valid(rb):
			rb.sleeping = false
			rb.apply_central_force(forca)


func atualizar_inclinacao_por_cursor_tela(pos_mouse_px: Vector2, cursor_valido: bool, delta: float) -> void:
	var norm_esq := Vector2.ZERO
	var norm_dir := Vector2.ZERO
	if cursor_valido and _cursor_na_janela:
		if vp_cont_esq != null:
			norm_esq = calcular_norm_relativo_ao_centro(pos_mouse_px, vp_cont_esq.get_global_rect())
		if vp_cont_dir != null:
			norm_dir = calcular_norm_relativo_ao_centro(pos_mouse_px, vp_cont_dir.get_global_rect())

	_aplicar_inclinacao_no_pivo(pivo_esq, pilulas_rb_esq, norm_esq, delta)
	_aplicar_inclinacao_no_pivo(pivo_dir, pilulas_rb_dir, norm_dir, delta)


func atualizar_inclinacao_mouse(pos_mouse_norm: Vector2, delta: float) -> void:
	_aplicar_inclinacao_no_pivo(pivo_esq, pilulas_rb_esq, pos_mouse_norm, delta)
	_aplicar_inclinacao_no_pivo(pivo_dir, pilulas_rb_dir, pos_mouse_norm, delta)


func _process(delta: float) -> void:
	if not visible:
		return

	var vp_rect := get_viewport_rect()
	var m_pos := get_viewport().get_mouse_position()
	var cursor_valido := _cursor_na_janela and vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0 and vp_rect.has_point(m_pos)
	atualizar_inclinacao_por_cursor_tela(m_pos, cursor_valido, delta)


func escolher(opcao: int) -> Dictionary:
	var resultado: Dictionary = {}
	if gerenciador != null:
		resultado = gerenciador.aplicar_escolha(opcao, vidros_atuais)

	BancoAudioDelusio.tocar_2d(self, &"pilula_consumir", -3.0, 0.04)
	escolha_feita.emit(opcao, resultado)
	fechar()
	return resultado
