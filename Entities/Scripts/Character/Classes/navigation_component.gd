class_name NavigationComponent
extends Node2D

@export var navigation_agent: NavigationAgent2D
@export var update_time: Timer

var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	
	update_time.timeout.connect(_on_timer_timeout)
	
func _on_timer_timeout() -> void:
	if player and is_instance_valid(player):
		navigation_agent.target_position = player.global_position
		
func get_next_direction(current_target: Node2D) -> Vector2:
	if not navigation_agent.is_target_reachable():
		return Vector2.ZERO
	
	var next_path_pos: Vector2 = navigation_agent.get_next_path_position()
	var local_pos: Vector2 = current_target.to_local(next_path_pos)
	
	return local_pos.normalized()
