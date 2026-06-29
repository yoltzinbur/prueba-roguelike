extends CharacterBody2D

var current_interactable: Node = null
var current_room: Node = null

# Identifica el último mensaje pedido para que un temporizador antiguo no oculte
# un mensaje más reciente.
var _message_token: int = 0

# --- Parry / Guard Break ---------------------------------------------------
## Reflejos necesarios para provocar un Guard Break.
const REFLECTS_PER_BREAK := 3
## Multiplicador de daño del golpe crítico durante la ventana de Guard Break.
@export var crit_multiplier: int = 5
## Duración del aturdimiento del jefe y de la ventana de crítico, en segundos.
@export var guard_break_seconds: float = 3.0

# Proyectiles reflejados acumulados y fin (ms) de la ventana de crítico activa.
var _reflect_count: int = 0
var _crit_until: float = 0.0

@onready var input_component: InputComponent = $InputComponent
## Componente de vida del jugador, expuesto para que otros sistemas (p. ej. la
## fogata) no dependan del nombre/ruta interna del nodo.
@onready var health_component: HealthComponent = $HealthComponent
@onready var message_label: Label = $UI/Message.get_node("Message")

# Contador de puzzles del nivel (instancia de PuzzlesCounter.tscn bajo UI). Lo
# controla el administrador del nivel a través de la API pública de este script.
@onready var _puzzle_counter: Control = $UI/PuzzlesCounter
@onready var _puzzle_counter_label: Label = _puzzle_counter.get_node_or_null("Label") if _puzzle_counter else null

func _ready() -> void:
	# El Label arranca vacío y oculto; solo aparece al pedir un mensaje.
	message_label.text = ""
	message_label.visible = false
	# El contador arranca oculto: solo se muestra dentro de un nivel procedural.
	if _puzzle_counter:
		_puzzle_counter.visible = false

func _process(_delta: float) -> void:
	if input_component.input_action and current_interactable:
		current_interactable.interact()

	if input_component.input_reset and current_room:
		current_room.reset_current_puzzle()

## Muestra un mensaje en el Label fijo de la UI durante 'duration' segundos y
## luego lo oculta. Llamadas sucesivas reinician el temporizador.
func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	message_label.visible = true
	_message_token += 1
	var token := _message_token
	await get_tree().create_timer(duration).timeout
	# Solo oculta si no llegó un mensaje más reciente mientras esperábamos.
	if token == _message_token:
		message_label.text = ""
		message_label.visible = false

## Restaura por completo al jugador: vida al máximo y frascos al tope indicado.
## La usan los interactuables de descanso (fogata) sin tocar el HealthComponent
## directamente.
func curar_completo(max_frascos: int) -> void:
	if health_component == null:
		return
	health_component.current_health = health_component.MAX_HEALTH
	health_component.flasks = max_frascos

## Llamada por el estado Parry cada vez que se refleja un proyectil con éxito. Cada
## REFLECTS_PER_BREAK reflejos provoca un Guard Break (aturde al jefe + abre el crítico).
func on_projectile_reflected() -> void:
	_reflect_count += 1
	if _reflect_count % REFLECTS_PER_BREAK == 0:
		_trigger_guard_break()
	else:
		show_message("¡Reflejado!", 1.0)

## Abre la ventana de crítico y aturde al jefe durante guard_break_seconds.
func _trigger_guard_break() -> void:
	_crit_until = Time.get_ticks_msec() + guard_break_seconds * 1000.0
	show_message("¡Guard Break!", guard_break_seconds)
	var boss := get_tree().get_first_node_in_group("Boss")
	if boss and boss.has_method("stun"):
		boss.stun(guard_break_seconds)

## Devuelve el multiplicador de daño para el próximo golpe: si hay ventana de crítico activa,
## la consume y devuelve crit_multiplier; si no, devuelve 1. La usan los estados de ataque.
func consume_crit_multiplier() -> int:
	if Time.get_ticks_msec() < _crit_until:
		_crit_until = 0.0
		return crit_multiplier
	return 1

## Muestra u oculta el contador de puzzles del nivel.
func mostrar_contador_puzzles(visible: bool) -> void:
	if _puzzle_counter:
		_puzzle_counter.visible = visible

## Actualiza el texto del contador de puzzles ("Puzzles: X / Y").
func actualizar_contador_puzzles(completados: int, total: int) -> void:
	if _puzzle_counter_label:
		_puzzle_counter_label.text = "Puzzles: %d / %d" % [completados, total]
