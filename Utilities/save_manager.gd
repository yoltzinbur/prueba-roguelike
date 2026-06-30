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
## Dónde reaparece el jugador en el bosque al REANUDAR: "level1" o "savepoint". Sólo lo
## cambia el SavePoint (y la llegada inicial del nivel 1). Se persiste.
var forest_spawn: String = "level1"
## Punto de aparición transitorio para la siguiente entrada al bosque (p. ej. "level2",
## frente a la cueva). NO se persiste: se consume una sola vez en consume_forest_spawn().
var _next_forest_spawn: String = ""
## IDs de cofres ya abiertos (persistentes). Sólo los cofres con save_id se guardan.
## Sin tipar a propósito: ConfigFile devuelve Array genérico al cargar.
var opened_chests: Array = []
## True una vez derrotado el jefe final: el BossPortal desaparece y la arena ya no es accesible.
var boss_defeated: bool = false

func _ready() -> void:
	if has_save():
		load_game()

## True si existe un archivo de guardado en disco.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Borra la partida guardada del disco y devuelve TODO el estado en memoria a sus
## valores por defecto, para empezar de cero. La usa el botón NEW GAME del menú: como
## SaveManager es autoload, no basta con borrar el archivo (el estado ya está cargado
## en memoria), así que también se reinicia aquí, incluidas las monedas de GameManager.
func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	max_flasks = 3
	levels_completed = 0
	save_location = "cave"
	forest_spawn = "level1"
	_next_forest_spawn = ""
	opened_chests = []
	boss_defeated = false
	GameManager.coins = 0

## Vuelca el estado actual (incluidas las monedas de GameManager) a disco.
func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "max_flasks", max_flasks)
	config.set_value(SECTION, "levels_completed", levels_completed)
	config.set_value(SECTION, "save_location", save_location)
	config.set_value(SECTION, "forest_spawn", forest_spawn)
	config.set_value(SECTION, "opened_chests", opened_chests)
	config.set_value(SECTION, "boss_defeated", boss_defeated)
	config.set_value(SECTION, "coins", GameManager.coins)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("No se pudo guardar la partida (código %d)" % error)
		return
	_announce_saved()

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
	forest_spawn = config.get_value(SECTION, "forest_spawn", forest_spawn)
	opened_chests = config.get_value(SECTION, "opened_chests", opened_chests)
	boss_defeated = config.get_value(SECTION, "boss_defeated", boss_defeated)
	GameManager.coins = config.get_value(SECTION, "coins", GameManager.coins)

## Muestra el aviso de guardado en la UI del jugador, si hay uno en escena. Se llama
## tras cada guardado real (save_game), no sólo desde el SavePoint.
func _announce_saved() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("show_message"):
		player.show_message("Partida guardada")

## True si el cofre con ese id ya fue abierto en una sesión previa.
func is_chest_opened(id: String) -> bool:
	return id in opened_chests

## Marca un cofre como abierto SÓLO en memoria (idempotente). No persiste por sí mismo:
## el estado se escribirá en el próximo save_game real (SavePoint, llegada al bosque, fin
## de nivel), junto con las monedas ya recogidas. Así nunca se guarda el cofre abierto sin
## guardar también las monedas que soltó.
func mark_chest_opened(id: String) -> void:
	if id in opened_chests:
		return
	opened_chests.append(id)

## Punto de aparición para la siguiente entrada al bosque. Si hay uno transitorio (nivel 2,
## frente a la cueva) lo devuelve una sola vez y lo limpia; si no, devuelve el punto de
## reanudación persistido (lo fija el SavePoint).
func consume_forest_spawn() -> String:
	if _next_forest_spawn != "":
		var spawn := _next_forest_spawn
		_next_forest_spawn = ""
		return spawn
	return forest_spawn

## Vencido un jefe: sube un frasco máximo, cuenta el nivel, fija el bosque como
## punto de guardado, persiste y lleva al jugador al bosque.
func complete_level() -> void:
	levels_completed = mini(levels_completed + 1, TOTAL_LEVELS)
	max_flasks += 1
	save_location = "forest"
	# El punto del nivel 2 (frente a la cueva) es transitorio: NO se guarda como punto de
	# reanudación. Para reestablecerlo hay que volver al SavePoint. El nivel 1 sí fija su
	# punto de reanudación.
	if levels_completed >= TOTAL_LEVELS:
		_next_forest_spawn = "level2"
	else:
		forest_spawn = "level1"
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
