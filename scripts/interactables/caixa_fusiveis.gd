class_name CaixaFusiveis
extends Interactable

## Quadro elétrico externo da casa (vinculado à malha existente caixa_de_luz).
## Permite religar a energia durante quedas de fusível e recarregar pontos de vigília.

signal fusivel_religado()
signal luz_vigilia_recarregada()


func _init() -> void:
	_aplicar_configuracao_padrao()


func _ready() -> void:
	inicializar_caixa_fusiveis()


func inicializar_caixa_fusiveis() -> void:
	_aplicar_configuracao_padrao()
	add_to_group("caixas_fusiveis")


func _aplicar_configuracao_padrao() -> void:
	exigir_lanterna_a_noite = true
	exigir_sequencia_direcional = true
	tamanho_sequencia = 4
	tempo_limite_sequencia = 5.5
	if prompt_interacao.is_empty() or prompt_interacao == "Interagir":
		prompt_interacao = "Verificar Caixa de Fusíveis"


func _obter_diretor_eventos() -> DiretorEventosNoite:
	if GameManager.instance != null and GameManager.instance.diretor_eventos_noite is DiretorEventosNoite:
		return GameManager.instance.diretor_eventos_noite as DiretorEventosNoite
	if get_tree() != null:
		for n in get_tree().current_scene.find_children("*", "DiretorEventosNoite", true, false):
			return n as DiretorEventosNoite
	return null


func interagir(jogador: Node3D = null) -> void:
	if not pode_interagir():
		return

	var gerente := GameManager.instance
	var diretor := _obter_diretor_eventos()
	var em_queda := diretor != null and diretor.queda_fusivel_ativa
	var pode_recarregar := gerente != null and gerente.pontos_vigilia_ativos and gerente.recargas_luz_disponiveis > 0

	if not em_queda and not pode_recarregar:
		if gerente != null:
			gerente.status_temporario.emit("Quadro de fusíveis estável.")
		return

	prompt_interacao = "Religar Fusível" if em_queda else "Recarregar Luzes de Vigília"
	super.interagir(jogador)


func _executar_interacao(_jogador: Node3D) -> void:
	var gerente := GameManager.instance
	var diretor := _obter_diretor_eventos()
	if diretor != null and diretor.queda_fusivel_ativa:
		diretor.encerrar_queda_fusivel()
		if gerente != null:
			gerente.status_temporario.emit("Energia da casa restabelecida!")
			if gerente.has_method("registrar_fusivel_religado"):
				gerente.registrar_fusivel_religado()
		fusivel_religado.emit()
		return

	if gerente != null and gerente.recarregar_luz_vigilia():
		luz_vigilia_recarregada.emit()
