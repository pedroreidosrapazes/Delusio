class_name GerenciadorMedicamentos
extends Node

## Gerenciador do catálogo de medicamentos, loot tables e traits High-Roller.

signal escolha_aplicada(opcao: int, resultado: Dictionary)
signal trait_desbloqueado(trait_id: StringName, dados: Dictionary)

const CATALOGO: Dictionary = {
	&"med_1_oval": {
		"id": &"med_1_oval",
		"nome": "Comprimido Oval Laranja",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 1 - OVAL.blend",
		"buff": "Velocidade de caminhada +",
		"debuff": "Tensão noturna -",
		"massa": 1.0,
		"atrito": 0.45,
		"raro": false,
		"mods": {"mult_vel_andar": 0.08, "offset_tensao_noite": 0.08}
	},
	&"med_1_oval_quebrado": {
		"id": &"med_1_oval_quebrado",
		"nome": "Comprimido Oval Partido",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 1 - OVAL QUEBRADO.blend",
		"buff": "Velocidade de caminhada +",
		"debuff": "Estabilidade no esconderijo --",
		"massa": 0.7,
		"atrito": 0.65,
		"raro": false,
		"mods": {"mult_vel_andar": 0.06, "instabilidade_esconderijo": 0.25}
	},
	&"med_1_pilula": {
		"id": &"med_1_pilula",
		"nome": "Cápsula Bicolor Vermelha",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 1 - PÍLULA.blend",
		"buff": "Velocidade de caminhada ++",
		"debuff": "Duração do dia --",
		"massa": 0.55,
		"atrito": 0.30,
		"raro": false,
		"mods": {"mult_vel_andar": 0.14, "mult_tempo_dia": -0.15}
	},
	&"med_1_redondo": {
		"id": &"med_1_redondo",
		"nome": "Drágea Amarela",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 1 - REDONDO.blend",
		"buff": "Fôlego de corrida +",
		"debuff": "Alcance da lanterna -",
		"massa": 1.1,
		"atrito": 0.50,
		"raro": false,
		"mods": {"mult_vel_correr": 0.10, "mult_alcance_lanterna": -0.12}
	},
	&"med_2_oval": {
		"id": &"med_2_oval",
		"nome": "Comprimido Oval Azul Claro",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 2 - OVAL.blend",
		"buff": "Tempo nas tarefas +",
		"debuff": "Velocidade de caminhada -",
		"massa": 1.3,
		"atrito": 0.55,
		"raro": false,
		"mods": {"bonus_tempo_tarefa": 0.8, "mult_vel_andar": -0.06}
	},
	&"med_2_oval_quebrado": {
		"id": &"med_2_oval_quebrado",
		"nome": "Comprimido Oval Azul Partido",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 2 - OVAL QUEBRADO.blend",
		"buff": "Tempo nas tarefas +",
		"debuff": "Calma ao errar tarefa --",
		"massa": 0.85,
		"atrito": 0.70,
		"raro": false,
		"mods": {"bonus_tempo_tarefa": 0.6, "mult_impulso_erro": 0.35}
	},
	&"med_2_pilula": {
		"id": &"med_2_pilula",
		"nome": "Cápsula Bicolor Azul",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 2 - PÍLULA.blend",
		"buff": "Tempo nas tarefas ++",
		"debuff": "Discrição da lanterna --",
		"massa": 0.60,
		"atrito": 0.32,
		"raro": false,
		"mods": {"bonus_tempo_tarefa": 1.4, "mult_atracao_lanterna": 0.30}
	},
	&"med_2_redondo": {
		"id": &"med_2_redondo",
		"nome": "Drágea Azul Escura",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 2 - REDONDO.blend",
		"buff": "Recuperação de erro nas tarefas +",
		"debuff": "Visão periférica -",
		"massa": 1.25,
		"atrito": 0.52,
		"raro": false,
		"mods": {"mult_bloqueio_erro": -0.35, "offset_tensao_base": 0.06}
	},
	&"med_3_oval": {
		"id": &"med_3_oval",
		"nome": "Comprimido Oval Verde",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 3 - OVAL.blend",
		"buff": "Calma na escuridão +",
		"debuff": "Agilidade nas tarefas -",
		"massa": 1.4,
		"atrito": 0.60,
		"raro": false,
		"mods": {"resistencia_escuridao": 0.30, "bonus_tempo_tarefa": -0.4}
	},
	&"med_3_oval_quebrado": {
		"id": &"med_3_oval_quebrado",
		"nome": "Comprimido Oval Verde Partido",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 3 - OVAL QUEBRADO.blend",
		"buff": "Calma na escuridão +",
		"debuff": "Passos silenciosos --",
		"massa": 0.9,
		"atrito": 0.75,
		"raro": false,
		"mods": {"resistencia_escuridao": 0.25, "ruido_movimento": 0.30}
	},
	&"med_3_pilula": {
		"id": &"med_3_pilula",
		"nome": "Cápsula Bicolor Verde",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 3 - PÍLULA.blend",
		"buff": "Duração do dia ++",
		"debuff": "Calma da Silhueta à noite --",
		"massa": 0.65,
		"atrito": 0.35,
		"raro": false,
		"mods": {"mult_tempo_dia": 0.20, "agressividade_silhueta": 0.25}
	},
	&"med_3_redondo": {
		"id": &"med_3_redondo",
		"nome": "Drágea Verde de Adrenalina",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 3 - REDONDO.blend",
		"cor_placeholder": Color("#3a9c5a"),
		"buff": "Sobrevive a uma captura +",
		"debuff": "Tensão noturna --",
		"massa": 1.15,
		"atrito": 0.48,
		"raro": false,
		"mods": {"segunda_chance_captura": 1.0, "offset_tensao_noite": 0.14}
	},
	&"med_4_oval": {
		"id": &"med_4_oval",
		"nome": "Comprimido Preto Selado",
		"modelo": "res://assets/medicamentos_e_placa/MEDICAMENTO 4 - OVAL.blend",
		"buff": "Tarefas do dia resolvidas +++",
		"debuff": "Assombração noturna ---",
		"massa": 1.8,
		"atrito": 0.40,
		"raro": true,
		"mods": {"resolver_dia_imediato": true, "agressividade_silhueta": 0.60, "recargas_noturnas_extras": 2}
	}
}

