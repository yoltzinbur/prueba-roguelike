class_name PuzzleLaser
extends Node2D
## Lógica global del segundo puzzle. Dos tótems (Totem, Totem2) disparan un láser
## horizontal (RayCast2D) hacia su receptor (Receptor, Receptor2). Cada receptor es
## una entrada booleana:
##   - A = Receptor: vale 1 si el láser de Totem llega sin obstáculos, 0 si una caja
##     interrumpe el rayo.
##   - B = Receptor2: ídem con Totem2.
## El bloqueo es físico: una Box sobre el RayCast lo detiene de forma natural. Según
## la compuerta sorteada al instanciarse (AND/OR/XOR) el puzzle se resuelve con
## distintas combinaciones de A y B. La sala (RoomLayout) persiste la compuerta para
## que los reinicios conserven el reto, igual que con el primer puzzle (Pila/Cola).

## Emitida cuando el puzzle se resuelve correctamente (la sala reabre las puertas).
signal puzzle_solved
## Emitida en una sobrecarga XOR (A y B activos a la vez): no resuelve, penaliza.
signal puzzle_overloaded

## Compuertas lógicas posibles. El valor entero (AND=0, OR=1, XOR=2) es el que la
## sala guarda en su persistencia para reimponerlo en los reinicios.
enum LogicMode { AND, OR, XOR }

## Compuerta activa. Se sortea en _ready() la primera vez; en los reinicios la sala
## la vuelve a fijar con apply_fixed_mode() para que el reto no cambie a mitad de
## partida.
var _current_mode: LogicMode = LogicMode.AND

## Estado actual de cada receptor (true = láser impactando, sin caja que lo tape).
var _input_a: bool = false
var _input_b: bool = false

var _is_solved: bool = false
# Cuando la sala impone la compuerta (en un reinicio) se evita re-sortearla.
var _config_fixed: bool = false

# Estilo del haz: verde si alcanza su receptor, rojo si algo lo interrumpe.
const BEAM_COLOR_ON := Color(0.4, 1.0, 0.4)
const BEAM_COLOR_OFF := Color(1.0, 0.3, 0.3)
const BEAM_WIDTH := 1.0

# Cajas que arrancan bloqueando un haz (colocadas sobre los raycasts en la escena).
const BEAM_BLOCKERS: Array[String] = ["Box3", "Box4"]
# Cajas alejadas que no intervienen en la lógica de los láseres.
const DECOY_BOXES: Array[String] = ["Box", "Box2"]

@onready var interaction_objects: Node2D = $InteractionObjects
@onready var laser_a: RayCast2D = $InteractionObjects/Laser
@onready var laser_b: RayCast2D = $InteractionObjects/Laser2
@onready var receptor_a: StaticBody2D = $InteractionObjects/Receptor
@onready var receptor_b: StaticBody2D = $InteractionObjects/Receptor2

func _ready() -> void:
	# Solo se sortea la compuerta en la primera instanciación. En los reinicios la
	# sala ya la fijó con apply_fixed_mode(), conservando el reto original.
	if not _config_fixed:
		_randomize_mode()

	_setup_beam(laser_a)
	_setup_beam(laser_b)
	_apply_box_layout()

## Elige AND, OR o XOR al azar. Solo se llama en la primera instanciación.
func _randomize_mode() -> void:
	_current_mode = [LogicMode.AND, LogicMode.OR, LogicMode.XOR].pick_random()

## Fija la compuerta desde fuera (la sala) ANTES de añadir el nodo al árbol, de modo
## que _ready() no vuelva a sortearla. Así un reinicio conserva la compuerta elegida
## en la primera instanciación.
func apply_fixed_mode(fixed_mode: int) -> void:
	_current_mode = fixed_mode as LogicMode
	_config_fixed = true

## Prepara el RayCast y su Line2D de feedback.
func _setup_beam(laser: RayCast2D) -> void:
	laser.enabled = true
	var line := laser.get_node_or_null("Line2D") as Line2D
	if line:
		line.width = BEAM_WIDTH
		line.default_color = BEAM_COLOR_OFF

## Deja en escena solo las cajas que bloquean los haces (Box3, Box4) y retira las
## alejadas (Box, Box2). Con ambos haces bloqueados los receptores arrancan en
## A=0, B=0, lo que NO resuelve ninguna compuerta (AND y OR exigen al menos un haz
## libre; XOR, exactamente uno), evitando que el puzzle se complete al iniciar. El
## jugador empuja Box3/Box4 fuera de los rayos para liberar los receptores.
func _apply_box_layout() -> void:
	for box_name in DECOY_BOXES:
		var box := interaction_objects.get_node_or_null(box_name)
		if box:
			box.queue_free()

