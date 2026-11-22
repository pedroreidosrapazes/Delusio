class_name ZonaBreuNoturno
extends Area3D

## Área exclusiva noturna ao Sul que exige lanterna 100% ligada e amplia o risco dos monstros.

signal jogador_entrou_breu(player: Player)
signal jogador_saiu_breu(player: Player)
signal entrada_bloqueada(motivo: String)

@export_category("Regras da Área Noturna")
@export var exigir_noite: bool = true
@export var bloquear_desligar_lanterna_dentro: bool = true
@export var multiplicador_atracao_silhueta: float = 1.5
@export var multiplicador_visao_rondante: float = 1.25

var jogador_no_breu: bool = false
var _jogador_atual: Player = null
var _ultima_pos_fora: Vector3 = Vector3.ZERO
var _aviso_cooldown: float = 0.0
var _particulas_breu: GPUParticles3D = null


func _ready() -> void:
	add_to_group("zona_breu_noturno")
	monitoring = true
	if get_node_or_null("ParticulasBreuSul") == null:
		_particulas_breu = FabricaParticulasDelusio.criar_nevoa_breu()
		add_child(_particulas_breu)
	if not body_entered.is_connected(_ao_entrar_corpo):
		body_entered.connect(_ao_entrar_corpo)
	if not body_exited.is_connected(_ao_sair_corpo):
		body_exited.connect(_ao_sair_corpo)


func _process(delta: float) -> void:
	_aviso_cooldown = maxf(0.0, _aviso_cooldown - delta)
	var p := _obter_player()
	if p == null:
		return
	if not contem_ponto(p.global_position):
		_ultima_pos_fora = p.global_position
		if jogador_no_breu:
			jogador_no_breu = false
			_jogador_atual = null
			jogador_saiu_breu.emit(p)
	elif not jogador_no_breu:
		validar_entrada_ou_recuar(p)


func _obter_player() -> Player:
	if _jogador_atual != null and is_instance_valid(_jogador_atual):
		return _jogador_atual
	if get_tree() != null:
		return get_tree().get_first_node_in_group("player") as Player
	return null


func _ao_entrar_corpo(body: Node3D) -> void:
	if body is Player:
		validar_entrada_ou_recuar(body as Player)


func _ao_sair_corpo(body: Node3D) -> void:
	if body is Player:
		if jogador_no_breu:
			jogador_no_breu = false
			_jogador_atual = null
			jogador_saiu_breu.emit(body as Player)


func contem_ponto(pos_global: Vector3) -> bool:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is BoxShape3D:
		var box := col.shape as BoxShape3D
		var half := box.size * 0.5
		var local_pt := col.to_local(pos_global) if col.is_inside_tree() else (pos_global - (global_position + col.position))
		return (
			absf(local_pt.x) <= half.x
			and absf(local_pt.y) <= half.y
			and absf(local_pt.z) <= half.z
		)
	return false


func pode_entrar(player: Player) -> Dictionary:
	var gerente := GameManager.instance
	if exigir_noite and gerente != null and gerente.horario_atual != 2:
		return {
			"permitido": false,
			"motivo": "A mata ao sul está tomada pela névoa — só é possível avançar ali à noite."
		}
	if player == null or not player.esta_com_lanterna_acesa():
		return {
			"permitido": false,
			"motivo": "Breu absoluto! Ligue a lanterna [F] para entrar na área sul."
		}
	return {"permitido": true, "motivo": ""}


func validar_entrada_ou_recuar(player: Player) -> bool:
	if player == null:
		return false
	var res := pode_entrar(player)
	if not bool(res.get("permitido", false)):
		var motivo := str(res.get("motivo", ""))
		var pos_segura := _ultima_pos_fora
		if pos_segura == Vector3.ZERO or contem_ponto(pos_segura):
			var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
			var half_z := 11.0
			if col != null and col.shape is BoxShape3D:
				half_z = (col.shape as BoxShape3D).size.z * 0.5
			pos_segura = Vector3(player.global_position.x, player.global_position.y, global_position.z - half_z - 1.2)
		player.global_position = pos_segura
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		if _aviso_cooldown <= 0.0:
			_aviso_cooldown = 1.5
			BancoAudioDelusio.tocar_2d(self, &"lanterna_bloqueada", -3.0, 0.04)
			if GameManager.instance != null:
				GameManager.instance.status_temporario.emit(motivo)
		entrada_bloqueada.emit(motivo)
		return false

	if not jogador_no_breu:
		jogador_no_breu = true
		_jogador_atual = player
		jogador_entrou_breu.emit(player)
	return true


func esta_jogador_dentro(player: Player = null) -> bool:
	var p := player if player != null else _obter_player()
	if p == null:
		return jogador_no_breu
	var res := pode_entrar(p)
	if not bool(res.get("permitido", false)):
		return false
	if jogador_no_breu and p == _jogador_atual:
		return true
	return contem_ponto(p.global_position)


func deve_bloquear_desligar_lanterna(player: Player) -> bool:
	return bloquear_desligar_lanterna_dentro and esta_jogador_dentro(player)
