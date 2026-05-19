class_name VelocityComponent
extends Node

@export var speed: float

@onready var target: CharacterBody2D = get_parent()

var separation_area: Area2D = null
var nav_agent: NavigationAgent2D = null

func _ready() -> void:
	if target.is_in_group("Enemy"):
		separation_area = $"../Area2D"
		nav_agent = $"../NavigationComponent/NavigationAgent2D"
	
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)

func move(delta: float, direction: Vector2) -> void:
	var target_velocity := Vector2.ZERO
	
	if direction:
		target_velocity = direction * speed
	
	if nav_agent and nav_agent.avoidance_enabled and nav_agent.get_navigation_map() != RID():
		nav_agent.set_velocity_forced(target_velocity)
	else:
		_apply_movement(target_velocity)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var separation = Vector2.ZERO
	if separation_area:
		separation = get_separation_vector() * (speed * 0.5)
	
	var final_velocity = safe_velocity + separation
	_apply_movement(final_velocity)

func _apply_movement(velocity_to_apply: Vector2) -> void:
	target.velocity.x = move_toward(target.velocity.x, velocity_to_apply.x, speed)
	target.velocity.y = move_toward(target.velocity.y, velocity_to_apply.y, speed)
	target.move_and_slide()

func get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
	
	if not get_parent() or not is_instance_valid(get_parent()):
		return Vector2.ZERO
	
	var separation_vector := Vector2.ZERO
	var overlapping_bodies = separation_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body != get_parent() and body.is_in_group("Enemy"):
			separation_vector += get_parent().global_position - body.global_position
	
	return separation_vector.normalized()
