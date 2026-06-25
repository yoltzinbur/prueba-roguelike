extends Node2D

@onready var interaction_area = $InteractionArea
signal door_interacted

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
	if GameManager:
		GameManager.load_scene("res://Stages/Layouts/Cave/Layout1.tscn")