const TRAITS_CATALOGO: Dictionary = {
	&"olhos_de_coruja": {
		"id": &"olhos_de_coruja",
		"nome": "Olhos de Coruja",
		"descricao": "Visão aguçada na penumbra + / Sensibilidade à luz da lanterna -",
		"mods": {"alcance_visao_noite": 0.30, "sensibilidade_luz": 0.20}
	},
	&"adrenalina_cronica": {
		"id": &"adrenalina_cronica",
		"nome": "Adrenalina Crônica",
		"descricao": "Velocidade em perigo ++ / Pânico sob perseguição --",
		"mods": {"mult_vel_perigo": 0.20, "aceleracao_tensao": 0.30}
	},
	&"dependencia_funcional": {
		"id": &"dependencia_funcional",
		"nome": "Dependência Funcional",
		"descricao": "Foco químico com dose dupla ++ / Tremores e ansiedade na abstinência --",
		"mods": {}
	},
	&"sorte_do_abismo": {
		"id": &"sorte_do_abismo",
		"nome": "Sorte do Abismo",
		"descricao": "Atração por substâncias raras ++ / Tensão existencial permanente -",
		"mods": {"chance_rara_bonus": 0.06, "offset_tensao_base": 0.04}
	}
}

var streak_high_roller: int = 0
var traits_ativos: Array[StringName] = []
var pilulas_consumidas_hoje: Array[StringName] = []
var modificadores_atuais: Dictionary = {}
var vidros_sorteados_atuais: Dictionary = {}


func obter_catalogo() -> Dictionary:
	return CATALOGO.duplicate(true)


func obter_loot_table_padrao() -> Array[StringName]:
	var lista: Array[StringName] = []
	for id in CATALOGO:
		if not CATALOGO[id]["raro"]:
			lista.append(id)
	return lista


func obter_loot_table_rara() -> Array[StringName]:
	var lista: Array[StringName] = []
	for id in CATALOGO:
		if CATALOGO[id]["raro"]:
			lista.append(id)
	return lista


func calcular_chance_rara() -> float:
	var chance: float = 0.02 + float(streak_high_roller) * 0.03
	if tem_trait(&"sorte_do_abismo"):
		chance += 0.06
	return clampf(chance, 0.0, 1.0)


func sortear_pilula() -> StringName:
	var chance_rara := calcular_chance_rara()
	if randf() < chance_rara:
		var rara := obter_loot_table_rara()
		if rara.size() > 0:
			return rara[randi() % rara.size()]

	var padrao := obter_loot_table_padrao()
	return padrao[randi() % padrao.size()]


