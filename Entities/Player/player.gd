extends CharacterBody2D

var current_interactable: Node = null

@onready var input_component: InputComponent = $InputComponent

func _process(_delta: float) -> void:
	if input_component.input_action and current_interactable:
		current_interactable.interact()
