extends CharacterBody2D

var current_interactable: Node = null
var current_room: Node = null

# Identifica el último mensaje pedido para que un temporizador antiguo no oculte
# un mensaje más reciente.
var _message_token: int = 0

@onready var input_component: InputComponent = $InputComponent
@onready var message_label: Label = $UI/Message

func _ready() -> void:
	# El Label arranca vacío y oculto; solo aparece al pedir un mensaje.
	message_label.text = ""
	message_label.visible = false

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
