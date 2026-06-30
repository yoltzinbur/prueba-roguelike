class_name Box
extends CharacterBody2D
## Caja empujable para puzzles. El jugador la empuja llamando a push(velocity);
## la caja avanza con move_and_slide() (que evita atravesar paredes del
## TileMapLayer) y se frena progresivamente por fricción hasta detenerse.
##
## Navegación: la caja recorta del navmesh la(s) celda(s) de piso que ocupa (ver
## _recarve), para que el path de los enemigos la rodee en vez de calcular una ruta
## recta que la atraviese (la colisión los frenaría y se atascarían). El recorte se
## restaura y se vuelve a aplicar cuando la caja se detiene en una posición nueva, y
## se restaura por completo al salir del árbol (p. ej. al reiniciar el puzzle), para
## no dejar huecos permanentes en el navmesh.

## Fricción (px/s²) aplicada cada frame para frenar la caja tras un empujón.
@export var friction: float = 400.0

## Velocidad máxima permitida al empujar (evita lanzamientos exagerados).
@export var max_push_speed: float = 80.0

# Caja bloqueada: ignora empujones y se queda fija (p. ej. al resolver un puzzle,
# para que el jugador no pueda deshacer la solución moviéndola).
var _locked: bool = false

# Celdas de navmesh recortadas bajo la caja, para poder restaurarlas al moverse o
# al salir del árbol. Cada entrada: { layer, coords, source, atlas, alt }.
var _carved: Array[Dictionary] = []
# True mientras la caja se está desplazando, para detectar el instante en que se
# detiene y recalcular el recorte en la nueva celda.
var _was_moving: bool = false

func _ready() -> void:
	# Recorte inicial diferido: asegura que los TileMapLayer del nivel ya estén en el
	# árbol y que get_world_2d() sea válido al forzar la actualización del navmesh.
	_recarve.call_deferred()

## API pública: imprime un impulso de movimiento a la caja en la dirección dada.
## `push_velocity` es un vector de velocidad (dirección * magnitud). Si la caja está
## bloqueada, ignora el empujón.
func push(push_velocity: Vector2) -> void:
	if _locked:
		return
	velocity = push_velocity.limit_length(max_push_speed)

## API pública: fija la caja en su posición actual e ignora empujones posteriores.
func lock() -> void:
	_locked = true
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		# La caja acaba de detenerse tras un empujón: recorta el navmesh en su nueva
		# celda (restaurando primero la anterior). Solo una vez al detenerse.
		if _was_moving:
			_was_moving = false
			_recarve()
		return

	_was_moving = true
	move_and_slide()

	# Si chocó de frente con una pared, move_and_slide() ya anuló la componente
	# bloqueada; frenamos el resto progresivamente hasta el reposo.
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _exit_tree() -> void:
	# Al salir del árbol (p. ej. reinicio de puzzle) devolvemos las celdas recortadas
	# para no dejar agujeros permanentes en el navmesh del nivel.
	_restore_carved()

# --- Recorte del navmesh ------------------------------------------------------

## Restaura las celdas recortadas previamente y recorta las que ocupa la caja ahora.
func _recarve() -> void:
	_restore_carved()
	if not is_inside_tree():
		return

	var carved_any := false
	var layers := _all_tilemap_layers()
	for cell_world in _footprint_points():
		for layer in layers:
			var cell := layer.local_to_map(layer.to_local(cell_world))
			var tile_data := layer.get_cell_tile_data(cell)
			# Solo recortamos celdas navegables (con polígono de navegación). Evitamos
			# duplicados: si esa (capa, celda) ya está recortada, la saltamos.
			if tile_data == null or tile_data.get_navigation_polygon(0) == null:
				continue
			if _is_already_carved(layer, cell):
				continue
			_carved.append({
				"layer": layer,
				"coords": cell,
				"source": layer.get_cell_source_id(cell),
				"atlas": layer.get_cell_atlas_coords(cell),
				"alt": layer.get_cell_alternative_tile(cell),
			})
			layer.erase_cell(cell)
			carved_any = true

	if carved_any:
		NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())

## Devuelve al navmesh las celdas recortadas y limpia el registro.
func _restore_carved() -> void:
	if _carved.is_empty():
		return
	for entry in _carved:
		var layer: TileMapLayer = entry["layer"]
		if is_instance_valid(layer):
			layer.set_cell(entry["coords"], entry["source"], entry["atlas"], entry["alt"])
	_carved.clear()
	if is_inside_tree():
		NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())

func _is_already_carved(layer: TileMapLayer, cell: Vector2i) -> bool:
	for entry in _carved:
		if entry["layer"] == layer and entry["coords"] == cell:
			return true
	return false

## Puntos en coordenadas de mundo que cubren la huella de 16x16 de la caja (centro y
## las 4 esquinas con un pequeño margen interior), para recortar todas las celdas que
## ocupa aunque no esté perfectamente alineada a la rejilla.
func _footprint_points() -> Array[Vector2]:
	var origin := global_position
	return [
		origin + Vector2(8, 8),
		origin + Vector2(2, 2),
		origin + Vector2(14, 2),
		origin + Vector2(2, 14),
		origin + Vector2(14, 14),
	]

## Recolecta (DFS) todas las TileMapLayer de la escena actual.
func _all_tilemap_layers() -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	var root := get_tree().current_scene
	if root:
		_collect_tilemap_layers(root, out)
	return out

func _collect_tilemap_layers(node: Node, out: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		out.append(node)
	for child in node.get_children():
		_collect_tilemap_layers(child, out)
