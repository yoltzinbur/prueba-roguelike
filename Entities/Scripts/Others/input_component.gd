class_name InputComponent
extends Node

var input_motion: Vector2:
	get:
		input_motion = Input.get_vector("left", "right", "up", "down")
		return input_motion
		
var input_action:
	get:
		input_action = Input.is_action_just_pressed("enter")
		return input_action
		
var input_attack:
	get:
		input_attack = Input.is_action_just_pressed("attack")
		return input_attack
		
var input_heal:
	get:
		input_heal = Input.is_action_just_pressed("heal")
		return input_heal
