class_name NavigationComponent
extends Node2D

@export var navigation_agent: NavigationAgent2D
@export var timer: Timer

var player: Node2D

func _ready() -> void:
	_find_player()
	
	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func _find_player():
	var player_nodes = get_tree().get_nodes_in_group("Player")
	if not player_nodes.is_empty():
		player = player_nodes[0]

func _on_timer_timeout() -> void:
	if not is_instance_valid(player):
		_find_player()
		return
	
	if navigation_agent.get_navigation_map() == RID():
		var default_map = get_world_2d().get_navigation_map()
		navigation_agent.set_navigation_map(default_map)
		return
	
	navigation_agent.target_position = player.global_position

func get_next_direction(current_target: Node2D) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	
	if navigation_agent.is_navigation_finished():
		return Vector2.ZERO
	
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - current_target.global_position).normalized()
	
	return direction
