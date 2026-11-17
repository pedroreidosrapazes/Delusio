extends Node3D

const Aplicador := preload("res://scripts/visual/estilo_pb/aplicador_estilo_pb.gd")
const CASA_GLB := "res://assets/environment/casa/Casa _final-col.glb"
const TEXTURA_FALLBACK := "res://assets/environment/cenario/Cenario_ideia (1)_oldWoodWhite.webp"
const TEXTURA_RADIO := "res://assets/estilo_pb/radio_atlas_demo_input.png"
const MASCARA_RADIO := "res://assets/estilo_pb/radio_atlas_demo_mask.png"

@export var extrair_linhas_da_textura := false
@export var espessura_contorno := 0.04
@export var velocidade_glow := 0.45

var _aplicador: RefCounted


func _ready() -> void:
	_aplicador = Aplicador.new()
	var item := _obter_mesh_radio_importada()
	if item == null:
		item = _criar_fallback()
	item.name = "Objeto_Demo_Estilo_PB"
	item.rotation.y += PI * 0.5
	add_child(item)
	item.position = Vector3.ZERO
	_aplicador.aplicar(item, {
		"usar_extracao_automatica": extrair_linhas_da_textura,
		"mascara_detalhes": load(MASCARA_RADIO) if ResourceLoader.exists(MASCARA_RADIO) else null,
		"limiar_borda": 0.55,
		"espessura_contorno": espessura_contorno,
		"velocidade_faixa": velocidade_glow,
		"intensidade_faixa": 2.5,
		"intensidade_glow": 1.0,
		"intensidade_rim": 1.0,
		"largura_rim": 0.12,
	})


func _obter_mesh_radio_importada() -> MeshInstance3D:
	if not ResourceLoader.exists(CASA_GLB):
		return null
	var cena := load(CASA_GLB) as PackedScene
	if cena == null:
		return null
	var raiz_importada := cena.instantiate()
	var item := _buscar_mesh(raiz_importada, "Cube_017")
	if item == null:
		raiz_importada.free()
		return null
	var escala_importada := item.scale * 6.4
	item.get_parent().remove_child(item)
	raiz_importada.free()
	item.scale = escala_importada
	return item


func _buscar_mesh(no: Node, nome: String) -> MeshInstance3D:
	if no is MeshInstance3D and no.name.to_lower().replace(".", "_") == nome.to_lower().replace(".", "_"):
		return no as MeshInstance3D
	for filho in no.get_children():
		var achado := _buscar_mesh(filho, nome)
		if achado != null:
			return achado
	return null


func _criar_fallback() -> MeshInstance3D:
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.4, 1.4, 1.4)
	var material := StandardMaterial3D.new()
	var caminho_textura := TEXTURA_RADIO if ResourceLoader.exists(TEXTURA_RADIO) else TEXTURA_FALLBACK
	material.albedo_texture = load(caminho_textura)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	caixa.material = material
	var item := MeshInstance3D.new()
	item.mesh = caixa
	return item
