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

	var valid_cells := _prepare_cells(floor_layer)
	if valid_cells.is_empty():
		return

	var player := get_tree().get_first_node_in_group("Player") as Node2D

	for category in pool:
		_spawn_category(category, floor_layer, valid_cells, player)

## Spawnea EXACTAMENTE `count` enemigos tomados al azar de las escenas de la pool.
## Pensado para penalizaciones de cantidad controlada (en lugar de volcar la
## cantidad fija de cada categoría, que puede acumular demasiados enemigos).
func spawn_count(pool: Array[SpawnCategory], count: int, floor_layer: TileMapLayer) -> void:
	if floor_layer == null:
		push_error("EnemySpawner: no se recibió un piso navegable donde spawnear.")
		return
	if count <= 0:
		return

	var scenes := _collect_scenes(pool)
	if scenes.is_empty():
		return

	var valid_cells := _prepare_cells(floor_layer)
	if valid_cells.is_empty():
		return

	var player := get_tree().get_first_node_in_group("Player") as Node2D

	var spawned := 0
	var attempts := 0
	var max_attempts := count * 5
	while spawned < count and attempts < max_attempts:
		attempts += 1
		if _try_spawn_one(scenes, floor_layer, valid_cells, player):
			spawned += 1

## Fuerza el mapa de navegación y devuelve las celdas usadas del piso (o vacío con
## una advertencia si no hay ninguna).
func _prepare_cells(floor_layer: TileMapLayer) -> Array[Vector2i]:
	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())
	var valid_cells := floor_layer.get_used_cells()
	if valid_cells.is_empty():
		push_warning("EnemySpawner: el TileMapLayer '%s' no tiene celdas usadas." % floor_layer.name)
	return valid_cells

## Reúne todas las escenas de enemigos de las categorías de la pool.
func _collect_scenes(pool: Array[SpawnCategory]) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for category in pool:
		for scene in category.scenes:
			if scene:
				scenes.append(scene)
	return scenes

## Spawnea los enemigos de una sola categoría (su `quantity`) sobre celdas
## navegables al azar, limitando los intentos para no colgarse.
func _spawn_category(category: SpawnCategory, floor_layer: TileMapLayer, valid_cells: Array[Vector2i], player: Node2D) -> void:
	if category.scenes.is_empty() or category.quantity <= 0:
		return

	var spawned := 0
	var attempts := 0
	var max_attempts := category.quantity * 5
	while spawned < category.quantity and attempts < max_attempts:
		attempts += 1
		if _try_spawn_one(category.scenes, floor_layer, valid_cells, player):
			spawned += 1

	if spawned == 0:
		push_warning("EnemySpawner: no se pudo spawnear ningún enemigo de '%s' (intentos agotados o jugador demasiado cerca)." % category.name)

## Intenta spawnear UN enemigo (de `scenes`) en una celda navegable al azar.
## Devuelve true si lo logró; false si la celda no es válida o está demasiado cerca
## del jugador.
func _try_spawn_one(scenes: Array[PackedScene], floor_layer: TileMapLayer, valid_cells: Array[Vector2i], player: Node2D) -> bool:
	var random_cell: Vector2i = valid_cells.pick_random()

	# Descarta celdas sin polígono de navegación (no son piso transitable).
	var tile_data := floor_layer.get_cell_tile_data(random_cell)
	if tile_data and tile_data.get_navigation_polygon(0) == null:
		return false

	var spawn_pos := floor_layer.to_global(floor_layer.map_to_local(random_cell))
	if player and spawn_pos.distance_to(player.global_position) < min_player_distance:
		return false

	var enemy_scene: PackedScene = scenes.pick_random()
	if enemy_scene == null:
		return false

	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = spawn_pos
	return true
