extends CharacterBody2D

var current_interactable: Node = null
var current_room: Node = null

# Identifica el último mensaje pedido para que un temporizador antiguo no oculte
# un mensaje más reciente.
var _message_token: int = 0

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

## Muestra u oculta el contador de puzzles del nivel.
func mostrar_contador_puzzles(visible: bool) -> void:
	if _puzzle_counter:
		_puzzle_counter.visible = visible

## Actualiza el texto del contador de puzzles ("Puzzles: X / Y").
func actualizar_contador_puzzles(completados: int, total: int) -> void:
	if _puzzle_counter_label:
		_puzzle_counter_label.text = "Puzzles: %d / %d" % [completados, total]
