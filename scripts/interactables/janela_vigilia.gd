class_name JanelaVigilia
extends Interactable

## Ponto de vigília na janela da casa para espiar o pátio em segurança.

signal vigilia_janela_iniciada(player: Player)
signal vigilia_janela_encerrada(player: Player)
signal ameaca_avistada_pela_janela(monstro: Node3D)

@export_category("Configurações da Janela")
@export var ponto_camera_janela: Marker3D
@export var visual_scene_override: PackedScene
@export var alcance_deteccao_monstros: float = 28.0


func _init() -> void:
	exigir_lanterna_a_noite = false
	exigir_sequencia_direcional = false
	prompt_interacao = "Espiar pela janela"


func _ready() -> void:
	add_to_group("janelas_vigilia")
	if visual_scene_override != null and get_node_or_null("Modelo") == null:
		var inst := visual_scene_override.instantiate() as Node3D
		if inst != null:
			inst.name = "Modelo"
			add_child(inst)
	if find_children("*", "CollisionShape3D", true, false).is_empty():
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 1.5, 0.6)
		col.shape = box
		add_child(col)


func obter_transform_camera() -> Transform3D:
	if ponto_camera_janela != null and is_instance_valid(ponto_camera_janela):
		return ponto_camera_janela.global_transform
	if is_inside_tree():
		return global_transform.looking_at(global_position + Vector3.RIGHT, Vector3.UP)
	return Transform3D.IDENTITY


func _executar_interacao(jogador: Node3D) -> void:
	if not (jogador is Player):
		return
	var p := jogador as Player
	if p.esta_olhando_janela() and p.janela_vigilia_atual == self:
		p.sair_vigilia_janela()
		vigilia_janela_encerrada.emit(p)
	else:
		p.entrar_vigilia_janela(self)
		vigilia_janela_iniciada.emit(p)
		avaliar_ameacas_externas(p)


func notificar_saida_janela(player: Player) -> void:
	vigilia_janela_encerrada.emit(player)


func avaliar_ameacas_externas(player: Player) -> Array[Node3D]:
	var avistados: Array[Node3D] = []
	var gerente := GameManager.instance
	if gerente != null and gerente.has_method("registrar_vigilia_janela"):
		gerente.registrar_vigilia_janela()

	return avistados
