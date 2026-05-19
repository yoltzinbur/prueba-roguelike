class_name PlayerInputComponent
extends InputComponent

func _process(delta: float) -> void:
	input_motion = Input.get_vector("left", "right", "up", "down")
	input_attack = Input.is_action_just_pressed("attack")
	input_heal = Input.is_action_just_pressed("heal")
	input_action = Input.is_action_just_pressed("enter")
