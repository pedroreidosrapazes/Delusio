class_name MonstroNoturnoBase
extends Node3D

## Classe base / contrato comum para todos os monstros noturnos do projeto Delusio.
## Garante registro automático no grupo "monstros_noturnos" e interface padronizada.

signal jogador_capturado(monstro: Node3D, player: Player)
signal estimulo_sonoro_recebido(posicao: Vector3, raio: float)
signal foco_lanterna_recebido(delta: float)

@export var config: CriaturaConfig
@export var distancia_captura: float = 1.6

var ativa: bool = false


func _ready() -> void:
	add_to_group("monstros_noturnos")


func ativar() -> void:
	ativa = true
	visible = true
	set_process(true)


func desativar() -> void:
	ativa = false
	visible = false
	set_process(false)


func receber_estimulo_sonoro(pos: Vector3, raio: float) -> void:
	estimulo_sonoro_recebido.emit(pos, raio)


func receber_foco_lanterna(delta: float) -> void:
	foco_lanterna_recebido.emit(delta)


func _obter_player() -> Player:
	if get_tree() != null:
		return get_tree().get_first_node_in_group("player") as Player
	return null
