class_name Interactable
extends StaticBody3D

## Classe base para todos os objetos interativos do jogo (Portas, Rádio, Cama, Tarefas).
signal interagiu(jogador: Node3D)

@export_category("Configurações de Interação")
@export var prompt_interacao: String = "Interagir"
@export var interacao_ativa: bool = true
@export var exigir_lanterna_a_noite: bool = true

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
	var tempo_base: float = tempo_limite_sequencia
	var bloq_base: float = tempo_bloqueio_apos_erro
	var gerente := GameManager.instance
	if gerente != null and ("gerenciador_medicamentos" in gerente) and gerente.gerenciador_medicamentos != null:
		var bonus_t: float = float(gerente.gerenciador_medicamentos.obter_modificador("bonus_tempo_tarefa", 0.0))
		tempo_base = maxf(1.5, tempo_base + bonus_t)
		var mult_b: float = float(gerente.gerenciador_medicamentos.obter_modificador("mult_bloqueio_erro", 0.0))
		bloq_base = maxf(0.05, bloq_base * (1.0 + mult_b))

	return {
		"ativo": exigir_sequencia_direcional,
		"tamanho": tamanho_sequencia,
		"tempo_limite": tempo_base,
		"embaralhar_ao_errar": embaralhar_ao_errar,
		"reiniciar_tempo_ao_errar": reiniciar_tempo_ao_errar,
		"tempo_bloqueio_apos_erro": bloq_base,
		"titulo": prompt_interacao
	}


func interagir(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return

	if exigir_lanterna_a_noite and jogador is Player:
		var gerente := GameManager.instance
		if gerente != null and gerente.horario_atual == 2:
			var p := jogador as Player
			if not p.esta_com_lanterna_acesa():
				gerente.status_temporario.emit("Está escuro demais! Ligue a lanterna [F] para realizar a tarefa.")
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
