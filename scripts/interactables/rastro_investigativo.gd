class_name RastroInvestigativo
extends Interactable

## Rastro ou pista física descoberta durante a Vigília Doméstica noturna.
## Possui colisor, brilho reflexivo sutil sob lanterna e encaixe modular para modelo 3D.

signal rastro_inspecionado(rastro_id: StringName, descricao: String)

@export_category("Dados da Pista")
@export var rastro_id: StringName = &"rastro_pegadas"
@export var descricao_pista: String = "Pegadas fundas na terra úmida seguindo em direção à cerca."
@export var visual_scene_override: PackedScene

var inspecionado: bool = false
var _luz_reflexo: OmniLight3D = null


func _init() -> void:
	exigir_lanterna_a_noite = true
	exigir_sequencia_direcional = false
	prompt_interacao = "Inspecionar rastro"


func _ready() -> void:
	add_to_group("rastros_vigilia")
	_garantir_colisor_e_reflexo()
	if visual_scene_override != null and get_node_or_null("Modelo") == null:
		var inst := visual_scene_override.instantiate() as Node3D
		if inst != null:
			inst.name = "Modelo"
			add_child(inst)


func _garantir_colisor_e_reflexo() -> void:
	if find_children("*", "CollisionShape3D", true, false).is_empty():
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sph := SphereShape3D.new()
		sph.radius = 0.65
		col.shape = sph
		col.position = Vector3(0.0, 0.35, 0.0)
		add_child(col)

	_luz_reflexo = get_node_or_null("LuzReflexoRastro") as OmniLight3D
	if _luz_reflexo == null:
		_luz_reflexo = OmniLight3D.new()
		_luz_reflexo.name = "LuzReflexoRastro"
		_luz_reflexo.position = Vector3(0.0, 0.45, 0.0)
		_luz_reflexo.light_color = Color("#c8d6e5")
		_luz_reflexo.light_energy = 0.25
		_luz_reflexo.omni_range = 1.6
		_luz_reflexo.omni_attenuation = 1.4
		_luz_reflexo.shadow_enabled = false
		add_child(_luz_reflexo)


func pode_interagir() -> bool:
	return super.pode_interagir() and not inspecionado


func _executar_interacao(_jogador: Node3D) -> void:
	if inspecionado:
		return
	inspecionado = true
	interacao_ativa = false
	if _luz_reflexo != null:
		_luz_reflexo.visible = false
	for child in find_children("*", "CollisionShape3D", true, false):
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true

	if GameManager.instance != null:
		GameManager.instance.status_temporario.emit(descricao_pista)
		if GameManager.instance.has_method("registrar_rastro_inspecionado"):
			GameManager.instance.registrar_rastro_inspecionado(self)

	rastro_inspecionado.emit(rastro_id, descricao_pista)
