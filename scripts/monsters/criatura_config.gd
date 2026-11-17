class_name CriaturaConfig
extends Resource

## Recurso configurável no Inspector para parâmetros de IA e percepção de monstros noturnos.

enum ModoPresencaRondante {
	CONTINUO = 0,
	PRESSAO_DINAMICA = 1
}

@export_category("Identidade")
@export var nome_criatura: String = "Criatura Noturna"

@export_category("Locomoção")
@export var velocidade_patrulha: float = 2.8
@export var velocidade_perseguicao: float = 5.2

@export_category("Percepção Visual e Sonora")
@export var raio_visao: float = 16.0
@export_range(10.0, 360.0, 1.0) var angulo_visao_graus: float = 110.0
@export var raio_audicao_passos: float = 7.0
@export var raio_audicao_corrida: float = 18.0

@export_category("Comportamento Noturno")
@export var intervalo_min_evento: float = 8.0
@export var sensivel_a_luz: bool = true
@export var tempo_tolerancia_esconderijo: float = 2.5

@export_category("Presença e Ronda Dinâmica")
@export var modo_presenca_rondante: ModoPresencaRondante = ModoPresencaRondante.CONTINUO
@export var limiar_pressao_entrada: float = 100.0
@export var duracao_ronda_min: float = 28.0
@export var duracao_ronda_max: float = 45.0
@export var distancia_min_spawn_jogador: float = 22.0


static func criar_padrao_silhueta() -> CriaturaConfig:
	var cfg := CriaturaConfig.new()
	cfg.nome_criatura = "Silhueta"
	cfg.velocidade_patrulha = 0.0
	cfg.velocidade_perseguicao = 8.0
	cfg.raio_visao = 28.0
	cfg.angulo_visao_graus = 180.0
	cfg.raio_audicao_passos = 4.0
	cfg.raio_audicao_corrida = 12.0
	cfg.intervalo_min_evento = 8.0
	cfg.sensivel_a_luz = true
	cfg.tempo_tolerancia_esconderijo = 1.5
	return cfg


static func criar_padrao_rondante() -> CriaturaConfig:
	var cfg := CriaturaConfig.new()
	cfg.nome_criatura = "Rondante da Fazenda"
	cfg.velocidade_patrulha = 2.8
	cfg.velocidade_perseguicao = 5.2
	cfg.raio_visao = 16.0
	cfg.angulo_visao_graus = 110.0
	cfg.raio_audicao_passos = 7.0
	cfg.raio_audicao_corrida = 18.0
	cfg.intervalo_min_evento = 8.0
	cfg.sensivel_a_luz = true
	cfg.tempo_tolerancia_esconderijo = 2.0
	cfg.modo_presenca_rondante = ModoPresencaRondante.CONTINUO
	return cfg


static func criar_padrao_rondante_pressao() -> CriaturaConfig:
	var cfg := criar_padrao_rondante()
	cfg.modo_presenca_rondante = ModoPresencaRondante.PRESSAO_DINAMICA
	cfg.limiar_pressao_entrada = 100.0
	cfg.duracao_ronda_min = 28.0
	cfg.duracao_ronda_max = 45.0
	cfg.distancia_min_spawn_jogador = 22.0
	return cfg
