class_name ConfiguracoesUsuario
extends RefCounted

## Persistência e aplicação centralizada das configurações de áudio, vídeo e controles.
## Integrada aos 4 buses de default_bus_layout.tres (Master, Musica, Ambiente, SFX).

const CAMINHO_PADRAO: String = "user://delusio_config.cfg"
const DB_BASE_BUSES: Dictionary = {
	"Master": 0.0,
	"Musica": -4.0,
	"Ambiente": -2.0,
	"SFX": 0.0
}


static func valores_padrao() -> Dictionary:
	return {
		"volume_master": 100.0,
		"volume_musica": 100.0,
		"volume_ambiente": 100.0,
		"volume_sfx": 100.0,
		"tela_cheia": false,
		"vsync": true,
		"brilho": 1.0,
		"sensibilidade_mouse": 0.002
	}


static func carregar(caminho: String = CAMINHO_PADRAO) -> Dictionary:
	var dados: Dictionary = valores_padrao()
	var cfg := ConfigFile.new()
	if cfg.load(caminho) != OK:
		return dados

	dados["volume_master"] = clampf(float(cfg.get_value("audio", "volume_master", 100.0)), 0.0, 100.0)
	dados["volume_musica"] = clampf(float(cfg.get_value("audio", "volume_musica", 100.0)), 0.0, 100.0)
	dados["volume_ambiente"] = clampf(float(cfg.get_value("audio", "volume_ambiente", 100.0)), 0.0, 100.0)
	dados["volume_sfx"] = clampf(float(cfg.get_value("audio", "volume_sfx", 100.0)), 0.0, 100.0)
	dados["tela_cheia"] = bool(cfg.get_value("video", "tela_cheia", false))
	dados["vsync"] = bool(cfg.get_value("video", "vsync", true))
	dados["brilho"] = clampf(float(cfg.get_value("video", "brilho", 1.0)), 0.5, 1.5)
	dados["sensibilidade_mouse"] = clampf(float(cfg.get_value("controles", "sensibilidade_mouse", 0.002)), 0.0005, 0.006)
	return dados


static func salvar(dados: Dictionary, caminho: String = CAMINHO_PADRAO) -> int:
	var mesclado: Dictionary = valores_padrao()
	for chave in mesclado.keys():
		if dados.has(chave):
			mesclado[chave] = dados[chave]

	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume_master", clampf(float(mesclado["volume_master"]), 0.0, 100.0))
	cfg.set_value("audio", "volume_musica", clampf(float(mesclado["volume_musica"]), 0.0, 100.0))
	cfg.set_value("audio", "volume_ambiente", clampf(float(mesclado["volume_ambiente"]), 0.0, 100.0))
	cfg.set_value("audio", "volume_sfx", clampf(float(mesclado["volume_sfx"]), 0.0, 100.0))
	cfg.set_value("video", "tela_cheia", bool(mesclado["tela_cheia"]))
	cfg.set_value("video", "vsync", bool(mesclado["vsync"]))
	cfg.set_value("video", "brilho", clampf(float(mesclado["brilho"]), 0.5, 1.5))
	cfg.set_value("controles", "sensibilidade_mouse", clampf(float(mesclado["sensibilidade_mouse"]), 0.0005, 0.006))
	return cfg.save(caminho)


static func aplicar_audio_bus(nome_bus: StringName, percentual: float) -> void:
	var idx: int = AudioServer.get_bus_index(nome_bus)
	if idx == -1:
		return
	var pct: float = clampf(percentual, 0.0, 100.0)
	if pct <= 0.01:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	var db_base: float = float(DB_BASE_BUSES.get(String(nome_bus), 0.0))
	AudioServer.set_bus_volume_db(idx, db_base + linear_to_db(clampf(pct, 0.01, 100.0) / 100.0))


static func aplicar_brilho(
	valor: float,
	arvore: SceneTree = null,
	world_env_override: WorldEnvironment = null
) -> void:
	var v: float = clampf(valor, 0.5, 1.5)
	RenderingServer.global_shader_parameter_set("ajuste_brilho", v)

	if world_env_override != null and world_env_override.environment != null:
		world_env_override.environment.tonemap_exposure = v
	elif arvore != null and arvore.current_scene != null:
		var env_node := arvore.current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if env_node != null and env_node.environment != null:
			env_node.environment.tonemap_exposure = v


static func aplicar_sensibilidade_mouse(valor: float, arvore: SceneTree = null) -> void:
	if arvore == null:
		return
	var sens: float = clampf(valor, 0.0005, 0.006)
	for node in arvore.get_nodes_in_group("player"):
		if node != null and ("sensibilidade_mouse" in node):
			node.set("sensibilidade_mouse", sens)


static func aplicar_todas(
	dados: Dictionary,
	arvore: SceneTree = null,
	aplicar_janela: bool = true,
	world_env_override: WorldEnvironment = null
) -> void:
	aplicar_audio_bus(&"Master", float(dados.get("volume_master", 100.0)))
	aplicar_audio_bus(&"Musica", float(dados.get("volume_musica", 100.0)))
	aplicar_audio_bus(&"Ambiente", float(dados.get("volume_ambiente", 100.0)))
	aplicar_audio_bus(&"SFX", float(dados.get("volume_sfx", 100.0)))
	aplicar_brilho(float(dados.get("brilho", 1.0)), arvore, world_env_override)
	aplicar_sensibilidade_mouse(float(dados.get("sensibilidade_mouse", 0.002)), arvore)

	if aplicar_janela and DisplayServer.get_name() != "headless":
		var tela_cheia: bool = bool(dados.get("tela_cheia", false))
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED
		)
		var vsync: bool = bool(dados.get("vsync", true))
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