func sortear_vidros_manha() -> Dictionary:
	vidros_sorteados_atuais = {
		"esquerda": [sortear_pilula(), sortear_pilula()],
		"direita": [sortear_pilula(), sortear_pilula()]
	}
	return vidros_sorteados_atuais.duplicate(true)


func tem_trait(trait_id: StringName) -> bool:
	return traits_ativos.has(trait_id)


func adicionar_trait(trait_id: StringName) -> bool:
	if not TRAITS_CATALOGO.has(trait_id) or tem_trait(trait_id):
		return false
	traits_ativos.append(trait_id)
	trait_desbloqueado.emit(trait_id, TRAITS_CATALOGO[trait_id])
	return true


func remover_trait(trait_id: StringName) -> bool:
	if not tem_trait(trait_id):
		return false
	traits_ativos.erase(trait_id)
	return true


func obter_modificador(nome_mod: String, valor_padrao: float = 0.0) -> float:
	return float(modificadores_atuais.get(nome_mod, valor_padrao))


func possui_protecao_segunda_captura() -> bool:
	return obter_modificador("segunda_chance_captura", 0.0) >= 1.0


func limpar_efeitos_diarios() -> void:
	pilulas_consumidas_hoje.clear()
	modificadores_atuais.clear()


func aplicar_escolha(opcao: int, vidros_sorteados: Dictionary = {}) -> Dictionary:
	# opcao: 0 = esquerda (2 pílulas), 1 = direita (2 pílulas), 2 = ambos (4 pílulas)
	if not vidros_sorteados.is_empty():
		vidros_sorteados_atuais = vidros_sorteados.duplicate(true)
	elif vidros_sorteados_atuais.is_empty():
		sortear_vidros_manha()

	var pilulas_escolhidas: Array[StringName] = []
	match opcao:
		0:
			pilulas_escolhidas.append_array(vidros_sorteados_atuais.get("esquerda", []))
			streak_high_roller = maxi(0, streak_high_roller - 1)
		1:
			pilulas_escolhidas.append_array(vidros_sorteados_atuais.get("direita", []))
			streak_high_roller = maxi(0, streak_high_roller - 1)
		2:
			pilulas_escolhidas.append_array(vidros_sorteados_atuais.get("esquerda", []))
			pilulas_escolhidas.append_array(vidros_sorteados_atuais.get("direita", []))
			streak_high_roller += 1

			# Sorteia/desbloqueia um novo trait se houver traits disponíveis
			var traits_disponiveis: Array[StringName] = []
			for t_id in TRAITS_CATALOGO:
				if not tem_trait(t_id):
					traits_disponiveis.append(t_id)
			if traits_disponiveis.size() > 0:
				var sorteado = traits_disponiveis[randi() % traits_disponiveis.size()]
				adicionar_trait(sorteado)

	limpar_efeitos_diarios()
	pilulas_consumidas_hoje = pilulas_escolhidas.duplicate()

	# Acumula modificadores das pílulas consumidas
	for p_id in pilulas_consumidas_hoje:
		if CATALOGO.has(p_id):
			var mods: Dictionary = CATALOGO[p_id].get("mods", {})
			for m_key in mods:
				var val = mods[m_key]
				if val is bool:
					modificadores_atuais[m_key] = val
				else:
					modificadores_atuais[m_key] = float(modificadores_atuais.get(m_key, 0.0)) + float(val)

	# Efeitos dinâmicos do trait "dependência funcional"
	if tem_trait(&"dependencia_funcional"):
		if opcao == 2:
			# Foco químico com dose dupla ++
			modificadores_atuais["foco_quimico"] = true
			modificadores_atuais["mult_vel_andar"] = float(modificadores_atuais.get("mult_vel_andar", 0.0)) + 0.06
			modificadores_atuais["bonus_tempo_tarefa"] = float(modificadores_atuais.get("bonus_tempo_tarefa", 0.0)) + 0.50
		else:
			# Tremor de abstinência --
			modificadores_atuais["tremor_abstinencia"] = true
			modificadores_atuais["mult_impulso_erro"] = float(modificadores_atuais.get("mult_impulso_erro", 0.0)) + 0.25
			modificadores_atuais["mult_vel_andar"] = float(modificadores_atuais.get("mult_vel_andar", 0.0)) - 0.05

	var resultado := {
		"opcao": opcao,
		"pilulas": pilulas_consumidas_hoje.duplicate(),
		"streak_high_roller": streak_high_roller,
		"traits_ativos": traits_ativos.duplicate(),
		"modificadores": modificadores_atuais.duplicate()
	}

	escolha_aplicada.emit(opcao, resultado)
	return resultado
