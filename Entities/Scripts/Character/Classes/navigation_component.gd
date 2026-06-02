class_name NavigationComponent
extends Node2D

@export var navigation_agent: NavigationAgent2D
@export var timer: Timer

var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	
	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	if player and is_instance_valid(player):
		navigation_agent.target_position = player.global_position
	
func get_next_direction(current_target: Node2D) -> Vector2:
	if not player and not is_instance_valid(player):
		return Vector2.ZERO
	
	if navigation_agent.is_navigation_finished():
		return Vector2.ZERO
	
	var direction: Vector2 = current_target.to_local(
		navigation_agent.get_next_path_position()
	).normalized()
	
	return direction
