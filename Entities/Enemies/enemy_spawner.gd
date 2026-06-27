class_name EnemySpawner
extends Node2D
## Servicio de spawneo reutilizable. No depende de nodos asignados desde el
## inspector: la sala (RoomLayout) le pasa el piso navegable y la pool en cada
## llamada, y el jugador se resuelve solo desde el grupo "Player". Sirve igual para
## el spawn inicial de una sala de combate que para las oleadas de un puzzle.

## Distancia mínima a la que puede aparecer un enemigo respecto del jugador.
@export var min_player_distance: float = 150.0

func _ready() -> void:
	randomize()

## Spawnea de inmediato la pool indicada sobre las celdas navegables de
## `floor_layer`. El jugador se busca en el grupo "Player" para respetar la
## distancia mínima de aparición.
func spawn_pool(pool: Array[SpawnCategory], floor_layer: TileMapLayer) -> void:
	if floor_layer == null:
		push_error("EnemySpawner: no se recibió un piso navegable donde spawnear.")
		return
	if pool.is_empty():
		return

	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())

	var valid_cells := floor_layer.get_used_cells()
	if valid_cells.is_empty():
		push_warning("EnemySpawner: el TileMapLayer '%s' no tiene celdas usadas." % floor_layer.name)
		return

	var player := get_tree().get_first_node_in_group("Player") as Node2D

	for category in pool:
		_spawn_category(category, floor_layer, valid_cells, player)

## Spawnea los enemigos de una sola categoría sobre celdas navegables al azar,
## respetando la distancia mínima al jugador. Limita los intentos para no colgarse
## si casi no hay celdas válidas o el jugador acapara el espacio.
func _spawn_category(category: SpawnCategory, floor_layer: TileMapLayer, valid_cells: Array[Vector2i], player: Node2D) -> void:
	if category.scenes.is_empty() or category.quantity <= 0:
		return

	var spawned := 0
	var attempts := 0
	var max_attempts := category.quantity * 5

	while spawned < category.quantity and attempts < max_attempts:
		attempts += 1

		var random_cell: Vector2i = valid_cells.pick_random()

		# Descarta celdas sin polígono de navegación (no son piso transitable).
		var tile_data := floor_layer.get_cell_tile_data(random_cell)
		if tile_data and tile_data.get_navigation_polygon(0) == null:
			continue

		var spawn_pos := floor_layer.to_global(floor_layer.map_to_local(random_cell))

		if player and spawn_pos.distance_to(player.global_position) < min_player_distance:
			continue

		var enemy_scene: PackedScene = category.scenes.pick_random()
		if enemy_scene == null:
			continue

		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = spawn_pos
		spawned += 1

	if spawned == 0:
		push_warning("EnemySpawner: no se pudo spawnear ningún enemigo de '%s' (intentos agotados o jugador demasiado cerca)." % category.name)
