class_name EnemySpawner
extends Node2D

var floor_layer: TileMapLayer

@export var spawn_categories: Array[SpawnCategory]
@export var max_enemies: int = 5
@export var min_player_distance: float = 150.0
@export var node_floor_layer: Node2D
@export var player: Node2D

func _ready() -> void:
	floor_layer = node_floor_layer.get_node_or_null("navigation_floor")
	
	randomize()
	call_deferred("spawn_all_categories")

## Spawnea de una vez las categorías configuradas en spawn_categories. La llama
## el _ready() de las salas de combate (al generarse la sala).
func spawn_all_categories() -> void:
	if spawn_categories.is_empty():
		# Sin categorías = sala pacífica (Start/Puzzle/Rest): nada que spawnear.
		return
	spawn_pool(spawn_categories)

## Spawnea de inmediato todas las categorías del pool indicado sobre el piso
## navegable. Reutilizable para oleadas periódicas (p. ej. los puzzles llaman a
## esto cada cierto tiempo con las pools easy/medium).
func spawn_pool(pool: Array[SpawnCategory]) -> void:
	if not floor_layer:
		push_error("Error: No hay mapita asignado en el Spawner")
		return

	if pool.is_empty():
		return

	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())

	var valid_cells = floor_layer.get_used_cells()
	if valid_cells.is_empty():
		push_warning("Fallo: El TileMapLayer '%s' no tiene celdas usadas detectadas." % floor_layer.name)
		return

	for category in pool:
		if category.scenes.is_empty() or category.quantity <= 0:
			continue

		var spawned_in_category = 0
		var attempts = 0
		var max_attempts = category.quantity * 5

		while spawned_in_category < category.quantity and attempts < max_attempts:
			attempts += 1

			var random_cell = valid_cells.pick_random()
			
			var tile_data: TileData = floor_layer.get_cell_tile_data(random_cell)
			if tile_data:
				var nav_poly = tile_data.get_navigation_polygon(0)
				if nav_poly == null:
					continue
			
			var local_pos = floor_layer.map_to_local(random_cell)
			var spawn_pos = floor_layer.to_global(local_pos)

			if player and spawn_pos.distance_to(player.global_position) < min_player_distance:
				continue

			var enemy_scene = category.scenes.pick_random()
			if not enemy_scene: continue
			
			var enemy_instance = enemy_scene.instantiate()
			
			add_child(enemy_instance)
			print("Enemigo ", spawned_in_category)
			enemy_instance.global_position = spawn_pos
			
			spawned_in_category += 1

			if spawned_in_category == 0:
				push_warning("No se pudo spawnear ningún enemigo de la categoría %s por exceso de intentos o rango del Player." % category.name)
