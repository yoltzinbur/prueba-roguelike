extends Node
## Persistencia de la partida: frascos máximos, monedas, niveles completados y el
## punto de guardado (cueva/bosque). Guarda en user://savegame.cfg con ConfigFile.
##
## Las monedas viven en GameManager.coins; aquí sólo se leen/escriben para no
## duplicar el estado ni romper la UI del contador (coins_counter.gd). Registrar
## este script como autoload DESPUÉS de GameManager.

const SAVE_PATH := "user://savegame.cfg"
const SECTION := "game"
## Total de niveles del juego. Al completarlos todos se desbloquea el jefe final.
const TOTAL_LEVELS := 2

## Frascos máximos del jugador (sube +1 por cada jefe vencido).
var max_flasks: int = 3
## Niveles completados (0..TOTAL_LEVELS).
var levels_completed: int = 0
## Dónde reanudar al abrir el juego: "cave" o "forest".
var save_location: String = "cave"

func _ready() -> void:
	if has_save():
		load_game()

## True si existe un archivo de guardado en disco.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Vuelca el estado actual (incluidas las monedas de GameManager) a disco.
func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "max_flasks", max_flasks)
	config.set_value(SECTION, "levels_completed", levels_completed)
	config.set_value(SECTION, "save_location", save_location)
	config.set_value(SECTION, "coins", GameManager.coins)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("No se pudo guardar la partida (código %d)" % error)

## Lee el archivo de guardado a memoria y aplica las monedas a GameManager.
func load_game() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		push_error("No se pudo cargar la partida (código %d)" % error)
		return
	max_flasks = config.get_value(SECTION, "max_flasks", max_flasks)
	levels_completed = config.get_value(SECTION, "levels_completed", levels_completed)
	save_location = config.get_value(SECTION, "save_location", save_location)
	GameManager.coins = config.get_value(SECTION, "coins", GameManager.coins)

## Vencido un jefe: sube un frasco máximo, cuenta el nivel, fija el bosque como
## punto de guardado, persiste y lleva al jugador al bosque.
func complete_level() -> void:
	levels_completed = mini(levels_completed + 1, TOTAL_LEVELS)
	max_flasks += 1
	save_location = "forest"
	save_game()
	GameManager.load_scene(GameScenes.FORESTMAIN)

## Llegada al bosque: fija el punto, rellena al jugador y guarda.
func register_forest_arrival(player: Node) -> void:
	save_location = "forest"
	apply_player_state(player)
	save_game()

## Rellena los frascos del jugador al máximo guardado (y su vida), usando la API
## pública del jugador para no depender de su HealthComponent interno.
func apply_player_state(player: Node) -> void:
	if player != null and player.has_method("curar_completo"):
		player.curar_completo(max_flasks)
