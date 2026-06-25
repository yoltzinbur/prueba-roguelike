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
@export var room_size: Vector2 = Vector2(528, 288)

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

func _ready() -> void:
	if generation_seed >= 0:
		seed(generation_seed)
	else:
		randomize()
	generate_map()
	build_rooms()

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
