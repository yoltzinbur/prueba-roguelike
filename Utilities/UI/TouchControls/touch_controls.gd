class_name TouchControls
extends CanvasLayer
## Capa de controles táctiles en pantalla para la exportación a APK.
##
## Agrupa el joystick virtual y los botones de acción (parry, ataque, dodge,
## heal, reset) más los botones de pausa y mapa. Cada control acciona
## directamente una acción del InputMap, por lo que se puede soltar en cualquier
## escena de juego sin cablear nada: el jugador y los menús ya leen esas acciones.

## Si está activo, los controles se muestran siempre (útil para depurar en escritorio).
@export var force_visible: bool = false

# Identificador de sala de puzzle (alineado con RoomLayout.ROOM_TYPE_PUZZLE).
const ROOM_TYPE_PUZZLE := "Puzzle"

# Botones dependientes del contexto: el de mapa solo sirve en la cueva procedural
# y el de reset solo dentro de una sala de puzzle sin resolver.
@onready var _map_button: Button = $Map
@onready var _reset_button: Button = $Actions/Reset

func _ready() -> void:
	# Visibles en dispositivos táctiles y dentro del editor (para probar con
	# ratón); ocultos en builds de escritorio sin pantalla táctil.
	var mostrar := force_visible or DisplayServer.is_touchscreen_available() or OS.has_feature("editor")
	visible = mostrar
	# Si se muestran, deben seguir procesando input AUNQUE el juego esté en pausa
	# (para poder cerrar el mapa o el menú de pausa desde los botones táctiles).
	# Si no se muestran, se deshabilitan por completo para no captar clics fantasma
	# en escritorio sin pantalla táctil.
	process_mode = Node.PROCESS_MODE_ALWAYS if mostrar else Node.PROCESS_MODE_DISABLED

## Refresca cada frame la visibilidad de los botones contextuales. Es barato (un par
## de comprobaciones) y sobrevive a los cambios de escena y de sala sin cablear señales.
func _process(_delta: float) -> void:
	if _map_button:
		_map_button.visible = _en_cueva_procedural()
	if _reset_button:
		_reset_button.visible = _en_sala_puzzle()

## True si la escena actual es un nivel procedural con mapa descubrible (expone `map`,
## igual que comprueba map_overlay.gd). Solo ahí el botón de mapa tiene sentido.
func _en_cueva_procedural() -> bool:
	var scene := get_tree().current_scene
	return scene != null and "map" in scene

## True si el jugador está dentro de una sala de tipo Puzzle todavía sin resolver, que
## es el único contexto donde el botón de reset hace algo (reset_current_puzzle()).
func _en_sala_puzzle() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	var room = player.current_room
	if room == null or not is_instance_valid(room):
		return false
	if not ("room_type" in room) or room.room_type != ROOM_TYPE_PUZZLE:
		return false
	# Ya resuelta: las puertas están abiertas y reiniciar no haría nada.
	return not ("is_puzzled_cleared" in room) or not room.is_puzzled_cleared
