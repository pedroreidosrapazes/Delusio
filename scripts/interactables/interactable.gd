class_name Interactable
extends StaticBody3D

## Classe base para todos os objetos interativos do jogo (Portas, Rádio, Cama, Tarefas).
signal interagiu(jogador: Node3D)

@export_category("Configurações de Interação")
@export var prompt_interacao: String = "Interagir"
@export var interacao_ativa: bool = true

@export_category("Minigame de Sequência Direcional")
@export var exigir_sequencia_direcional: bool = false
@export var tamanho_sequencia: int = 4
@export var tempo_limite_sequencia: float = 6.0
@export var embaralhar_ao_errar: bool = true
@export var reiniciar_tempo_ao_errar: bool = true
@export var tempo_bloqueio_apos_erro: float = 0.22


func pode_interagir() -> bool:
	return interacao_ativa


func obter_config_sequencia() -> Dictionary:
	return {
		"ativo": exigir_sequencia_direcional,
		"tamanho": tamanho_sequencia,
		"tempo_limite": tempo_limite_sequencia,
		"embaralhar_ao_errar": embaralhar_ao_errar,
		"reiniciar_tempo_ao_errar": reiniciar_tempo_ao_errar,
		"tempo_bloqueio_apos_erro": tempo_bloqueio_apos_erro,
		"titulo": prompt_interacao
	}


func interagir(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return

	if exigir_sequencia_direcional and jogador != null and jogador.has_method("iniciar_interacao_sequencia"):
		jogador.iniciar_interacao_sequencia(self)
		return

	concluir_interacao_direta(jogador)


func concluir_interacao_direta(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return
	_executar_interacao(jogador)
	interagiu.emit(jogador)


func _executar_interacao(_jogador: Node3D) -> void:
	pass
