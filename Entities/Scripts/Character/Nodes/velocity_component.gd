class_name VelocityComponent
extends Node

@export var speed: float

@onready var target: CharacterBody2D = get_parent()

var separation_area: Area2D = null
var nav_agent: NavigationAgent2D = null

func _ready() -> void:
	if target.is_in_group("Enemy"):
		separation_area = $"../SeparationArea"
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
	_push_colliding_boxes(velocity_to_apply)

## Tras moverse, empuja las cajas con las que el jugador choca avanzando hacia
## ellas. Solo el jugador empuja (los enemigos las ignoran) y solo cuando se
## desplaza hacia la caja, evitando que se deslice al estar simplemente apoyado.
func _push_colliding_boxes(intended_velocity: Vector2) -> void:
	if intended_velocity == Vector2.ZERO:
		return
	if not target.is_in_group("Player"):
		return

	var move_dir := intended_velocity.normalized()
	for i in target.get_slide_collision_count():
		var collision := target.get_slide_collision(i)
		var box := collision.get_collider() as Box
		if box == null:
			continue
		# Dirección de empuje = hacia el interior de la caja (contra su normal).
		var push_dir := -collision.get_normal()
		if move_dir.dot(push_dir) > 0.0:
			box.push(push_dir * speed)

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
