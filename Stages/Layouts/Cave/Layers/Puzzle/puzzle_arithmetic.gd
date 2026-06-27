class_name PuzzleArithmetic
extends Node2D
## Lógica global del tercer puzzle: aritmética modular. La sala tiene 5 interruptores
## (Interrupter) con un valor entero aleatorio cada uno. El jugador enciende/apaga
## interruptores; la SUMA de los valores ACTIVOS debe ser múltiplo del módulo M
## (residuo 0) y mayor que 0 en el momento de la validación periódica.
##
## El puzzle NO se resuelve solo al llegar a residuo 0: hay un temporizador en la UI
## que, al expirar, valida. Si el residuo es 0 (y la suma > 0) se gana; si no, la
## penalización escala con el residuo (esa cantidad de oleadas de enemigos). Las
## oleadas presionan desde que el jugador entra a la sala.

## Emitida cuando el puzzle se resuelve correctamente (la sala reabre las puertas).
signal puzzle_solved

## Módulo (divisor) de la sala: la suma activa debe ser múltiplo de este valor.
@export var modulo: int = 5
## Segundos entre cada validación automática del puzzle.
@export var validation_interval: int = 10

# La cuenta regresiva en la UI solo aparece en los últimos segundos, para no saturar
# el mensaje del jugador y dejar que el aviso inicial se vea completo.
const COUNTDOWN_VISIBLE_FROM: int = 5

# Rango de valores aleatorios asignados a cada interruptor.
const MIN_VALUE: int = 1
const MAX_VALUE: int = 9

const LABEL_FONT := preload("res://Assets/Fonts/Minecraft.ttf")

var _interrupters: Array[Interrupter] = []
var _active_sum: int = 0
var _is_solved: bool = false
var _seconds_left: int = 0

@onready var interaction_objects: Node2D = $InteractionObjects

var _residue_label: Label
var _tick_timer: Timer

func _ready() -> void:
	_setup_residue_label()
	_init_interrupters()
	_recalculate()
	# El temporizador de validación NO arranca aquí (el _ready corre al generarse la
	# sala): lo inicia la sala con begin() cuando el jugador entra, y lo pausa con
	# halt() al salir, para no validar ni mostrar mensajes con el jugador ausente.

# --- Inicialización ----------------------------------------------------------

## Asigna a cada interruptor un valor aleatorio, conecta su señal de cambio y los
## indexa para recalcular la suma en tiempo real.
func _init_interrupters() -> void:
	for child in interaction_objects.get_children():
		if child is Interrupter:
			child.set_value(_random_value())
			child.interrupter_changed.connect(_on_interrupter_changed)
			_interrupters.append(child)

## Devuelve un valor aleatorio en [MIN_VALUE, MAX_VALUE] que NO sea múltiplo del
## módulo: un múltiplo no aportaría nada al residuo y sería un interruptor "muerto"
## (p. ej. el 5 con módulo 5). Si no quedara ningún valor válido, cae al rango completo.
func _random_value() -> int:
	var pool: Array[int] = []
	for v in range(MIN_VALUE, MAX_VALUE + 1):
		if modulo <= 0 or v % modulo != 0:
			pool.append(v)
	if pool.is_empty():
		return randi_range(MIN_VALUE, MAX_VALUE)
	return pool.pick_random()

## Resuelve la etiqueta del residuo dentro del CanvasLayer del puzzle, la centra en
## la parte superior de la pantalla (sin chocar con la barra de vida) y la deja
## OCULTA hasta que la sala llame a begin(); así no se muestra el residuo de salas
## donde el jugador no está, ni se enciman varias del mismo puzzle.
func _setup_residue_label() -> void:
	_residue_label = _resolve_residue_label()
	if _residue_label == null:
		return
	var settings := LabelSettings.new()
	settings.font = LABEL_FONT
	settings.font_size = 16
	_residue_label.label_settings = settings
	# Centrado arriba: ancho completo y alineación centrada.
	_residue_label.anchor_left = 0.0
	_residue_label.anchor_right = 1.0
	_residue_label.offset_left = 0.0
	_residue_label.offset_right = 0.0
	_residue_label.offset_top = 8.0
	_residue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_residue_label.visible = false

## Busca la etiqueta "Message" bajo el CanvasLayer del puzzle. Admite la estructura
## nueva (CanvasLayer/Message) y la anterior (Control/CanvasLayer); si "Message" es
## un componente con un Label hijo, usa ese; y si no hay nada, crea un Label.
func _resolve_residue_label() -> Label:
	var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		canvas = get_node_or_null("Control/CanvasLayer") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)
	var node := canvas.get_node_or_null("Message")
	if node is Label:
		return node
	if node != null:
		var inner := node.get_node_or_null("Message") as Label
		if inner:
			return inner
	var label := Label.new()
	label.name = "Message"
	canvas.add_child(label)
	return label

