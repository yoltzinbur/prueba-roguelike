class_name PuzzleStackQueue
extends Node2D
## Lógica global del puzzle de Pila/Cola. Un callejón estrecho con tres placas de
## presión consecutivas (PressurePlate, PressurePlate2, PressurePlate3) dentro de
## 'InteractionObjects'. Según el modo elegido al azar al instanciarse:
##   - STACK (Pila): el jugador empuja las 3 cajas sobre las 3 placas; al colocar
##     la última se valida el orden temporal de colocación.
##   - QUEUE (Cola): solo la primera placa actúa como "tubería"; cada caja que la
##     pisa se identifica, se encola y se elimina, validando la secuencia al vuelo.

## Emitida cuando el puzzle se resuelve correctamente.
signal puzzle_solved
## Emitida cuando la secuencia es incorrecta (antes de reiniciar la sala).
signal puzzle_failed

enum PuzzleMode { STACK, QUEUE }

## Modo de juego. Se sortea en _ready() la primera vez para que cada instancia
## sea distinta; el valor del inspector solo actúa como defecto. En los reinicios
## la sala vuelve a fijarlo con apply_fixed_mode() para conservar la naturaleza.
@export var mode: PuzzleMode = PuzzleMode.STACK

## Orden objetivo expresado con los tipos de caja. Se baraja al azar en _ready()
## la primera vez para que cada instancia exija una secuencia distinta; en los
## reinicios la sala vuelve a fijarlo con apply_fixed_config() para no cambiar el
## reto a mitad de partida.
var target_order: Array[String] = ["Fuego", "Hielo", "Rayo"]
## Orden acumulado por el jugador durante la partida.
var current_order: Array[String] = []

## Mapeo del nombre del nodo de cada caja (según la escena) a su tipo lógico.
const BOX_TYPES: Dictionary = {
	"Box": "Fuego",
	"Box2": "Hielo",
	"Box3": "Rayo",
}

## Fuente compartida por las etiquetas flotantes de las cajas, para mantener el
## estilo pixel-art del resto de la UI.
const LABEL_FONT := preload("res://Assets/Fonts/Minecraft.ttf")

@onready var plate_1: PressurePlate = $InteractionObjects/PressurePlate
@onready var plate_2: PressurePlate = $InteractionObjects/PressurePlate2
@onready var plate_3: PressurePlate = $InteractionObjects/PressurePlate3

# Tipo de caja registrado actualmente sobre cada placa (modo STACK).
var _plate_contents: Dictionary = {}
var _is_solved: bool = false

# Cuando la sala impone la configuración (en un reinicio), se evita re-sortearla.
var _config_fixed: bool = false

func _ready() -> void:
	# Solo se sortean modo y orden en la primera instanciación. En los reinicios la
	# sala ya los ha fijado con apply_fixed_config(), conservando el reto original.
	if not _config_fixed:
		_randomize_mode()
		_randomize_order()

	# Conecta las tres placas pasando la propia placa como argumento extra.
	plate_1.plate_activated.connect(_on_plate_activated.bind(plate_1))
	plate_2.plate_activated.connect(_on_plate_activated.bind(plate_2))
	plate_3.plate_activated.connect(_on_plate_activated.bind(plate_3))

	# En modo Cola solo la primera placa funciona: las otras dos se desactivan.
	if mode == PuzzleMode.QUEUE:
		_disable_plate(plate_2)
		_disable_plate(plate_3)

	# Identifica cada caja con su elemento, ya que no hay diferencia visual entre ellas.
	_create_box_labels()

## Elige STACK o QUEUE al azar. Solo se llama en la primera instanciación.
func _randomize_mode() -> void:
	mode = PuzzleMode.STACK if randi() % 2 == 0 else PuzzleMode.QUEUE

## Baraja la secuencia objetivo. Solo se llama en la primera instanciación.
func _randomize_order() -> void:
	target_order.shuffle()

## Fija modo y orden desde fuera (la sala) ANTES de añadir el nodo al árbol, de
## modo que _ready() no vuelva a sortearlos. Así un reinicio conserva el reto
## (naturaleza Pila/Cola y secuencia) elegido en la primera instanciación.
func apply_fixed_config(fixed_mode: PuzzleMode, fixed_order: Array[String]) -> void:
	mode = fixed_mode
	target_order = fixed_order.duplicate()
	_config_fixed = true

# --- Despacho de señales -----------------------------------------------------

func _on_plate_activated(activated: bool, plate: PressurePlate) -> void:
	if _is_solved:
		return
	match mode:
		PuzzleMode.STACK:
			_handle_stack(activated, plate)
		PuzzleMode.QUEUE:
			_handle_queue(activated, plate)

