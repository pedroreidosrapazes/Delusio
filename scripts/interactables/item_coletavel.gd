class_name ItemColetavel
extends Interactable

## Script para itens e ferramentas no cenário que o jogador pode pegar.

signal item_coletado(id_item: StringName, quantidade: int)

@export_category("Configurações do Item")
@export var id_item: StringName = &"silver_tape"
@export var quantidade: int = 1
@export var destruir_apos_coleta: bool = true
@export var reaparecer_novo_dia: bool = false

var _particulas_brilho: GPUParticles3D = null
var _coletado_no_dia: bool = false

func _init() -> void:
	exigir_lanterna_a_noite = false
	exigir_sequencia_direcional = false

func _ready() -> void:
	add_to_group("itens_coletaveis")
	if id_item == &"silver_tape":
		reaparecer_novo_dia = true
	if prompt_interacao == "Interagir" or prompt_interacao.is_empty():
		prompt_interacao = "Pegar " + str(id_item).replace("_", " ").capitalize()
	if get_node_or_null("ParticulasBrilhoItem") == null:
		_particulas_brilho = FabricaParticulasDelusio.criar_brilho_item()
		add_child(_particulas_brilho)
	_conectar_gerente_dia()
	call_deferred("_conectar_gerente_dia")


func _conectar_gerente_dia() -> void:
	if GameManager.instance != null and not GameManager.instance.dia_iniciado.is_connected(_ao_iniciar_novo_dia):
		GameManager.instance.dia_iniciado.connect(_ao_iniciar_novo_dia)


func _ao_iniciar_novo_dia(_novo_dia: int) -> void:
	if not reaparecer_novo_dia:
		return
	_coletado_no_dia = false
	interacao_ativa = true
	visible = true
	for child in find_children("*", "CollisionShape3D", true, false):
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false
	if _particulas_brilho != null:
		_particulas_brilho.emitting = true


func _finalizar_estado_coleta() -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	if reaparecer_novo_dia:
		_coletado_no_dia = true
		interacao_ativa = false
		visible = false
		if _particulas_brilho != null:
			_particulas_brilho.emitting = false
	elif destruir_apos_coleta:
		queue_free()


func _executar_interacao(jogador: Node3D) -> void:
	if not pode_interagir() or _coletado_no_dia:
		return

	interacao_ativa = false
	var pai_fx: Node = get_parent() if get_parent() != null else self

	if jogador != null and jogador.has_method("adicionar_item"):
		var restante: int = jogador.adicionar_item(id_item, quantidade)
		if restante < quantidade:
			var coletado: int = quantidade - restante
			print("Item coletado pelo jogador: ", id_item, " x", coletado)
			BancoAudioDelusio.tocar_3d(pai_fx, &"item_coletar", global_position, -2.0, 14.0)
			FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, &"item", global_position)
			item_coletado.emit(id_item, coletado)
			_finalizar_estado_coleta()
		else:
			print("Inventário cheio para o item: ", id_item)
			interacao_ativa = true
	else:
		BancoAudioDelusio.tocar_3d(pai_fx, &"item_coletar", global_position, -2.0, 14.0)
		FabricaParticulasDelusio.disparar_burst_tarefa(pai_fx, &"item", global_position)
		item_coletado.emit(id_item, quantidade)
		_finalizar_estado_coleta()