# --- Suma y residuo en tiempo real -------------------------------------------

func _on_interrupter_changed(_is_on: bool) -> void:
	_recalculate()

## Recalcula la suma de los interruptores activos y refresca el residuo en la UI.
func _recalculate() -> void:
	var sum := 0
	for interrupter in _interrupters:
		if interrupter.is_on:
			sum += interrupter.value
	_active_sum = sum
	_update_residue_label()

func _update_residue_label() -> void:
	if _residue_label == null:
		return
	# Sin interruptores activos (inicio): muestra "--" en lugar de 0.
	if _active_sum == 0:
		_residue_label.text = "Residuo: --"
	else:
		_residue_label.text = "Residuo: %d" % _residue()

func _residue() -> int:
	if modulo <= 0:
		return 0
	return _active_sum % modulo

# --- Temporizador de validación ----------------------------------------------

## API pública (la llama la sala al entrar el jugador): arranca/reinicia el
## temporizador que valida el puzzle cada cierto tiempo, mostrando la cuenta
## regresiva en la UI del jugador.
func begin() -> void:
	if _is_solved:
		return
	# Muestra el residuo solo mientras el jugador está en esta sala.
	if _residue_label:
		_residue_label.visible = true
	# Aviso inicial para dejar claro el objetivo del puzzle.
	_show_message("Obtén residuo 0", 3.0)
	_seconds_left = validation_interval
	if _tick_timer == null:
		_tick_timer = Timer.new()
		_tick_timer.wait_time = 1.0
		_tick_timer.timeout.connect(_on_tick)
		add_child(_tick_timer)
	_tick_timer.start()

## API pública (la llama la sala al salir el jugador): pausa la validación para no
## penalizar ni mostrar mensajes mientras el jugador no está en la sala.
func halt() -> void:
	# Oculta el residuo al salir (y pausa la validación).
	if _residue_label:
		_residue_label.visible = false
	if _tick_timer:
		_tick_timer.stop()

## Cada segundo descuenta el reloj de validación; al llegar a cero valida y reinicia
## (el proceso se repite hasta resolver el puzzle).
func _on_tick() -> void:
	if _is_solved:
		return
	_seconds_left -= 1
	if _seconds_left > 0:
		# Solo muestra la cuenta regresiva en los últimos segundos.
		if _seconds_left <= COUNTDOWN_VISIBLE_FROM:
			_show_message("Validación en: %ds" % _seconds_left, 1.5)
	else:
		_validate()
		_seconds_left = validation_interval

# --- Validación, victoria y penalización -------------------------------------

## Evalúa el puzzle: gana si el residuo es 0 con suma positiva; si el residuo no es
## cero, penaliza con tantas oleadas como indique el residuo.
func _validate() -> void:
	if _is_solved:
		return
	var residue := _residue()
	if _active_sum > 0 and residue == 0:
		_mark_solved()
	elif residue != 0:
		_show_message("RESIDUO %d: ¡enemigos!" % residue, 2.0)
		_apply_penalty(residue)
	else:
		# Suma 0 (todos apagados): ni victoria ni penalización.
		_show_message("Enciende interruptores", 1.5)

## La severidad de la penalización escala con el residuo: spawnea esa cantidad de
## enemigos (no oleadas enteras), para no acumular demasiados de golpe.
func _apply_penalty(severity: int) -> void:
	var room := _find_room()
	if room == null:
		return
	room.spawn_penalty_enemies(severity)

func _mark_solved() -> void:
	if _is_solved:
		return
	_is_solved = true
	if _tick_timer:
		_tick_timer.stop()
	# Bloquea los interruptores para que el jugador no pueda alterar la solución.
	for interrupter in _interrupters:
		interrupter.lock()
	_show_message("PUZZLE RESUELTO", 3.0)
	puzzle_solved.emit()
	# Avisa a la sala para que reabra las puertas, si el puzzle vive dentro de una.
	var room := _find_room()
	if room:
		room.complete_puzzle()

# --- Utilidades de escena ----------------------------------------------------

## Sube por el árbol hasta encontrar la sala (RoomLayout) que contiene el puzzle.
func _find_room() -> RoomLayout:
	var node: Node = get_parent()
	while node != null and not (node is RoomLayout):
		node = node.get_parent()
	return node as RoomLayout

## Envía texto a la UI del jugador. Si no se encuentra (puzzle fuera de partida),
## simplemente no muestra nada.
func _show_message(text: String, duration: float = 3.0) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message(text, duration)
