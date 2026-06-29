class_name LevelManager
extends Node
## Administra el PROGRESO de un nivel procedural: cuenta las salas de puzzle, lleva
## el contador en la UI del jugador y desbloquea la sala del Boss al completarlas
## todas. El generador (start_cave.gd) lo instancia como hijo y le entrega las salas
## ya construidas, separando la geometría (generación) de la gestión de progreso.

# Tipos de sala relevantes para el progreso (deben coincidir con los del generador).
const ROOM_BOSS := "Boss"
const ROOM_PUZZLE := "Puzzle"

## Total de salas de puzzle del nivel.
var total_puzzles: int = 0
## Puzzles ya resueltos.
var puzzles_completed: int = 0
# Set (por instance_id) de salas ya contadas, para no contar un mismo puzzle dos veces.
var _cleared_rooms: Dictionary = {}
var _boss_room: RoomLayout = null
# Jugador del nivel, cacheado para refrescar/ocultar su contador (vive en su UI).
var _player: Node = null

## Recibe las salas ya construidas: cuenta los puzzles, localiza el Boss (que arranca
## bloqueado en configure_room), conecta las señales de resolución y prepara el
## contador. El Boss se desbloquea al completar todos los puzzles.
func setup(rooms: Array) -> void:
	for room in rooms:
		if not room is RoomLayout:
			continue
		match room.room_type:
			ROOM_BOSS:
				_boss_room = room
			ROOM_PUZZLE:
				total_puzzles += 1
				room.room_cleared.connect(_on_room_cleared)
				# Defensa: si una sala ya estuviera resuelta al generarse (auto-
				# resolución futura), cuéntala desde el inicio para no desincronizar
				# el contador ni el desbloqueo del Boss.
				if room.is_puzzled_cleared:
					_cleared_rooms[room.get_instance_id()] = true
					puzzles_completed += 1
	_resolve_player()
	# El contador solo se ve dentro del nivel procedural: aquí se activa al entrar.
	if is_instance_valid(_player):
		_player.mostrar_contador_puzzles(true)
	_update_counter()
	# Sin puzzles pendientes, el Boss queda accesible de entrada.
	if puzzles_completed >= total_puzzles:
		_unlock_boss()

## Maneja la resolución de una sala de puzzle: la cuenta UNA sola vez (evita dobles
## si el jugador vuelve a interactuar), refresca la UI y, al completar todas,
## desbloquea la sala del Boss.
func _on_room_cleared(room: RoomLayout) -> void:
	var id := room.get_instance_id()
	if _cleared_rooms.has(id):
		return
	_cleared_rooms[id] = true
	puzzles_completed += 1
	_update_counter()
	if puzzles_completed >= total_puzzles:
		_unlock_boss()

## Cachea al jugador del nivel (el contador de puzzles vive en su UI).
func _resolve_player() -> void:
	_player = get_tree().get_first_node_in_group("Player")

## Actualiza el contador a través de la API del jugador ("Puzzles: X / Y").
func _update_counter() -> void:
	if is_instance_valid(_player) and _player.has_method("actualizar_contador_puzzles"):
		_player.actualizar_contador_puzzles(puzzles_completed, total_puzzles)

## Al salir del nivel procedural (este nodo abandona el árbol), vuelve a ocultar el
## contador para que no quede visible fuera del dungeon. Se protege con
## is_instance_valid por si el Player se libera junto con la escena.
func _exit_tree() -> void:
	if is_instance_valid(_player) and _player.has_method("mostrar_contador_puzzles"):
		_player.mostrar_contador_puzzles(false)

## Desbloquea el acceso físico a la sala del Boss y avisa al jugador.
func _unlock_boss() -> void:
	if _boss_room:
		_boss_room.unlock_boss_room()
	if not is_instance_valid(_player):
		_resolve_player()
	if is_instance_valid(_player) and _player.has_method("show_message"):
		_player.show_message("¡La sala del Jefe ha sido desbloqueada!", 4.0)
