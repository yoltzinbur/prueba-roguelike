extends Node2D

@onready var interaction_area = $InteractionArea
signal door_interacted

var player_present: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_present = true
		# Aquí puedes mostrar un indicador visual ("Presiona Enter")

func _on_body_exited(body):
	if body.name == "Player":
		player_present = false
		# Ocultar indicador visual

func _process(_delta):
	# Si el jugador está en el área y presiona la tecla asignada a "enter"
	if player_present and Input.is_action_just_pressed("enter"):
		open_door()

func open_door():
	emit_signal("door_interacted")
	if GameManager:
		GameManager.load_scene("res://Stages/Main/Main.tscn")
