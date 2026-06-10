extends Node2D

var floor_layer: TileMapLayer

@export var enemy_scenes: Array[PackedScene]
@export var max_enemies: int = 5
@export var node_floor_layer: Node2D
@export var player: Node2D
@export var min_player_distance: float = 100.0

func _ready() -> void:
	floor_layer = node_floor_layer.get_node_or_null("navigation_floor")
	
	randomize()
	call_deferred("spawn_enemies")

func spawn_enemies() -> void:
	if enemy_scenes.is_empty() or not floor_layer:
		push_error("Error: No hay enemigos a generar o no hya mapita")
		return
	
	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())
	
	var valid_cells = floor_layer.get_used_cells()
	if valid_cells.is_empty():
		return
	
	var spawned_count = 0
	var attempts = 0
	var max_attempts = max_enemies * 5
	
	while spawned_count < max_enemies and attempts < max_attempts:
		attempts += 1
		
		var random_cell = valid_cells.pick_random()
		var local_pos = floor_layer.map_to_local(random_cell)
		var spawn_pos = floor_layer.to_global(local_pos)
		
		if player and spawn_pos.distance_to(player.global_position) < min_player_distance:
			continue
		
		var enemy_scene = enemy_scenes.pick_random()
		var enemy_instance = enemy_scene.instantiate()
		
		enemy_instance.global_position = spawn_pos
		
		add_child(enemy_instance)
		spawned_count += 1
