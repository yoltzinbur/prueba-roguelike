class_name MessageUI
extends Control
## Message UI del jugador: avisos breves dentro de un panel oscuro semitransparente
## con esquinas redondeadas. En lugar de aparecer de golpe, el panel se DESLIZA hacia
## su sitio al entrar y se desliza de vuelta al salir, con un pequeño desvanecido.
##
## Expone la API pública show_message()/hide_message(); player.gd delega aquí, así que
## todos los avisos del juego (combate, guardado, jefe, pista del mapa) pasan por este
## mismo panel animado.

@onready var _panel: Panel = $Panel
@onready var _label: RichTextLabel = $Panel/Label

## Distancia (px) que recorre el panel al deslizarse hacia/desde su posición de reposo.
const SLIDE_DISTANCE: float = 14.0
## Duración de las transiciones de entrada y salida (segundos).
const SLIDE_IN_TIME: float = 0.35
const SLIDE_OUT_TIME: float = 0.25

# Posición de reposo del panel (la que tiene en el editor). La entrada parte de
# SLIDE_DISTANCE px por encima de esta y termina aquí; la salida hace lo inverso.
var _rest_position: Vector2

# Identifica el último mensaje pedido para que un temporizador antiguo no oculte un
# mensaje más reciente que llegó mientras esperábamos.
var _token: int = 0
# Tween activo de entrada/salida; se cancela al pedir un nuevo mensaje.
var _tween: Tween

func _ready() -> void:
	_rest_position = _panel.position
	# Arranca oculto: invisible, desplazado hacia arriba y sin ocupar la pantalla.
	_panel.modulate.a = 0.0
	_panel.position = _rest_position - Vector2(0.0, SLIDE_DISTANCE)
	_panel.visible = false

## Muestra `text` deslizando el panel hacia dentro y lo oculta tras `duration` segundos.
## Llamadas sucesivas reinician el texto y el temporizador (reanima la entrada).
func show_message(text: String, duration: float = 3.0) -> void:
	# Los mensajes pueden traer BBCode (íconos de botón). RichTextLabel no expone
	# alineación horizontal como propiedad, así que centramos con [center].
	_label.text = "[center]%s[/center]" % text
	_panel.visible = true
	_token += 1
	var token := _token
	_slide_in()
	await get_tree().create_timer(duration).timeout
	# Solo oculta si seguimos en escena y no llegó un mensaje más reciente.
	if token == _token and is_inside_tree():
		hide_message()

## Oculta el panel deslizándolo hacia arriba y desvaneciéndolo.
func hide_message() -> void:
	if not _panel.visible:
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position", _rest_position - Vector2(0.0, SLIDE_DISTANCE), SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Al terminar el desvanecido, deja de dibujarse para no ocupar la pantalla.
	_tween.chain().tween_callback(func() -> void: _panel.visible = false)

## Reanima la entrada: parte desde arriba y transparente, y llega a la posición de
## reposo opaco. El deslizamiento usa TRANS_BACK para un leve rebote al asentarse.
func _slide_in() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_panel.position = _rest_position - Vector2(0.0, SLIDE_DISTANCE)
	_panel.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position", _rest_position, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