# --- Modo PILA (STACK) -------------------------------------------------------

## Acumula el tipo de la caja al activarse la placa y lo retira al liberarse.
## Cuando las tres placas tienen caja, valida el orden de colocación.
func _handle_stack(activated: bool, plate: PressurePlate) -> void:
	if activated:
		var box := _get_box_on_plate(plate)
		if box == null:
			return  # Probablemente fue el jugador quien pisó la placa.
		var box_type := _get_box_type(box)
		_plate_contents[plate] = box_type
		current_order.append(box_type)
	else:
		if _plate_contents.has(plate):
			current_order.erase(_plate_contents[plate])
			_plate_contents.erase(plate)

	# Evalúa solo cuando las tres cajas están colocadas.
	if current_order.size() == target_order.size():
		if not check_puzzle():
			_show_message("ORDEN INCORRECTO")
			puzzle_failed.emit()
			_reset_room()

# --- Modo COLA (QUEUE) -------------------------------------------------------

## Cada caja que pisa la primera placa se encola, se elimina y se valida contra
## el índice correspondiente de target_order de forma inmediata.
func _handle_queue(activated: bool, plate: PressurePlate) -> void:
	if not activated or plate != plate_1:
		return

	var box := _get_box_on_plate(plate)
	if box == null:
		return

	var box_type := _get_box_type(box)
	current_order.append(box_type)
	box.queue_free()  # Despeja el camino inmediatamente.

	var index := current_order.size() - 1
	# 1) ¿Coincide con el tipo esperado en este índice?
	if index >= target_order.size() or current_order[index] != target_order[index]:
		_show_message("SECUENCIA ERRONEA")
		puzzle_failed.emit()
		_reset_room()
		return

	# 2) Si coincide y se completó la longitud, validar victoria.
	if current_order.size() == target_order.size():
		check_puzzle()

# --- Validación --------------------------------------------------------------

## Comprueba el estado global: si el orden acumulado iguala al objetivo, marca el
## puzzle como resuelto y emite la señal. Devuelve true si está resuelto.
func check_puzzle() -> bool:
	if current_order == target_order:
		_mark_solved()
		return true
	return false

func _mark_solved() -> void:
	if _is_solved:
		return
	_is_solved = true
	_show_message("PUZZLE RESUELTO")
	puzzle_solved.emit()
	# Avisa a la sala para que reabra las puertas, si el puzzle vive dentro de una.
	var room := _find_room()
	if room:
		room.complete_puzzle()

# --- Utilidades de escena ----------------------------------------------------

## Devuelve la primera Box que solapa el área de la placa (ignora al jugador).
func _get_box_on_plate(plate: PressurePlate) -> Box:
	for body in plate.interaction_area.get_overlapping_bodies():
		if body is Box:
			return body
	return null

## Traduce el nombre del nodo de la caja a su tipo lógico.
func _get_box_type(box: Box) -> String:
	return BOX_TYPES.get(box.name, "")

## Desactiva una placa (oculta y sin colisión) para los modos que no la usan.
func _disable_plate(plate: PressurePlate) -> void:
	plate.visible = false
	plate.interaction_area.set_deferred("monitoring", false)
	var shape := plate.interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)

## Sube por el árbol hasta encontrar la sala (RoomLayout) que contiene el puzzle.
func _find_room() -> RoomLayout:
	var node: Node = get_parent()
	while node != null and not (node is RoomLayout):
		node = node.get_parent()
	return node as RoomLayout

func _reset_room() -> void:
	var room := _find_room()
	if room:
		room.reset_current_puzzle()

## Envía el texto de retroalimentación al Label fijo de la UI del jugador, que
## permanece unos segundos en pantalla y luego desaparece. Si no se encuentra al
## jugador (puzzle fuera de una partida), simplemente no muestra nada.
func _show_message(text: String) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message(text)

## Muestra momentáneamente en la UI el orden de elementos que el jugador debe
## seguir. La llama la sala al entrar y tras cada reinicio.
func show_order_hint() -> void:
	_show_message("Orden: " + " > ".join(target_order))

## Crea un Label flotante por encima de cada caja con su elemento, para que el
## jugador pueda distinguirlas (todas comparten el mismo sprite).
func _create_box_labels() -> void:
	var settings := LabelSettings.new()
	settings.font = LABEL_FONT
	settings.font_size = 8
	for box_name in BOX_TYPES:
		var box := get_node_or_null("InteractionObjects/" + box_name) as Node2D
		if box == null:
			continue
		var label := Label.new()
		label.text = BOX_TYPES[box_name]
		label.label_settings = settings
		label.position = Vector2(-6.0, -12.0)
		box.add_child(label)
