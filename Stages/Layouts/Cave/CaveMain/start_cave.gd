extends Node2D
## Generador procedural de mapa estilo rogue-lite (Drunkard's Walk).
## Reparte salas (Layout1.tscn) sobre una cuadrícula orgánica y las conecta
## entre sí según vecindad. Es la escena principal del juego (CaveMain.tscn).

const ROOM_SCENE: PackedScene = preload("res://Stages/Layouts/Cave/Layout1.tscn")

# Tipos de sala (en inglés, según la convención del proyecto).
const ROOM_START := "Start"
const ROOM_BOSS := "Boss"
const ROOM_EASY := "Easy"
const ROOM_MEDIUM := "Medium"
const ROOM_HARD := "Hard"
const ROOM_PUZZLE := "Puzzle"
const ROOM_REST := "Rest"

# Cantidad EXACTA de cada tipo de sala (configurable desde el editor).
@export var easy_room: int = 4
@export var medium_room: int = 3
@export var hard_room: int = 2
@export var puzzle_room: int = 1
@export var rest_room: int = 1

## Tamaño en píxeles del "footprint" de cada sala. Debe coincidir con el tamaño
## real de Layout1.tscn para que las puertas vecinas queden alineadas.
#@export var room_size: Vector2 = Vector2(528, 288)
@export var room_size: Vector2 = Vector2(592, 368)

## Semilla de generación. -1 = aleatoria en cada ejecución.
@export var generation_seed: int = -1

# Direcciones cardinales en coordenadas de cuadrícula.
const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const CARDINALS: Array[Vector2i] = [NORTH, SOUTH, EAST, WEST]

# Mapa generado: coordenada de cuadrícula (Vector2i) -> tipo de sala (String).
var map: Dictionary = {}

@onready var rooms_container: Node2D = $Rooms

# --- Progreso de puzzles y desbloqueo del Boss -------------------------------

## Total de salas de puzzle del nivel (se cuenta tras generar el mapa).
var total_puzzles: int = 0
## Puzzles ya resueltos.
var puzzles_completed: int = 0
# Set (por instance_id) de salas ya contadas, para no contar un mismo puzzle dos veces.
var _cleared_rooms: Dictionary = {}
var _boss_room: RoomLayout = null
# Contenedor del contador (Control con ícono + Label) y su Label de texto. El
# contenedor solo se hace visible dentro de un nivel procedural.
var _puzzle_counter_node: Control = null
var _puzzle_counter: Label = null

func _ready() -> void:
	if generation_seed >= 0:
		seed(generation_seed)
	else:
		randomize()
	generate_map()
	build_rooms()
	_init_puzzle_progress()

## Calcula el tamaño total del mapa y reparte los tipos de sala sobre las
## coordenadas obtenidas con Drunkard's Walk.
func generate_map() -> void:
	map.clear()

	# Suma de salas pedidas + 2 (Sala de Inicio y Sala de Jefe).
	var filler_count: int = easy_room + medium_room + hard_room + puzzle_room + rest_room
	var total_rooms: int = filler_count + 2

	var coordinates: Array[Vector2i] = _drunkards_walk(total_rooms)

	# La Sala de Inicio siempre está en (0,0).
	var start_coord: Vector2i = coordinates[0]
	map[start_coord] = ROOM_START

	# La Sala de Jefe va en la coordenada más lejana (distancia Manhattan).
	var boss_coord: Vector2i = _farthest_coord(coordinates, start_coord)
	map[boss_coord] = ROOM_BOSS

	# "Bolsa" con los tipos solicitados, mezclada y vaciada sobre el resto.
	var bag: Array[String] = _build_room_bag()
	bag.shuffle()

	for coord in coordinates:
		if coord == start_coord or coord == boss_coord:
			continue
		if bag.is_empty():
			break
		map[coord] = bag.pop_back()

## Drunkard's Walk: parte de (0,0) y camina en direcciones cardinales aleatorias
## hasta reunir `amount` celdas distintas. El resultado es una región conexa y
## orgánica (deja huecos vacíos en la cuadrícula).
func _drunkards_walk(amount: int) -> Array[Vector2i]:
	var visited: Array[Vector2i] = []
	var seen: Dictionary = {}

	var current := Vector2i.ZERO
	visited.append(current)
	seen[current] = true

	# Límite de seguridad para evitar un bucle infinito teórico.
	var safety: int = amount * 1000
	while visited.size() < amount and safety > 0:
		safety -= 1
		current += CARDINALS.pick_random()
		if not seen.has(current):
			seen[current] = true
			visited.append(current)

	return visited

