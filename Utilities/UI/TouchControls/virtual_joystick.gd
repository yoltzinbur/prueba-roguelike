class_name VirtualJoystick
extends Control
## Joystick virtual para controles táctiles (exportación a APK).
##
## Traduce el arrastre del dedo a las acciones direccionales del InputMap
## (left/right/up/down) usando Input.action_press con intensidad analógica.
## Como PlayerInputComponent lee Input.get_vector("left","right","up","down"),
## el jugador se mueve sin necesidad de modificar su lógica.
##
## Solo toca el InputMap mientras el dedo está sobre el joystick, de modo que en
## escritorio el teclado (WASD/flechas) sigue funcionando con normalidad.

## Radio máximo (px) que recorre la perilla desde el centro.
@export var radius: float = 60.0
## Fracción del radio bajo la cual no se emite movimiento (zona muerta local).
@export var dead_zone: float = 0.2
## Escalado de la velocidad analógica: >1 hace que el jugador alcance la velocidad
## máxima con menos recorrido del dedo (la respuesta sube más rápido).
@export var sensibilidad: float = 1.6
@export var base_color: Color = Color(1, 1, 1, 0.16)
@export var base_border_color: Color = Color(1, 1, 1, 0.35)
@export var knob_color: Color = Color(1, 1, 1, 0.55)

const ACCIONES: Array[StringName] = [&"left", &"right", &"up", &"down"]
# Índice reservado para el ratón (pruebas en el editor); los toques usan índices >= 0.
const RATON_INDEX: int = -2

var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
# Índice del dedo que controla el joystick; -1 = inactivo.
var _touch_index: int = -1

func _ready() -> void:
	_recenter()
	resized.connect(_recenter)

func _recenter() -> void:
	_center = size * 0.5
	_knob = _center
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_drag_to(event.position)
				accept_event()
		elif event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag_to(event.position)
		accept_event()
	# Soporte de ratón para poder probar el joystick en el editor.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _touch_index == -1:
			_touch_index = RATON_INDEX
			_drag_to(event.position)
			accept_event()
		elif not event.pressed and _touch_index == RATON_INDEX:
			_release()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == RATON_INDEX:
		_drag_to(event.position)
		accept_event()

## Mueve la perilla a la posición (local) tocada y vuelca el vector en el InputMap.
func _drag_to(local_pos: Vector2) -> void:
	var offset := local_pos - _center
	var dist := offset.length()
	if dist > radius:
		offset = offset.normalized() * radius
		dist = radius
	_knob = _center + offset

	var output := Vector2.ZERO
	var raw := dist / radius  # 0..1 según lo lejos del centro que esté el dedo
	if raw >= dead_zone:
		# Remapea fuera de la zona muerta (0..1) y aplica la sensibilidad: el
		# jugador llega antes a la velocidad máxima sin perder la dirección.
		var magnitud := (raw - dead_zone) / (1.0 - dead_zone)
		magnitud = clampf(magnitud * sensibilidad, 0.0, 1.0)
		output = offset.normalized() * magnitud

	_set_axis(&"right", &"left", output.x)
	_set_axis(&"down", &"up", output.y)
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_knob = _center
	for accion in ACCIONES:
		Input.action_release(accion)
	queue_redraw()

## Acciona la dirección positiva o negativa de un eje con intensidad analógica,
## liberando la opuesta para no dejar acciones "pegadas".
func _set_axis(pos: StringName, neg: StringName, value: float) -> void:
	if value > 0.0:
		Input.action_release(neg)
		Input.action_press(pos, value)
	elif value < 0.0:
		Input.action_release(pos)
		Input.action_press(neg, -value)
	else:
		Input.action_release(pos)
		Input.action_release(neg)

func _exit_tree() -> void:
	# Evita dejar el movimiento activo si el nodo se elimina a mitad de arrastre.
	for accion in ACCIONES:
		Input.action_release(accion)

func _draw() -> void:
	draw_circle(_center, radius, base_color)
	draw_arc(_center, radius, 0.0, TAU, 48, base_border_color, 3.0, true)
	draw_circle(_knob, radius * 0.45, knob_color)
