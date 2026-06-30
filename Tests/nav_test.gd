extends SceneTree
## Runner de prueba de navegación (headless), sin framework externo.
##
## Ejecutar:
##   godot --headless --path . --script res://Tests/nav_test.gd
##
## Construye un navmesh en forma de "dona" (un rectángulo con un hueco central no
## navegable), coloca un Jugador a la derecha y un Chort real (Chort.tscn) a la
## izquierda, y deja correr la física unos segundos. Comprueba dos cosas:
##   1) MOVIMIENTO: el Chort se acerca de verdad al jugador (regresión "no se mueven").
##   2) RUTA: el Chort RODEA el hueco en lugar de intentar cruzarlo en línea recta
##      (lo que valida que el path respeta los huecos del navmesh, igual que harán las
##      cajas y los obstáculos de combate al recortar el navmesh).
##
## Imprime "NAV TEST: PASS"/"FAIL" y termina con código de salida 0/1.

const CHORT := preload("res://Entities/Enemies/Chort/Chort.tscn")

# Geometría del navmesh.
const OUTER := 120.0   # medio-lado del rectángulo de piso
const HOLE := 32.0     # medio-lado del hueco central no navegable

const PLAYER_POS := Vector2(90, 0)
const ENEMY_POS := Vector2(-90, 0)

const MAX_FRAMES := 600          # ~10 s a 60 FPS de física
const REACH_DIST := 28.0         # se considera "llegó" a esta distancia del jugador
const HOLE_INSIDE := 26.0        # entrar aquí (|x|,|y| < esto) = cruzó el hueco

func _initialize() -> void:
	_run()

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	# --- Piso navegable con hueco central (dona de 4 cuadriláteros) ---
	var region := NavigationRegion2D.new()
	region.navigation_polygon = _make_donut_polygon()
	world.add_child(region)

	# --- Jugador (objetivo de la persecución) ---
	var player := CharacterBody2D.new()
	player.add_to_group("Player")
	player.global_position = PLAYER_POS
	world.add_child(player)

	# --- Enemigo real ---
	var enemy: Node2D = CHORT.instantiate()
	world.add_child(enemy)
	enemy.global_position = ENEMY_POS

	# Deja que el navmesh y los agentes se sincronicen antes de empezar a medir.
	NavigationServer2D.map_force_update(world.get_world_2d().get_navigation_map())
	await physics_frame
	await physics_frame

	var start_dist := enemy.global_position.distance_to(player.global_position)
	var min_dist := start_dist
	var crossed_hole := false
	var reached := false

	for i in MAX_FRAMES:
		await physics_frame
		var pos: Vector2 = enemy.global_position
		min_dist = min(min_dist, pos.distance_to(player.global_position))
		if absf(pos.x) < HOLE_INSIDE and absf(pos.y) < HOLE_INSIDE:
			crossed_hole = true
		if pos.distance_to(player.global_position) <= REACH_DIST:
			reached = true
			break

	var moved := min_dist < start_dist - 30.0

	print("--- NAV TEST ---")
	print("  dist inicial : %.1f" % start_dist)
	print("  dist mínima  : %.1f" % min_dist)
	print("  se movió     : %s" % moved)
	print("  llegó        : %s" % reached)
	print("  cruzó hueco  : %s" % crossed_hole)

	var ok: bool = moved and reached and not crossed_hole
	if ok:
		print("NAV TEST: PASS")
		quit(0)
	else:
		var reasons: Array[String] = []
		if not moved:
			reasons.append("el enemigo no se acercó al jugador (¿no se mueve?)")
		if not reached:
			reasons.append("el enemigo no llegó al jugador")
		if crossed_hole:
			reasons.append("el enemigo cruzó el hueco (no rodeó el obstáculo)")
		print("NAV TEST: FAIL -> " + ", ".join(reasons))
		quit(1)

## Construye un NavigationPolygon rectangular con un hueco central: cuatro
## cuadriláteros (arriba/derecha/abajo/izquierda) que forman un anillo navegable.
func _make_donut_polygon() -> NavigationPolygon:
	var poly := NavigationPolygon.new()
	var o := OUTER
	var h := HOLE
	poly.vertices = PackedVector2Array([
		Vector2(-o, -o), Vector2(o, -o), Vector2(o, o), Vector2(-o, o),  # 0..3 exterior
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),  # 4..7 hueco
	])
	poly.add_polygon(PackedInt32Array([0, 1, 5, 4]))  # franja superior
	poly.add_polygon(PackedInt32Array([1, 2, 6, 5]))  # franja derecha
	poly.add_polygon(PackedInt32Array([2, 3, 7, 6]))  # franja inferior
	poly.add_polygon(PackedInt32Array([3, 0, 4, 7]))  # franja izquierda
	return poly