## Devuelve la coordenada con mayor distancia Manhattan respecto a `origin`.
## En caso de empate prioriza la última generada, garantizando recorrido.
func _farthest_coord(coordinates: Array[Vector2i], origin: Vector2i) -> Vector2i:
	var best: Vector2i = origin
	var best_distance: int = -1
	for coord in coordinates:
		if coord == origin:
			continue
		var distance: int = abs(coord.x - origin.x) + abs(coord.y - origin.y)
		if distance >= best_distance:
			best_distance = distance
			best = coord
	return best

## Construye la bolsa de tipos de sala según las cantidades @export.
func _build_room_bag() -> Array[String]:
	var bag: Array[String] = []
	for i in easy_room:
		bag.append(ROOM_EASY)
	for i in medium_room:
		bag.append(ROOM_MEDIUM)
	for i in hard_room:
		bag.append(ROOM_HARD)
	for i in puzzle_room:
		bag.append(ROOM_PUZZLE)
	for i in rest_room:
		bag.append(ROOM_REST)
	return bag

## Instancia una sala por coordenada y la configura según sus vecinos.
func build_rooms() -> void:
	for coord in map:
		var room := ROOM_SCENE.instantiate() as RoomLayout
		room.position = Vector2(coord) * room_size
		rooms_container.add_child(room)

		# Las puertas se abren hacia los vecinos existentes en el mapa.
		var has_north: bool = map.has(coord + NORTH)
		var has_south: bool = map.has(coord + SOUTH)
		var has_east: bool = map.has(coord + EAST)
		var has_west: bool = map.has(coord + WEST)

		room.configure_room(map[coord], has_north, has_south, has_east, has_west)

## Cuenta las salas de puzzle, localiza la del Boss, conecta sus señales de
## resolución y prepara el contador de la UI. El Boss arranca bloqueado (lo hace la
## propia sala en configure_room); aquí solo se desbloquea al completar todo.
func _init_puzzle_progress() -> void:
	for room in rooms_container.get_children():
		if not room is RoomLayout:
			continue
		match room.room_type:
			ROOM_BOSS:
				_boss_room = room
			ROOM_PUZZLE:
				total_puzzles += 1
				room.room_cleared.connect(_on_room_cleared)
	_resolve_puzzle_counter()
	# El contador solo se ve dentro del nivel procedural: aquí se activa al entrar.
	if _puzzle_counter_node:
		_puzzle_counter_node.visible = true
	_update_puzzle_counter_ui()
	# Sin puzzles que resolver, el Boss queda accesible de entrada.
	if total_puzzles == 0:
		_unlock_boss_room()

## Maneja la resolución de una sala de puzzle: la cuenta UNA sola vez (evita dobles
## si el jugador vuelve a interactuar), refresca la UI y, al completar todas,
## desbloquea la sala del Boss.
func _on_room_cleared(room: RoomLayout) -> void:
	var id := room.get_instance_id()
	if _cleared_rooms.has(id):
		return
	_cleared_rooms[id] = true
	puzzles_completed += 1
	_update_puzzle_counter_ui()
	if puzzles_completed >= total_puzzles:
		_unlock_boss_room()

## Localiza el contador dentro de la UI del Player: el nodo "PuzzlesCounter"
## (instancia de PuzzlesCounter.tscn) y su hijo "Label".
func _resolve_puzzle_counter() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	_puzzle_counter_node = player.get_node_or_null("UI/PuzzlesCounter") as Control
	if _puzzle_counter_node:
		_puzzle_counter = _puzzle_counter_node.get_node_or_null("Label") as Label

## Actualiza el texto del contador con el formato "Puzzles: X / Y".
func _update_puzzle_counter_ui() -> void:
	if _puzzle_counter:
		_puzzle_counter.text = "Puzzles: %d / %d" % [puzzles_completed, total_puzzles]

## Al salir del nivel procedural (este nodo abandona el árbol), vuelve a ocultar el
## contador para que no quede visible fuera del dungeon. Se protege con
## is_instance_valid por si el Player se libera junto con la escena.
func _exit_tree() -> void:
	if is_instance_valid(_puzzle_counter_node):
		_puzzle_counter_node.visible = false

## Desbloquea el acceso físico a la sala del Boss y avisa al jugador.
func _unlock_boss_room() -> void:
	if _boss_room:
		_boss_room.unlock_boss_room()
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message("¡La sala del Jefe ha sido desbloqueada!", 4.0)
