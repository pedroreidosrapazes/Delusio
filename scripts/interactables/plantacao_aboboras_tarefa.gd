class_name PlantacaoAboborasTarefa
extends TarefaInterativa

## Tarefa de regar as plantas na plantação de abóboras, ligando a animação de rega por alguns segundos.

@export_category("Referências da Plantação")
@export var caminho_modelo: NodePath = ^".."
@export var nome_animacao_regar: StringName = &"Anim_Regar"
@export var duracao_animacao_regar: float = 5.0

var _token_animacao: int = 0


func _init() -> void:
	super._init()
	id_tarefa = "regar_horta"
	nome_exibicao = "Regar as plantas"


func _ready() -> void:
	super._ready()
	_definir_animacao_regar_ativa(false)

	if GameManager.instance and not GameManager.instance.dia_iniciado.is_connected(_ao_iniciar_novo_dia):
		GameManager.instance.dia_iniciado.connect(_ao_iniciar_novo_dia)


func _executar_interacao(_jogador: Node3D) -> void:
	if concluida:
		print("Você já concluiu esta tarefa hoje: ", nome_exibicao)
		return

	concluida = true
	interacao_ativa = false
	print("Tarefa realizada: ", nome_exibicao)

	for child in find_children("*", "CollisionShape3D"):
		if child is CollisionShape3D:
			child.disabled = true

	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
	else:
		var manager = get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa(id_tarefa)

	_iniciar_animacao_temporaria()


func _iniciar_animacao_temporaria() -> void:
	_token_animacao += 1
	var token_atual := _token_animacao
	_definir_animacao_regar_ativa(true)

	if duracao_animacao_regar <= 0.0 or not is_inside_tree():
		return

	await get_tree().create_timer(duracao_animacao_regar).timeout
	if not is_instance_valid(self) or token_atual != _token_animacao:
		return

	_definir_animacao_regar_ativa(false)


func _ao_iniciar_novo_dia(_dia: int) -> void:
	_token_animacao += 1
	concluida = false
	interacao_ativa = true
	_definir_animacao_regar_ativa(false)

	for child in find_children("*", "CollisionShape3D"):
		if child is CollisionShape3D:
			child.disabled = false


func _definir_animacao_regar_ativa(ativa: bool) -> void:
	var modelo := get_node_or_null(caminho_modelo)
	if modelo == null:
		return

	var rig_agua := modelo.find_child("Rig_Agua_Rega", true, false) as Node3D
	if rig_agua:
		rig_agua.visible = ativa

	var anim_player := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		if ativa and anim_player.has_animation(nome_animacao_regar):
			var anim := anim_player.get_animation(nome_animacao_regar)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(nome_animacao_regar)
		else:
			anim_player.stop()
