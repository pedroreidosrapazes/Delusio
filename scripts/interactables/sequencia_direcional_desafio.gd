class_name SequenciaDirecionalDesafio
extends RefCounted

## Desafio de sequência direcional para interações do jogador.

enum Direcao {
	CIMA,
	BAIXO,
	ESQUERDA,
	DIREITA
}

signal sequencia_iniciada(sequencia: Array[int], tempo_limite: float, titulo: String)
signal passo_acertado(indice: int, total: int)
signal sequencia_errada(motivo: String, nova_sequencia: Array[int], tempo_restante: float)
signal sequencia_concluida()
signal sequencia_cancelada()
signal tempo_atualizado(restante: float, limite: float)

var ativo: bool = false
var sequencia: Array[int] = []
var indice_atual: int = 0
var tamanho: int = 4
var tempo_limite: float = 6.0
var tempo_restante: float = 6.0
var embaralhar_ao_errar: bool = true
var reiniciar_tempo_ao_errar: bool = true
var tempo_bloqueio_apos_erro: float = 0.22
var bloqueio_restante: float = 0.0
var erros_cometidos: int = 0
var titulo: String = ""


func iniciar(config: Dictionary) -> void:
	tamanho = maxi(1, int(config.get("tamanho", 4)))
	tempo_limite = float(config.get("tempo_limite", 6.0))
	embaralhar_ao_errar = bool(config.get("embaralhar_ao_errar", true))
	reiniciar_tempo_ao_errar = bool(config.get("reiniciar_tempo_ao_errar", true))
	tempo_bloqueio_apos_erro = float(config.get("tempo_bloqueio_apos_erro", 0.22))
	titulo = str(config.get("titulo", ""))

	sequencia = _gerar_sequencia(tamanho, [])
	indice_atual = 0
	erros_cometidos = 0
	bloqueio_restante = 0.0
	tempo_restante = tempo_limite
	ativo = true

	sequencia_iniciada.emit(sequencia, tempo_limite, titulo)
	tempo_atualizado.emit(tempo_restante, tempo_limite)


func processar_delta(delta: float) -> void:
	if not ativo:
		return

	if bloqueio_restante > 0.0:
		bloqueio_restante = maxf(0.0, bloqueio_restante - delta)

	if tempo_limite > 0.0:
		tempo_restante = maxf(0.0, tempo_restante - delta)
		tempo_atualizado.emit(tempo_restante, tempo_limite)
		if tempo_restante <= 0.0:
			_falhar("tempo_esgotado")


func submeter_direcao(dir: int) -> String:
	if not ativo:
		return "inativo"
	if bloqueio_restante > 0.0:
		return "bloqueado"
	if indice_atual >= sequencia.size():
		return "inativo"

	if dir == sequencia[indice_atual]:
		indice_atual += 1
		passo_acertado.emit(indice_atual, sequencia.size())
		if indice_atual >= sequencia.size():
			ativo = false
			sequencia_concluida.emit()
			return "concluida"
		return "acerto"
	else:
		_falhar("tecla_errada")
		return "erro"


func cancelar() -> void:
	if not ativo:
		return
	ativo = false
	bloqueio_restante = 0.0
	sequencia_cancelada.emit()


func _falhar(motivo: String) -> void:
	erros_cometidos += 1
	bloqueio_restante = tempo_bloqueio_apos_erro
	indice_atual = 0
	var anterior := sequencia.duplicate()

	if embaralhar_ao_errar:
		sequencia = _gerar_sequencia(tamanho, anterior)

	if reiniciar_tempo_ao_errar:
		tempo_restante = tempo_limite

	sequencia_errada.emit(motivo, sequencia, tempo_restante)
	tempo_atualizado.emit(tempo_restante, tempo_limite)


func _gerar_sequencia(qtd: int, anterior: Array[int]) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var max_tentativas := 100
	var seq: Array[int] = []

	for _tentativa in range(max_tentativas):
		seq.clear()
		for i in range(qtd):
			var opcoes: Array[int] = [
				Direcao.CIMA,
				Direcao.BAIXO,
				Direcao.ESQUERDA,
				Direcao.DIREITA
			]
			# Evita >= 3 consecutivas iguais
			if i >= 2 and seq[i - 1] == seq[i - 2]:
				opcoes.erase(seq[i - 1])

			var d: int = opcoes[rng.randi_range(0, opcoes.size() - 1)]
			seq.append(d)

		# Evita sequências de 2 ou mais todas iguais
		if qtd >= 2:
			var todos_iguais := true
			for val in seq:
				if val != seq[0]:
					todos_iguais = false
					break
			if todos_iguais:
				continue

		# Garante diferença em relação à sequência anterior
		if anterior.size() == qtd and qtd >= 2:
			var igual_anterior := true
			for k in range(qtd):
				if seq[k] != anterior[k]:
					igual_anterior = false
					break
			if igual_anterior:
				continue

		return seq

	# Fallback determinístico caso o RNG esgote tentativas
	if anterior.size() == qtd and qtd >= 2:
		var fallback := anterior.duplicate()
		fallback[-1] = (fallback[-1] + 1) % 4
		return fallback

	return seq


static func nome_direcao(dir: int) -> String:
	match dir:
		Direcao.CIMA:
			return "Cima"
		Direcao.BAIXO:
			return "Baixo"
		Direcao.ESQUERDA:
			return "Esquerda"
		Direcao.DIREITA:
			return "Direita"
		_:
			return "Desconhecido"
