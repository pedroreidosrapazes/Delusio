class_name RegistroEndless
extends RefCounted

## Persistência local de progresso e recordes do Modo Endless via ConfigFile.

const CAMINHO_PADRAO: String = "user://delusio_endless_save.cfg"
const SECAO: String = "endless"


static func carregar(caminho: String = CAMINHO_PADRAO) -> Dictionary:
	var dados: Dictionary = {
		"recorde_dias": 0,
		"recorde_tarefas": 0,
		"partidas_jogadas": 0
	}
	var cfg := ConfigFile.new()
	if cfg.load(caminho) != OK:
		return dados

	dados["recorde_dias"] = int(cfg.get_value(SECAO, "recorde_dias", 0))
	dados["recorde_tarefas"] = int(cfg.get_value(SECAO, "recorde_tarefas", 0))
	dados["partidas_jogadas"] = int(cfg.get_value(SECAO, "partidas_jogadas", 0))
	return dados


static func registrar_progresso_noite(dias_sobrevividos: int, tarefas_rodada: int, caminho: String = CAMINHO_PADRAO) -> Dictionary:
	return _salvar_registro(dias_sobrevividos, tarefas_rodada, false, caminho)


static func registrar_fim_rodada(dias_sobrevividos: int, tarefas_rodada: int, caminho: String = CAMINHO_PADRAO) -> Dictionary:
	return _salvar_registro(dias_sobrevividos, tarefas_rodada, true, caminho)


static func _salvar_registro(dias_sobrevividos: int, tarefas_rodada: int, incrementar_partidas: bool, caminho: String) -> Dictionary:
	var atual := carregar(caminho)
	var rec_dias_ant: int = int(atual.get("recorde_dias", 0))
	var rec_tar_ant: int = int(atual.get("recorde_tarefas", 0))
	var partidas: int = int(atual.get("partidas_jogadas", 0))

	var novo_recorde: bool = dias_sobrevividos > rec_dias_ant
	var rec_dias: int = maxi(rec_dias_ant, maxi(0, dias_sobrevividos))
	var rec_tarefas: int = maxi(rec_tar_ant, maxi(0, tarefas_rodada))
	if incrementar_partidas:
		partidas += 1

	var cfg := ConfigFile.new()
	cfg.set_value(SECAO, "recorde_dias", rec_dias)
	cfg.set_value(SECAO, "recorde_tarefas", rec_tarefas)
	cfg.set_value(SECAO, "partidas_jogadas", partidas)
	cfg.save(caminho)

	return {
		"novo_recorde": novo_recorde,
		"recorde_dias": rec_dias,
		"recorde_tarefas": rec_tarefas,
		"partidas_jogadas": partidas
	}
