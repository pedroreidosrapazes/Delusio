class_name CercaQuebradaTarefa
extends Interactable

## Tarefa interativa de consertar a cerca quebrada do perímetro usando tábuas do paiol.

@export_category("Configurações da Tarefa")
@export var id_tarefa: String = "consertar_cerca"
@export var nome_exibicao: String = "Consertar a cerca"
@export var item_necessario: StringName = &"tabuas_cerca"
@export var quantidade_necessaria: int = 1

@export_category("Modelos da Cerca")
@export var caminho_modelo_quebrado: NodePath = ^"ModeloQuebrado"
@export var caminho_modelo_consertado: NodePath = ^"ModeloConsertado"

var concluida: bool = false


func _init() -> void:
	exigir_sequencia_direcional = true
	tamanho_sequencia = 5
	tempo_limite_sequencia = 6.5


func _ready() -> void:
	prompt_interacao = nome_exibicao
	add_to_group("tarefas")
	_aplicar_estado_visual(concluida)

	if GameManager.instance and not GameManager.instance.dia_iniciado.is_connected(_ao_iniciar_novo_dia):
		GameManager.instance.dia_iniciado.connect(_ao_iniciar_novo_dia)


func pode_interagir() -> bool:
	return super.pode_interagir() and not concluida


func interagir(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return

	if jogador != null and jogador.has_method("possui_item"):
		if not jogador.possui_item(item_necessario, quantidade_necessaria):
			if GameManager.instance:
				GameManager.instance.status_temporario.emit("Você precisa das Tábuas (no paiol) para consertar a cerca!")
			return

	super.interagir(jogador)


func _executar_interacao(jogador: Node3D) -> void:
	if concluida:
		return

	if jogador != null and jogador.has_method("consumir_item"):
		if not jogador.consumir_item(item_necessario, quantidade_necessaria):
			if GameManager.instance:
				GameManager.instance.status_temporario.emit("Você precisa das Tábuas (no paiol) para consertar a cerca!")
			return

	concluida = true
	interacao_ativa = false
	_aplicar_estado_visual(true)

	var pai_fx: Node = get_parent() if get_parent() != null else self
	BancoAudioDelusio.tocar_3d(pai_fx, &"tarefa_cerca", global_position, -2.0, 18.0)
	FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, &"folhas", global_position + Vector3(0.0, 1.2, 0.0))

	if GameManager.instance:
		GameManager.instance.concluir_tarefa(id_tarefa)
		GameManager.instance.status_temporario.emit("Cerca consertada com as tábuas!")
	else:
		var manager := get_tree().current_scene.get_node_or_null("GameManager")
		if manager and manager.has_method("concluir_tarefa"):
			manager.concluir_tarefa(id_tarefa)


func _aplicar_estado_visual(esta_consertada: bool) -> void:
	var quebrado := get_node_or_null(caminho_modelo_quebrado) as Node3D
	var consertado := get_node_or_null(caminho_modelo_consertado) as Node3D
	if quebrado != null:
		quebrado.visible = not esta_consertada
	if consertado != null:
		consertado.visible = esta_consertada


func _ao_iniciar_novo_dia(_dia: int) -> void:
	concluida = false
	interacao_ativa = true
	_aplicar_estado_visual(false)
