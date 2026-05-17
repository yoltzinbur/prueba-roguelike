class_name VelocityComponent
extends Node

@export var speed: float

@onready var target: CharacterBody2D = get_parent()

func move(delta: float, direction: Vector2) -> void:
	if direction:
		target.velocity.x = move_toward(target.velocity.x, direction.x * speed, speed)
		target.velocity.y = move_toward(target.velocity.y, direction.y * speed, speed)
	else: 
		target.velocity.x = move_toward(target.velocity.x, 0, speed)
		target.velocity.y = move_toward(target.velocity.y, 0, speed)
		
	target.move_and_slide()
