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
