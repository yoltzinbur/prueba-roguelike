class_name VelocityComponent
extends Node

@export var speed: float

@onready var target: CharacterBody2D = get_parent()
@onready var separation_area: Area2D = $"../Area2D"


func move(delta: float, direction: Vector2) -> void:
	if direction:
		target.velocity.x = move_toward(target.velocity.x, direction.x * speed, speed)
		target.velocity.y = move_toward(target.velocity.y, direction.y * speed, speed)
	else: 
		target.velocity.x = move_toward(target.velocity.x, 0, speed)
		target.velocity.y = move_toward(target.velocity.y, 0, speed)
		
	target.move_and_slide()

func get_separation_vector() -> Vector2:
	var separation_vector := Vector2.ZERO
	var overlapping_bodies = separation_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body != get_parent() and body.is_in_group("Enemy"):
			separation_vector += get_parent().global_position - body.global_position
	
	return separation_vector.normalized()
