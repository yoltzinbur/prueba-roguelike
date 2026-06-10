extends Node2D

var floor_layer: TileMapLayer

@export var spawn_categories: Array[SpawnCategory]
@export var max_enemies: int = 5
@export var node_floor_layer: Node2D
@export var player: Node2D
@export var min_player_distance: float = 150.0

func _ready() -> void:
	floor_layer = node_floor_layer.get_node_or_null("navigation_floor")
	
	randomize()
	call_deferred("spawn_all_categories")

func spawn_all_categories() -> void:
	if not floor_layer:
		push_error("Error: No hay mapita")
		return
	
	if spawn_categories.is_empty():
		push_error("Error: No hay categorías configuradas")
		return
	
	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())
	
	var valid_cells = floor_layer.get_used_cells()
	if valid_cells.is_empty():
		return
	
	for category in spawn_categories:
		if category.scenes.is_empty() or category.quantity <= 0:
			continue
		
		var spawned_in_category = 0
		var attempts = 0
		var max_attempts = category.quantity * 5
		
		while spawned_in_category < category.quantity and attempts < max_attempts:
			attempts += 1
			
			var random_cell = valid_cells.pick_random()
			var local_pos = floor_layer.map_to_local(random_cell)
			var spawn_pos = floor_layer.to_global(local_pos)
			
			if player and	 spawn_pos.distance_to(player.global_position) < min_player_distance:
				continue
			
			var enemy_scene = category.scenes.pick_random()
			var enemy_instance = enemy_scene.instantiate()
			
			enemy_instance.global_position = spawn_pos
			add_child(enemy_instance)
			
			spawned_in_category += 1
