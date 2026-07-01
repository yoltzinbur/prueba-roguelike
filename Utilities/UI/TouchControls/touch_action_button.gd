class_name TouchActionButton
extends Button
## Botón táctil multitáctil que acciona una acción del InputMap mientras se
## mantiene pulsado.
##
## No usamos la pulsación NATIVA del Button porque depende de la emulación de
## ratón de Godot, que solo sigue UN dedo: con el joystick activo (primer dedo),
## un segundo dedo sobre un botón no generaba evento y la acción no se detectaba
## (no podías moverte y atacar a la vez). Por eso leemos los InputEventScreenTouch
## directamente —igual que el joystick— y soportamos varios dedos simultáneos.

## Acción del InputMap a accionar (p. ej. "attack", "parry", "dodge", "heal",
## "enter", "reset", "pause", "map").
@export var action: StringName = &""

# "Punteros" especiales: ninguno activo y ratón (para probar en el editor).
const _NINGUNO: int = -1000
const _RATON: int = -500

# Índice del dedo (o _RATON) que mantiene pulsado el botón; _NINGUNO = libre.
var _puntero: int = _NINGUNO
# Estilos cacheados para pintar el estado pulsado a mano: con mouse_filter IGNORE
# el Button no gestiona su propio dibujo de pulsación.
var _estilo_normal: StyleBox
var _estilo_pulsado: StyleBox

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	# El Button no debe procesar ratón/foco por su cuenta: gestionamos el toque
	# nosotros para soportar multitouch real.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo_normal = get_theme_stylebox("normal")
	_estilo_pulsado = get_theme_stylebox("pressed")
	# Los botones contextuales (mapa/reset) se ocultan según el lugar. Un botón oculto
	# no debe capturar toques ni dejar su acción "pegada" si se oculta mientras se pulsa.
	visibility_changed.connect(_on_visibility_changed)

func _input(event: InputEvent) -> void:
	# Un botón oculto (p. ej. mapa fuera de la cueva, reset fuera de un puzzle) no
	# procesa toques: su rect no debe capturar pulsaciones fantasma en pantalla.
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _puntero == _NINGUNO and get_global_rect().has_point(event.position):
				_presionar(event.index)
				get_viewport().set_input_as_handled()
		elif event.index == _puntero:
			_soltar()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Solo para probar con ratón en el editor/escritorio.
		if event.pressed:
			if _puntero == _NINGUNO and get_global_rect().has_point(event.position):
				_presionar(_RATON)
				get_viewport().set_input_as_handled()
		elif _puntero == _RATON:
			_soltar()
			get_viewport().set_input_as_handled()

func _presionar(indice: int) -> void:
	_puntero = indice
	if action != &"":
		Input.action_press(action)
	_mostrar_pulsado(true)

func _soltar() -> void:
	_puntero = _NINGUNO
	if action != &"" and Input.is_action_pressed(action):
		Input.action_release(action)
	_mostrar_pulsado(false)

## Intercambia el StyleBox "normal" (el único que dibuja el Button al ser IGNORE)
## para reflejar visualmente la pulsación.
func _mostrar_pulsado(pulsado: bool) -> void:
	add_theme_stylebox_override("normal", _estilo_pulsado if pulsado else _estilo_normal)

## Si el botón se oculta mientras estaba pulsado, suéltalo para no dejar la acción
## activa (p. ej. el jugador resuelve el puzzle y el botón de reset desaparece).
func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _puntero != _NINGUNO:
		_soltar()

func _exit_tree() -> void:
	# Si el botón desaparece mientras está pulsado, no dejes la acción activa.
	if action != &"" and Input.is_action_pressed(action):
		Input.action_release(action)