# --- Lectura de receptores y evaluación --------------------------------------

func _physics_process(_delta: float) -> void:
	if _is_solved:
		return

	var a := _read_receptor(laser_a, receptor_a)
	var b := _read_receptor(laser_b, receptor_b)
	_update_beam_visual(laser_a, receptor_a)
	_update_beam_visual(laser_b, receptor_b)

	# Solo se reevalúa cuando cambia el estado de algún receptor (flanco).
	if a == _input_a and b == _input_b:
		return
	_input_a = a
	_input_b = b
	evaluate_puzzle()

## Devuelve true si el láser llega hasta su receptor sin que una caja (u otro cuerpo)
## interrumpa el rayo antes.
func _read_receptor(laser: RayCast2D, receptor: Node) -> bool:
	laser.force_raycast_update()
	return laser.is_colliding() and laser.get_collider() == receptor

## Dibuja el haz desde el tótem hasta donde impacta (caja, pared o receptor) y lo
## tiñe de verde si alcanza su receptor o de rojo si algo lo interrumpe. También
## resalta el receptor cuando está activo.
func _update_beam_visual(laser: RayCast2D, receptor: Node) -> void:
	var hitting := laser.is_colliding() and laser.get_collider() == receptor

	var line := laser.get_node_or_null("Line2D") as Line2D
	if line:
		var end_point := laser.target_position
		if laser.is_colliding():
			end_point = laser.to_local(laser.get_collision_point())
		line.points = PackedVector2Array([Vector2.ZERO, end_point])
		line.default_color = BEAM_COLOR_ON if hitting else BEAM_COLOR_OFF

	if receptor is CanvasItem:
		receptor.modulate = BEAM_COLOR_ON if hitting else Color.WHITE

## Evalúa A y B según la compuerta activa. La llama _physics_process cuando cambia
## el estado de algún receptor.
func evaluate_puzzle() -> void:
	if _is_solved:
		return

	var solved := false
	match _current_mode:
		LogicMode.AND:
			# Resuelve solo si ambos láseres están libres.
			solved = _input_a and _input_b
		LogicMode.OR:
			# Resuelve si al menos un láser está libre.
			solved = _input_a or _input_b
		LogicMode.XOR:
			# Resuelve solo si exactamente uno está libre. Ambos a la vez = sobrecarga.
			if _input_a and _input_b:
				_trigger_overload()
				return
			solved = _input_a != _input_b

	if solved:
		_mark_solved()

# --- Resolución y penalización -----------------------------------------------

func _mark_solved() -> void:
	if _is_solved:
		return
	_is_solved = true
	set_physics_process(false)
	_show_message("PUZZLE RESUELTO")
	puzzle_solved.emit()
	# Avisa a la sala para que reabra las puertas, si el puzzle vive dentro de una.
	var room := _find_room()
	if room:
		room.complete_puzzle()

## Sobrecarga XOR: ambos haces activos a la vez. No resuelve; penaliza al jugador.
func _trigger_overload() -> void:
	_show_message("SOBRECARGA: XOR")
	puzzle_overloaded.emit()
	trigger_trap_or_enemies()

## Penalización configurable. Por defecto pide a la sala una oleada extra de
## enemigos; si el puzzle corre fuera de una sala, simplemente no hace nada.
func trigger_trap_or_enemies() -> void:
	var room := _find_room()
	if room:
		room.spawn_penalty_wave()

# --- Feedback y utilidades de escena -----------------------------------------

## Muestra en la UI la compuerta lógica actual. La llama la sala al entrar a ella.
func show_gate_hint() -> void:
	_show_message(_gate_label())

func _gate_label() -> String:
	match _current_mode:
		LogicMode.AND:
			return "COMPUERTA: AND"
		LogicMode.OR:
			return "COMPUERTA: OR"
		LogicMode.XOR:
			return "COMPUERTA: XOR"
	return "COMPUERTA"

## Sube por el árbol hasta encontrar la sala (RoomLayout) que contiene el puzzle.
func _find_room() -> RoomLayout:
	var node: Node = get_parent()
	while node != null and not (node is RoomLayout):
		node = node.get_parent()
	return node as RoomLayout

## Envía el texto de retroalimentación al Label de la UI del jugador. Si no se
## encuentra al jugador (puzzle fuera de una partida), simplemente no muestra nada.
func _show_message(text: String) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message(text)
