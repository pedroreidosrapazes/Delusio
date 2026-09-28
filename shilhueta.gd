extends Node3D

@export var TEMPO_PARA_SUMIR : float = 0.25
@export var DISTANCIA_MAXIMA_VISAO : float = 30.0

var jogador : Node3D = null
var sumindo : bool = false
var pode_ativar_por_visao : bool = false

@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D
@onready var area_aproximacao: Area3D = $Area3D

func _ready() -> void:
	# Conecta o detector de tela
	if not notifier.screen_entered.is_connected(_on_screen_entered):
		notifier.screen_entered.connect(_on_screen_entered)
	
	# Conecta a detecção física de aproximação
	if area_aproximacao:
		area_aproximacao.body_entered.connect(_on_body_entered)

	# Procura o jogador no grupo
	var jogadores = get_tree().get_nodes_in_group("player")
	if jogadores.size() > 0:
		jogador = jogadores.front()

	await get_tree().create_timer(1.0).timeout
	pode_ativar_por_visao = true

func _on_body_entered(body: Node) -> void:
	# Dispara no exato instante em que o corpo do jogador toca na esfera física
	if body.is_in_group("player") and not sumindo:
		print("Silhueta: Jogador ENTROU na Area3D! Sumindo...")
		sumir_suavemente()

func _on_screen_entered() -> void:
	if pode_ativar_por_visao and not sumindo and jogador != null:
		var distancia := global_position.distance_to(jogador.global_position)
		if distancia <= DISTANCIA_MAXIMA_VISAO:
			print("Silhueta: Vista pela câmera! Sumindo...")
			sumir_suavemente()

func sumir_suavemente() -> void:
	if sumindo:
		return
	sumindo = true
	
	await get_tree().create_timer(TEMPO_PARA_SUMIR).timeout
	queue_free()
