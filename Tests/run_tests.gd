extends Node
## Runner de pruebas mínimo y SIN dependencias externas para la lógica PURA del
## juego (generación procedural y puzzles), donde más fácil se cuelan regresiones.
## No instala ningún framework (GUT u otro); usa funciones que no dependen del árbol
## de escena, instanciando los scripts con .new() y llamando sus métodos directamente.
##
## Se ejecuta como escena (modo normal, para que los autoloads estén disponibles y
## no fallen los scripts que dependen de ellos). Desde la raíz del proyecto:
##   godot --headless res://Tests/Tests.tscn
## Sale con código 0 si todo pasa y 1 si algo falla (apto para CI).

const StartCave := preload("res://Stages/Layouts/Cave/CaveMain/start_cave.gd")
const PuzzleArithmetic := preload("res://Stages/Layouts/Cave/Layers/Puzzle/puzzle_arithmetic.gd")

var _count := 0
var _failures: Array[String] = []

func _ready() -> void:
	_test_drunkards_walk()
	_test_boss_coord_single_door()
	_test_generate_map_boss_single_door()
	_test_random_value_no_multiplo()
	_test_residue()

	print("\n[TESTS] %d comprobaciones, %d fallidas" % [_count, _failures.size()])
	for f in _failures:
		print("  FALLO: %s" % f)
	get_tree().quit(0 if _failures.is_empty() else 1)

## Registra una comprobación y guarda el mensaje si falla.
func _check(cond: bool, msg: String) -> void:
	_count += 1
	if not cond:
		_failures.append(msg)

# --- Drunkard's Walk ---------------------------------------------------------

func _test_drunkards_walk() -> void:
	var cave := StartCave.new()
	var amount := 8
	var cells: Array = cave._drunkards_walk(amount)

	_check(cells.size() == amount, "drunkards_walk debe devolver %d celdas, devolvió %d" % [amount, cells.size()])
	_check(cells.has(Vector2i.ZERO), "drunkards_walk debe incluir el origen (0,0)")

	var seen := {}
	var unico := true
	for c in cells:
		if seen.has(c):
			unico = false
		seen[c] = true
	_check(unico, "drunkards_walk no debe repetir celdas")
	_check(_es_conexo(cells), "drunkards_walk debe producir una región conexa")

	cave.free()

## BFS sobre vecinos cardinales: comprueba que todas las celdas estén conectadas.
func _es_conexo(cells: Array) -> bool:
	if cells.is_empty():
		return true
	var conjunto := {}
	for c in cells:
		conjunto[c] = true
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	var visitado := {}
	var pila := [cells[0]]
	while not pila.is_empty():
		var actual: Vector2i = pila.pop_back()
		if visitado.has(actual):
			continue
		visitado[actual] = true
		for d in dirs:
			var vecino: Vector2i = actual + d
			if conjunto.has(vecino) and not visitado.has(vecino):
				pila.append(vecino)
	return visitado.size() == conjunto.size()

func _test_boss_coord_single_door() -> void:
	var cave := StartCave.new()
	# Mapa en forma de "L" con varios bordes para que haya varias candidatas.
	var coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
	]
	var boss: Vector2i = cave._pick_boss_coord(coords, Vector2i.ZERO)

	# La Sala de Jefe no debe coincidir con una sala existente.
	_check(not coords.has(boss), "la Sala de Jefe no debe caer sobre una sala existente (cayó en %s)" % str(boss))

	# Debe tener EXACTAMENTE un vecino en el mapa: una sola puerta.
	var conjunto := {}
	for c in coords:
		conjunto[c] = true
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	var vecinos := 0
	for d in dirs:
		if conjunto.has(boss + d):
			vecinos += 1
	_check(vecinos == 1, "la Sala de Jefe debe tener exactamente una entrada, tuvo %d" % vecinos)
	cave.free()

# --- Puzzle aritmético -------------------------------------------------------

## Genera muchos mapas completos y comprueba que la Sala de Jefe SIEMPRE tenga
## exactamente una puerta (el problema que motivó el cambio: jefe como sala de paso).
func _test_generate_map_boss_single_door() -> void:
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	var siempre_una_puerta := true
	var detalle := ""
	for iteracion in 100:
		var cave := StartCave.new()
		seed(iteracion)
		cave.generate_map()
		# Localiza la celda del Jefe.
		var boss_coord := Vector2i.ZERO
		var encontrado := false
		for coord in cave.map:
			if cave.map[coord] == StartCave.ROOM_BOSS:
				boss_coord = coord
				encontrado = true
				break
		if not encontrado:
			siempre_una_puerta = false
			detalle = "no se asignó Sala de Jefe en la iteración %d" % iteracion
			cave.free()
			break
		var puertas := 0
		for d in dirs:
			if cave.map.has(boss_coord + d):
				puertas += 1
		if puertas != 1:
			siempre_una_puerta = false
			detalle = "iteración %d: el jefe tuvo %d puertas" % [iteracion, puertas]
			cave.free()
			break
		cave.free()
	_check(siempre_una_puerta, "la Sala de Jefe debe tener siempre una sola puerta (%s)" % detalle)

func _test_random_value_no_multiplo() -> void:
	var p := PuzzleArithmetic.new()
	p.modulo = 5
	var todos_validos := true
	for i in 200:
		var v: int = p._random_value()
		if v < PuzzleArithmetic.MIN_VALUE or v > PuzzleArithmetic.MAX_VALUE or v % 5 == 0:
			todos_validos = false
			break
	_check(todos_validos, "_random_value no debe devolver múltiplos del módulo ni salirse del rango")
	p.free()

func _test_residue() -> void:
	var p := PuzzleArithmetic.new()
	p.modulo = 5
	p._active_sum = 7
	_check(p._residue() == 2, "_residue de 7 con módulo 5 debe ser 2")
	p._active_sum = 10
	_check(p._residue() == 0, "_residue de 10 con módulo 5 debe ser 0")
	p.modulo = 0
	_check(p._residue() == 0, "_residue con módulo 0 (sin módulo) debe ser 0")
	p.free()
