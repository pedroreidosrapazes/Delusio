class_name PontoRonda
extends Marker3D

## Marcador modular e agnóstico ao mapa para o Rondante.
## Pode ser posicionado em qualquer cenário futuro (Celeiro, Silo, Casa, Cerca, Mata)
## para definir rotas de patrulha, quinas de wall-peek e entradas/saídas de ronda.

enum TipoPonto {
	PATRULHA = 0,
	WALL_PEEK = 1,
	ENTRADA_SAIDA = 2,
	INTERESSE = 3
}

@export var tipo_ponto: TipoPonto = TipoPonto.PATRULHA
@export var zona_nome: String = "geral"
@export var tempo_espreita: float = 2.5
@export var peso_prioridade: float = 1.0
@export var ativo: bool = true


func _ready() -> void:
	add_to_group("pontos_ronda")
	match tipo_ponto:
		TipoPonto.PATRULHA:
			add_to_group("pontos_patrulha")
		TipoPonto.WALL_PEEK:
			add_to_group("pontos_wall_peek")
		TipoPonto.ENTRADA_SAIDA:
			add_to_group("pontos_entrada_saida_rondante")
		TipoPonto.INTERESSE:
			add_to_group("pontos_interesse_rondante")
			add_to_group("pontos_patrulha")


func obter_direcao_espreita() -> Vector3:
	var frente := -global_transform.basis.z
	var xz := Vector3(frente.x, 0.0, frente.z)
	if xz.length_squared() < 0.0001:
		return Vector3.FORWARD
	return xz.normalized()
