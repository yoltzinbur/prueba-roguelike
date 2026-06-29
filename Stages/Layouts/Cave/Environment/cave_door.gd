extends Node2D

@onready var interaction_area = $InteractionArea
signal door_interacted

## Si es true, esta puerta cierra el nivel: cuenta el nivel vencido (+1 frasco),
## guarda y lleva al bosque. La usa la puerta de avance del Jefe (CaveDoor2). Las
## puertas normales (CaveDoor1) la dejan en false y recargan la cueva.
@export var completes_level: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.current_interactable = self

func _on_body_exited(body):
	if body.is_in_group("Player") and body.current_interactable == self:
		body.current_interactable = null

func interact() -> void:
	open()

func open():
	door_interacted.emit()
	if completes_level:
		SaveManager.complete_level()
		return
	if GameManager:
		GameManager.load_scene(GameScenes.STARTCAVE)
