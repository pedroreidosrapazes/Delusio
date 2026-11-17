class_name DocumentoLeitura
extends Interactable

## Prop interativo de leitura (Folha / Jornal sobre a mesa).
## Ao interagir, abre o PainelLeituraDocumento com o título, subtítulo e texto configurados.

signal documento_lido(documento_id: StringName, titulo: String)

@export_category("Conteúdo do Documento")
@export var documento_id: StringName = &""
@export var titulo_documento: String = "Documento"
@export var subtitulo_data: String = ""
@export_multiline var texto_conteudo: String = (
	"Anotação preservada sobre a mesa."
)

@export_category("Visual Modular")
@export var visual_scene_override: PackedScene

var lido: bool = false


func _init() -> void:
	exigir_lanterna_a_noite = false
	exigir_sequencia_direcional = false


func _ready() -> void:
	add_to_group("documentos_leitura")
	_aplicar_visual_modular()
	if prompt_interacao == "Interagir" or prompt_interacao.is_empty():
		prompt_interacao = "Ler " + titulo_documento


func _aplicar_visual_modular() -> void:
	if visual_scene_override != null:
		var modelo_antigo := get_node_or_null("Modelo")
		if modelo_antigo != null:
			modelo_antigo.queue_free()
		var inst := visual_scene_override.instantiate()
		inst.name = "Modelo"
		add_child(inst)
		return

	if find_children("*", "MeshInstance3D", true, false).is_empty():
		var placeholder := MeshInstance3D.new()
		placeholder.name = "PlaceholderMesh"
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.02, 0.38)
		placeholder.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.78, 0.68, 1.0)
		placeholder.material_override = mat
		add_child(placeholder)


func _executar_interacao(_jogador: Node3D) -> void:
	lido = true
	var painel := _obter_painel_leitura()
	if painel != null and painel.has_method("abrir"):
		painel.abrir(titulo_documento, texto_conteudo, subtitulo_data)
	elif GameManager.instance != null:
		GameManager.instance.status_temporario.emit(titulo_documento + ": " + texto_conteudo)

	documento_lido.emit(documento_id, titulo_documento)
	if GameManager.instance != null and GameManager.instance.has_method("registrar_documento_lido"):
		GameManager.instance.registrar_documento_lido(documento_id)


func _obter_painel_leitura() -> Control:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("painel_leitura_documento") as Control
