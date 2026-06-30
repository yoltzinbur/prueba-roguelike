extends Control
## Overlay de mapa básico para niveles procedurales. Dibuja un cuadrado por sala
## (sin colores ni marcadores: todos idénticos) sobre un fondo semitransparente.
##
## El mapa se DESCUBRE poco a poco: cada vez que el jugador llega a una sala se
## revelan esa sala y sus salas contiguas. El jugador va armando el mapa mentalmente.
##
## Se abre/cierra con el input "map" (tecla M) o con "pause" (Esc) si está abierto,
## y pausa el juego mientras está visible, igual que el menú de pausa.

## Paso de cada celda en píxeles (incluye el gap).
@export var cell: float = 40.0
## Separación entre cuadrados; el lado del cuadrado es (cell - gap).
@export var gap: float = 6.0
## Color de los cuadrados y del fondo semitransparente.
@export var square_color: Color = Color.WHITE
@export var background_color: Color = Color(0, 0, 0, 0.6)

# Direcciones cardinales en coordenadas de cuadrícula (igual que start_cave.gd).
const CARDINALS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)
]

# Nodo raíz del nivel procedural (CaveMain). Expone `map` y `room_size`.
var _cave: Node = null
# Tamaño en píxeles del footprint de cada sala; se lee del nivel (fallback razonable).
var _room_size: Vector2 = Vector2(592, 368)

# Salas ya descubiertas: coordenada de cuadrícula (Vector2i) -> true.
var _discovered: Dictionary = {}
# Última sala registrada del jugador, para detectar cuándo cambia.
var _last_room: Node = null

func _ready() -> void:
	visible = false
	# Sigue procesando input/descubrimiento aunque el árbol esté pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	_resolver_nivel()
	_actualizar_descubrimiento()

	if Input.is_action_just_pressed("map"):
		_toggle()
	elif visible and Input.is_action_just_pressed("pause"):
		_close()

# --- Resolución del nivel procedural ---------------------------------------

## Localiza (una sola vez) el nodo raíz del nivel si expone `map`. En escenas no
## procedurales `_cave` queda en null y el overlay nunca se abre.
func _resolver_nivel() -> void:
	if _cave != null and is_instance_valid(_cave):
		return
	var scene := get_tree().current_scene
	if scene != null and "map" in scene:
		_cave = scene
		if "room_size" in scene:
			_room_size = scene.room_size

# --- Descubrimiento ---------------------------------------------------------

## Si el jugador cambió de sala, revela esa sala y sus contiguas existentes.
func _actualizar_descubrimiento() -> void:
	if _cave == null:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var room = player.current_room
	if room == null or room == _last_room:
		return
	_last_room = room
	_revelar(_coord_de(room))

## Coordenada de cuadrícula de una sala, derivada de su posición en píxeles.
func _coord_de(room: Node) -> Vector2i:
	return Vector2i((room.position / _room_size).round())

## Marca como descubierta la sala `coord` y cada vecina que exista en el mapa.
func _revelar(coord: Vector2i) -> void:
	_discovered[coord] = true
	for dir in CARDINALS:
		var vecina := coord + dir
		if _cave.map.has(vecina):
			_discovered[vecina] = true

# --- Apertura / cierre ------------------------------------------------------

func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	if _cave == null:
		return
	visible = true
	get_tree().paused = true
	queue_redraw()

func _close() -> void:
	visible = false
	get_tree().paused = false

# --- Dibujo -----------------------------------------------------------------

func _draw() -> void:
	# Fondo semitransparente a pantalla completa.
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if _discovered.is_empty():
		return

	# Bounding box de las salas DESCUBIERTAS: el mapa se centra solo en lo conocido,
	# así no se revela la extensión total del nivel. Las posiciones relativas se
	# conservan (es solo una traslación), preservando la memoria espacial.
	var coords := _discovered.keys()
	var min_x: int = coords[0].x
	var max_x: int = coords[0].x
	var min_y: int = coords[0].y
	var max_y: int = coords[0].y
	for c in coords:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)

	var grid_total := Vector2((max_x - min_x + 1) * cell, (max_y - min_y + 1) * cell)
	var origin := (size - grid_total) * 0.5
	var square := Vector2(cell - gap, cell - gap)

	for c in coords:
		var cell_pos := Vector2((c.x - min_x) * cell, (c.y - min_y) * cell)
		draw_rect(Rect2(origin + cell_pos, square), square_color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
