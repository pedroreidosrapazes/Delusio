class_name Esconderijo
extends Interactable

## Esconderijo seguro para se ocultar da Silhueta à noite (Armários, Baús, Folhagens densas).

signal jogador_entrou(player: Player)
signal jogador_saiu(player: Player)

@export_category("Configurações do Esconderijo")
@export var nome_esconderijo: String = "Armário de Madeira"
@export var ponto_olhar: Node3D

var ocupado: bool = false
var jogador_escondido: Player = null
var estabilidade_atual: float = 1.0


func _init() -> void:
	prompt_interacao = "Esconder-se no armário"
	exigir_sequencia_direcional = false
	exigir_lanterna_a_noite = false


func _ready() -> void:
	add_to_group("esconderijos")
	prompt_interacao = "Esconder-se em " + nome_esconderijo


func pode_interagir() -> bool:
	return interacao_ativa


func _executar_interacao(jogador: Node3D) -> void:
	if not (jogador is Player):
		return

	var p := jogador as Player
	if not ocupado:
		entrar(p)
	elif jogador_escondido == p:
		sair(p)


func entrar(player: Player) -> void:
	if ocupado or player == null:
		return

	ocupado = true
	jogador_escondido = player
	prompt_interacao = "Sair de " + nome_esconderijo
	player.entrar_esconderijo(self)

	# Se houver GameManager com medicamentos ativos, ajusta estabilidade
	var gerente := GameManager.instance
	estabilidade_atual = 1.0
	if gerente != null and gerente.gerenciador_medicamentos != null:
		var penalidade := gerente.gerenciador_medicamentos.obter_modificador("instabilidade_esconderijo", 0.0)
		estabilidade_atual = clampf(1.0 - penalidade, 0.20, 1.0)

	jogador_entrou.emit(player)


func sair(player: Player = null) -> void:
	if not ocupado:
		return

	var p := player if player != null else jogador_escondido
	ocupado = false
	prompt_interacao = "Esconder-se em " + nome_esconderijo

	if p != null:
		p.sair_esconderijo()
		jogador_saiu.emit(p)

	jogador_escondido = null


func esta_comprometido(player: Player) -> bool:
	if player == null:
		return false

	# Se a lanterna estiver acesa dentro do esconderijo, a luz vaza e compromete a posição
	if player.esta_com_lanterna_acesa():
		return true

	# Se a Silhueta estiver em investida direta próxima
	var gerente := GameManager.instance
	if gerente != null and gerente.silhueta != null and is_instance_valid(gerente.silhueta):
		var sil := gerente.silhueta
		if ("em_investida" in sil) and sil.em_investida:
			if global_position.distance_to(sil.global_position) < 12.0:
				return true

	return false
