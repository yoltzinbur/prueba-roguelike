class_name RoomLayout
extends Node2D
## Plantilla de sala procedural. `configure_room()` ajusta las puertas (muro o
## apertura), inyecta el contenido interior y configura el EnemySpawner según el
## tipo de sala recibido desde el generador (cave_main.gd).

# Listas de contenido instanciable (configurables desde el editor).
@export var puzzle_list: Array[PackedScene]
@export var rest_list: Array[PackedScene]
@export var combat_list: Array[PackedScene] ## Layouts internos de combate.
## Layer(s) de la zona del Jefe (BossRoom): traen su propio mapa con el jefe ya
## colocado dentro. Se instancia uno al azar en las salas de tipo Boss.
@export var boss_list: Array[PackedScene]

# Pools de enemigos por dificultad, inyectadas al EnemySpawner.
@export var easy_combat: Array[SpawnCategory]
@export var medium_combat: Array[SpawnCategory]
@export var hard_combat: Array[SpawnCategory]

@onready var doors: Node2D = $Doors
@onready var content: Node2D = $Content
@onready var enemy_spawner: EnemySpawner = $EnemySpawner

## Emitida tras reinstanciar el contenido del puzzle en reset_current_puzzle().
## La UI o los sistemas externos pueden reconectarse al nuevo contenido aquí.
signal puzzle_reset

## Emitida cuando la sala de puzzle se resuelve (desde complete_puzzle). La escucha
## el administrador del nivel (start_cave.gd) para el contador y el desbloqueo del Boss.
signal room_cleared(room: RoomLayout)

# Configuración ORIGINAL de las puertas (qué lados conectan con un vecino). Se
# guarda en configure_room() para poder restaurar la apertura tras el puzzle.
var _n_active: bool
var _s_active: bool
var _e_active: bool
var _w_active: bool

# Escena del puzzle instanciada en _setup_peaceful(); se conserva para poder
# clonarla en reset_current_puzzle().
var _current_puzzle_scene: PackedScene

# Modo (Pila/Cola) y secuencia objetivo sorteados por el puzzle en su primera
# instanciación. Se guardan para reimponerlos en cada reinicio y que el reto no
# cambie. _puzzle_mode = -1 indica que no hay configuración guardada (sala que no
# es de tipo Puzzle o cuyo contenido no es un PuzzleStackQueue).
var _puzzle_mode: int = -1
var _puzzle_order: Array[String] = []

# Estado de la sala para la mecánica de bloqueo de puertas.
var room_type: String = ""
var is_puzzled_cleared: bool = false

# --- Pelea del Jefe (salas Boss) ---------------------------------------------
# Al entrar el jugador se encierra y se activa al jefe; al morir todos, se reabren las
# puertas. _boss_active evita reactivar; _bosses_alive vigila las muertes.
var _boss_active: bool = false
var _bosses_alive: Array[Node] = []
# Nombre del jefe para el aviso de victoria; se captura al activarlo.
var _boss_name: String = "El jefe"

# --- Combate por encierro (salas Easy/Medium/Hard) ---------------------------
# Las salas de combate ya NO spawnean al instanciarse: igual que los puzzles,
# esperan a que el jugador entre. Al entrar se cierran las puertas y aparece la
# oleada; cuando muere el último enemigo, las puertas se reabren.
# Pool guardada en _setup_combat para spawnear al entrar el jugador.
var _combat_pools: Array[SpawnCategory] = []
# True mientras hay enemigos vivos de la oleada (puertas cerradas).
var _combat_active: bool = false
# True una vez limpiada la sala: no vuelve a encerrar al jugador si reentra.
var is_combat_cleared: bool = false

# La pista del orden solo se muestra la primera vez que se entra a la sala; ni
# reentrar ni reiniciar el puzzle vuelven a mostrarla. Que sufra el jugador.
var _hint_shown: bool = false

# --- Oleadas de enemigos en salas de tipo Puzzle -----------------------------
# Mientras el jugador resuelve un puzzle, cada WAVE_INTERVAL_SECONDS aparecen
# enemigos básicos (pool easy) y cada MEDIUM_EVERY_WAVES oleadas, además, medianos.
const WAVE_INTERVAL_SECONDS: float = 15.0
## El puzzle de láseres presiona más al jugador: oleadas más frecuentes.
const LASER_WAVE_INTERVAL_SECONDS: float = 7.0
const MEDIUM_EVERY_WAVES: int = 5

# Temporizador de oleadas (creado bajo demanda) y número de oleadas ya lanzadas.
var _wave_timer: Timer
var _wave_count: int = 0

## Conecta el RoomTrigger (añadido manualmente en el editor) para detectar la
## entrada del jugador. Corre antes que configure_room(), así que room_type aún
## está vacío aquí: solo se cablea la señal y el tipo se lee de forma diferida.
func _ready() -> void:
	var room_trigger := get_node_or_null("RoomTrigger") as Area2D
	if room_trigger:
		room_trigger.body_entered.connect(_on_room_trigger_entered)
		room_trigger.body_exited.connect(_on_room_trigger_exited)

## Punto de entrada llamado por el generador. Abre/cierra las puertas según los
## vecinos e inyecta contenido o enemigos según el tipo de sala.
func configure_room(type: String, north: bool, south: bool, east: bool, west: bool) -> void:
	# Guarda la configuración original para restaurarla al completar el puzzle.
	room_type = type
	_n_active = north
	_s_active = south
	_e_active = east
	_w_active = west
	# Verificación: confirma el estado guardado al iniciar el juego.
	print_verbose("[RoomLayout] type=%s | N:%s S:%s E:%s W:%s" % [type, north, south, east, west])

	_configure_door(doors.get_node_or_null("NorthDoor"), north)
	_configure_door(doors.get_node_or_null("SouthDoor"), south)
	_configure_door(doors.get_node_or_null("EastDoor"), east)
	_configure_door(doors.get_node_or_null("WestDoor"), west)
	# Las puertas de avance del Jefe (CaveDoor2) viven en la plantilla, así que están
	# presentes en TODAS las salas. Se ocultan siempre y solo se revelan al vencer al
	# jefe en la sala del Jefe (ver _reveal_boss_doors).
	_hide_boss_doors()

	match type:
		ROOM_TYPE_EASY:
			_setup_combat(easy_combat)
		ROOM_TYPE_MEDIUM:
			_setup_combat(medium_combat)
		ROOM_TYPE_HARD:
			_setup_combat(hard_combat)
		ROOM_TYPE_BOSS:
			_setup_boss()
		ROOM_TYPE_PUZZLE:
			_setup_peaceful(puzzle_list)
		ROOM_TYPE_REST:
			_setup_peaceful(rest_list)
		_:
			# Sala de Inicio (Start) u otras: pacífica y sin contenido. El spawner es
			# un servicio pasivo, así que basta con no invocarlo.
			pass

# Identificadores de tipo, alineados con los del generador (cave_main.gd).
const ROOM_TYPE_EASY := "Easy"
const ROOM_TYPE_MEDIUM := "Medium"
const ROOM_TYPE_HARD := "Hard"
const ROOM_TYPE_BOSS := "Boss"
const ROOM_TYPE_PUZZLE := "Puzzle"
const ROOM_TYPE_REST := "Rest"

## Abre el pasillo (si hay vecino) o mantiene la puerta como muro de contención.
func _configure_door(door: Node2D, has_neighbor: bool) -> void:
	if door == null:
		return

	var collision := door.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var interaction := door.get_node_or_null("InteractionArea") as Area2D

	# En el mapa procedural las puertas no transicionan de escena: son muro o
	# apertura. Se desactiva su interacción para no disparar load_scene().
	if interaction:
		interaction.set_deferred("monitoring", false)
		interaction.set_deferred("monitorable", false)

	if has_neighbor:
		# Hay vecino → abrir el pasillo: ocultar puerta y desactivar colisión.
		door.visible = false
		if collision:
			collision.set_deferred("disabled", true)
	else:
		# Sin vecino → muro de contención: puerta visible y colisión activa.
		door.visible = true
		if collision:
			collision.set_deferred("disabled", false)

## Sala de combate: instancia (si existe) un layout interno de combate y guarda la
## pool de enemigos. A diferencia de antes, NO spawnea al instanciar la sala: los
## enemigos aparecen cuando el jugador entra (_on_room_trigger_entered), igual que
## los puzzles. Así la sala empieza vacía y se "activa" al cruzar la puerta.
func _setup_combat(pools: Array[SpawnCategory]) -> void:
	_spawn_interior(combat_list)
	_combat_pools = pools

## Sala del Jefe: instancia su layer dedicado (BossRoom), que trae su propio mapa y
## al jefe ya colocado dentro, y bloquea las puertas hasta que el nivel desbloquee la
## sala (al completar los puzzles). No usa el EnemySpawner: el jefe es parte de la
## escena instanciada, no se spawnea desde una pool.
func _setup_boss() -> void:
	_spawn_interior(boss_list)
	_lock_boss_room()

## Despierta al/los jefe(s) de la sala. El jefe (Samurai) nace inerte (process_mode =
## DISABLED) y solo procesa —persigue/ataca— tras esta llamada. Se busca en el subárbol de
## Content (el layer del BossRoom trae al jefe ya colocado dentro) cualquier nodo del grupo
## "Boss" con método activate(). Idempotente: el propio jefe ignora reactivaciones.
func _activate_boss() -> void:
	if content == null or _boss_active:
		return
	var bosses := _find_bosses(content)
	if bosses.is_empty():
		return
	# Encierra al jugador para convertir la sala en arena durante la pelea. Al morir el
	# jefe (sale del árbol), se reabren las puertas para no dejar al jugador encerrado.
	_boss_active = true
	_bosses_alive = bosses.duplicate()
	_boss_name = String(bosses[0].name)
	_close_all_active_doors()
	for boss in bosses:
		boss.activate()
		boss.tree_exited.connect(_on_boss_exited.bind(boss))

## Disparada cuando un jefe abandona el árbol (muerte). Cuando ya no queda ninguno vivo,
## reabre las puertas que conectan con vecinos.
func _on_boss_exited(boss: Node) -> void:
	# El jefe también sale del árbol cuando se desmonta TODA la escena (p. ej. al volver
	# al menú tras un Game Over). Eso NO es derrotarlo: si la propia sala ya salió del
	# árbol, se ignora para no ejecutar la lógica de victoria ni tocar un get_tree() nulo.
	if not is_inside_tree():
		return
	_bosses_alive.erase(boss)
	if _bosses_alive.is_empty():
		_boss_active = false
		_open_active_doors()
		_reveal_boss_doors()

## Tras la muerte del jefe, revela UNA sola puerta de avance y anuncia la victoria. Se
## prefiere la del norte: si ese lado no es la entrada (no conecta con un vecino) se abre
## ahí; si el norte ES la entrada, se abre la del sur. Así el camino desbloqueado nunca
## se superpone con la entrada por la que llegó el jugador.
func _reveal_boss_doors() -> void:
	var door_name := "BossNorthDoor" if not _n_active else "BossSouthDoor"
	if _reveal_boss_door(doors.get_node_or_null(door_name)):
		_announce_boss_defeated()

## Oculta y desactiva ambas puertas de avance del Jefe. Se aplica a TODAS las salas al
## configurarlas, porque las CaveDoor2 viven en la plantilla pero solo deben usarse en
## la sala del Jefe una vez vencido.
func _hide_boss_doors() -> void:
	_set_boss_door_enabled(doors.get_node_or_null("BossNorthDoor"), false)
	_set_boss_door_enabled(doors.get_node_or_null("BossSouthDoor"), false)

## Activa una puerta de avance del Jefe (visible, con colisión e interacción). Devuelve
## true si la puerta existía y se reveló.
func _reveal_boss_door(door: Node2D) -> bool:
	if door == null:
		return false
	_set_boss_door_enabled(door, true)
	return true

## Activa o desactiva por completo una puerta de avance del Jefe (CaveDoor2):
## visibilidad, su CollisionPolygon2D y el monitoreo de su InteractionArea.
func _set_boss_door_enabled(door: Node2D, enabled: bool) -> void:
	if door == null:
		return
	door.visible = enabled
	var collision := door.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if collision:
		collision.set_deferred("disabled", not enabled)
	var interaction := door.get_node_or_null("InteractionArea") as Area2D
	if interaction:
		interaction.set_deferred("monitoring", enabled)
		interaction.set_deferred("monitorable", enabled)

## Muestra en la UI del jugador el aviso de que el jefe cayó. La caja de mensaje es de
## una sola línea, así que el texto se parte en DOS avisos consecutivos: primero la
## derrota (3 s) y luego el desbloqueo del camino, en vez de un único texto que no cabe.
func _announce_boss_defeated() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null or not player.has_method("show_message"):
		return
	player.show_message("%s derrotado." % _boss_name, 3.0)
	await get_tree().create_timer(3.0).timeout
	player.show_message("Se ha desbloqueado el camino...")

## Búsqueda en profundidad de los nodos del grupo "Boss" dentro del subárbol de `node`.
func _find_bosses(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.is_in_group("Boss") and child.has_method("activate"):
			found.append(child)
		found.append_array(_find_bosses(child))
	return found

## Sala pacífica (Puzzle/Rest): instancia contenido. No invoca al spawner, así que
## la sala queda sin enemigos.
func _setup_peaceful(scene_list: Array[PackedScene]) -> void:
	# Guarda la escena elegida antes de instanciarla para poder clonarla en el
	# reset. En salas Rest queda registrada también, pero reset_current_puzzle()
	# solo actúa sobre salas de tipo Puzzle.
	var instance := _spawn_interior(scene_list)
	# Recuerda el reto sorteado por el puzzle para conservarlo en los reinicios:
	# el de Pila/Cola guarda modo + secuencia; el de láser guarda compuerta + objetivo
	# (reutilizando _puzzle_order para el código del objetivo).
	if instance is PuzzleStackQueue:
		_puzzle_mode = instance.mode
		_puzzle_order = instance.target_order.duplicate()
	elif instance is PuzzleLaser:
		_puzzle_mode = instance.get_mode()
		_puzzle_order = [instance.get_objective_code()]

## Elige una escena al azar de la lista, la añade como hija de Content (lo que
## guarda también la PackedScene en _current_puzzle_scene) y devuelve la instancia
## creada (o null si la lista está vacía).
func _spawn_interior(scene_list: Array[PackedScene]) -> Node:
	if scene_list.is_empty() or content == null:
		return null
	var scene: PackedScene = scene_list.pick_random()
	if scene == null:
		return null
	_current_puzzle_scene = scene
	var instance := scene.instantiate()
	content.add_child(instance)
	return instance

# --- Mecánica de bloqueo de puertas (salas de tipo Puzzle) -------------------

## Disparada por el RoomTrigger. Si el jugador entra a una sala de puzzle aún no
## resuelta, encierra al jugador cerrando todas las puertas activas.
func _on_room_trigger_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# El jugador queda asociado a esta sala para que el input "reset" sepa cuál
	# reiniciar (reset_current_puzzle() solo actúa sobre salas de tipo Puzzle).
	body.current_room = self
	# Sala del Jefe: al entrar el jugador, despierta al jefe (que nace inerte).
	if room_type == ROOM_TYPE_BOSS:
		_activate_boss()
		return
	# Salas de combate: encierran al jugador y disparan la oleada de enemigos.
	if _is_combat_room():
		_enter_combat_room()
		return
	if room_type != ROOM_TYPE_PUZZLE or is_puzzled_cleared:
		return
	_close_all_active_doors()
	_show_puzzle_hint()
	_start_enemy_waves()
	_begin_timed_puzzles()

## True si la sala es de combate por encierro (Easy/Medium/Hard).
func _is_combat_room() -> bool:
	return room_type == ROOM_TYPE_EASY or room_type == ROOM_TYPE_MEDIUM or room_type == ROOM_TYPE_HARD

## Sala de combate: al entrar el jugador (si no la ha limpiado ya y no hay un combate
## en curso) cierra las puertas y dispara la oleada. El spawneo se difiere porque
## esto corre dentro del callback body_entered (física en pleno "flushing queries"),
## donde no se puede crear el Area2D de los enemigos.
func _enter_combat_room() -> void:
	if is_combat_cleared or _combat_active:
		return
	_close_all_active_doors()
	_start_combat.call_deferred()

## Spawnea la oleada de combate y empieza a vigilar las muertes para reabrir las
## puertas cuando no quede ningún enemigo. Spawnea sobre el piso del layout de
## combate instanciado (no sobre todo el interior de la sala): así el spawner, con su
## chequeo de navegabilidad por celda, descarta las celdas que ese layout dibujó como
## obstáculo y solo coloca enemigos sobre el suelo transitable. Si no hay piso de
## combate, pool vacía o spawn fallido, limpia la sala para no encerrar al jugador.
func _start_combat() -> void:
	var combat_floor := _combat_floor()
	if enemy_spawner == null or combat_floor == null:
		_clear_combat()
		return
	_combat_active = true
	if not enemy_spawner.child_exiting_tree.is_connected(_on_combat_enemy_exiting):
		enemy_spawner.child_exiting_tree.connect(_on_combat_enemy_exiting)
	enemy_spawner.spawn_pool(_combat_pools, combat_floor)
	# Sin enemigos vivos (pool vacía o spawn fallido): no encerrar al jugador.
	if _alive_combat_enemies() == 0:
		_clear_combat()

## Devuelve la TileMapLayer del layout de combate instanciado en Content (la escena
## raíz de Combat.tscn ES una TileMapLayer con suelo y obstáculos mezclados). El
## spawner descarta por celda las que no tienen polígono de navegación (los
## obstáculos), igual que con _puzzle_floor() en las salas de puzzle. Null si no hay.
func _combat_floor() -> TileMapLayer:
	return _find_tilemap_layer(content)

## Devuelve la primera TileMapLayer encontrada en el subárbol de `node` (búsqueda en
## profundidad), o null si no hay ninguna.
func _find_tilemap_layer(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child
		var found := _find_tilemap_layer(child)
		if found:
			return found
	return null

## Disparada cuando un hijo del spawner abandona el árbol. Si era un enemigo de la
## oleada, comprueba —de forma diferida, ya retirado del árbol— si era el último.
func _on_combat_enemy_exiting(child: Node) -> void:
	if not _combat_active or not child.is_in_group("Enemy"):
		return
	_check_combat_cleared.call_deferred()

## Da por limpiada la sala cuando ya no queda ningún enemigo vivo de la oleada.
func _check_combat_cleared() -> void:
	# Los enemigos también salen del árbol al desmontarse la escena (p. ej. menú del Game
	# Over tras morir en la sala). Si la propia sala ya salió del árbol no es una limpieza
	# real: se ignora para no anunciar "Sala completada" ni tocar un get_tree() nulo.
	if not is_inside_tree():
		return
	if not _combat_active:
		return
	if _alive_combat_enemies() > 0:
		return
	# Hubo combate real y cayó el último enemigo: avisa al jugador en su Message UI.
	# Se hace aquí (y no en _clear_combat) para no mostrarlo cuando la sala se limpia
	# sin combate (pool vacía o spawn fallido).
	_show_player_message("¡Sala completada!", 3.0)
	_clear_combat()

## Envía un mensaje breve al Message UI del jugador. Si no se encuentra al jugador
## (sala fuera de partida), simplemente no muestra nada.
func _show_player_message(text: String, duration: float = 3.0) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message(text, duration)

## Marca la sala como limpiada, deja de vigilar muertes y reabre las puertas que
## conectan con vecinos. Idempotente: reentrar no vuelve a encerrar al jugador.
func _clear_combat() -> void:
	_combat_active = false
	is_combat_cleared = true
	if enemy_spawner and enemy_spawner.child_exiting_tree.is_connected(_on_combat_enemy_exiting):
		enemy_spawner.child_exiting_tree.disconnect(_on_combat_enemy_exiting)
	_open_active_doors()

## Cuenta los enemigos vivos generados por el spawner de la sala (sus hijos del
## grupo "Enemy"). Permite saber cuándo se limpió el combate.
func _alive_combat_enemies() -> int:
	if enemy_spawner == null:
		return 0
	var count := 0
	for child in enemy_spawner.get_children():
		if child.is_in_group("Enemy"):
			count += 1
	return count

## Arranca los puzzles con temporizador propio (p. ej. el aritmético) al entrar el
## jugador, para que su validación no corra con la sala vacía.
func _begin_timed_puzzles() -> void:
	for child in content.get_children():
		if child is PuzzleArithmetic:
			child.begin()

## Pausa los puzzles con temporizador propio al salir el jugador.
func _halt_timed_puzzles() -> void:
	for child in content.get_children():
		if child is PuzzleArithmetic:
			child.halt()

## Pide al puzzle de la sala que muestre momentáneamente su pista en la UI, solo la
## primera vez: el de Pila/Cola muestra el orden objetivo; el de láser, la compuerta
## lógica actual. No hace nada si la pista ya se mostró antes.
func _show_puzzle_hint() -> void:
	if _hint_shown:
		return
	for child in content.get_children():
		if child is PuzzleStackQueue:
			child.show_order_hint()
			_hint_shown = true
			return
		elif child is PuzzleLaser:
			child.show_gate_hint()
			_hint_shown = true
			return

## Arranca las oleadas periódicas de enemigos. El temporizador se crea la primera
## vez y se reutiliza; el conteo de oleadas NO se reinicia, para que la dificultad
## siga escalando aunque el jugador entre y salga.
func _start_enemy_waves() -> void:
	if _wave_timer == null:
		_wave_timer = Timer.new()
		_wave_timer.timeout.connect(_on_wave_timer_timeout)
		add_child(_wave_timer)
	# El intervalo depende del puzzle de la sala (el de láser es más exigente).
	_wave_timer.wait_time = _wave_interval()
	_wave_timer.start()
	# El puzzle aritmético presiona desde el primer instante: primera oleada ya. Se
	# difiere porque esto corre dentro del callback body_entered (física en pleno
	# "flushing queries"), donde no se puede crear el Area2D de los enemigos.
	if _waves_start_immediately():
		_on_wave_timer_timeout.call_deferred()

## Intervalo entre oleadas según el puzzle de la sala: 7 s para el de láseres,
## el estándar (15 s) para el resto.
func _wave_interval() -> float:
	for child in content.get_children():
		if child is PuzzleLaser:
			return LASER_WAVE_INTERVAL_SECONDS
	return WAVE_INTERVAL_SECONDS

## Indica si la primera oleada debe lanzarse de inmediato al entrar, sin esperar al
## primer ciclo del temporizador. Lo usa el puzzle aritmético.
func _waves_start_immediately() -> bool:
	for child in content.get_children():
		if child is PuzzleArithmetic:
			return true
	return false

## Detiene las oleadas sin destruir el temporizador ni perder el conteo.
func _stop_enemy_waves() -> void:
	if _wave_timer:
		_wave_timer.stop()

## Cada oleada lanza enemigos básicos (easy); cada MEDIUM_EVERY_WAVES oleadas,
## además, enemigos medianos. Que sufra el jugador.
func _on_wave_timer_timeout() -> void:
	if enemy_spawner == null or is_puzzled_cleared:
		return
	# El piso del puzzle cambia tras cada reinicio, así que se resuelve por oleada.
	var puzzle_floor := _puzzle_floor()
	if puzzle_floor == null:
		return
	_wave_count += 1
	enemy_spawner.spawn_pool(easy_combat, puzzle_floor)
	if _wave_count % MEDIUM_EVERY_WAVES == 0:
		enemy_spawner.spawn_pool(medium_combat, puzzle_floor)

## Devuelve el piso navegable del puzzle actual (su corredor), buscando un nodo
## "FloorLayer" entre el contenido instanciado. Devuelve null si no lo encuentra.
func _puzzle_floor() -> TileMapLayer:
	for child in content.get_children():
		var floor_node := child.get_node_or_null("FloorLayer")
		if floor_node is TileMapLayer:
			return floor_node
	return null

## API pública: penalización para los puzzles (p. ej. la sobrecarga del puzzle láser
## en modo XOR). Lanza una oleada extra de enemigos básicos sobre el piso del puzzle,
## reutilizando el spawner. No hace nada si la sala no tiene spawner o piso.
func spawn_penalty_wave() -> void:
	if enemy_spawner == null:
		return
	var puzzle_floor := _puzzle_floor()
	if puzzle_floor == null:
		return
	reset_current_puzzle()
	enemy_spawner.spawn_pool(easy_combat, puzzle_floor)
	enemy_spawner.spawn_pool(medium_combat, puzzle_floor)

## API pública: penalización de cantidad CONTROLADA. Spawnea exactamente `count`
## enemigos básicos sobre el piso del puzzle, para no acumular oleadas enteras
## (p. ej. la penalización por residuo del puzzle aritmético).
func spawn_penalty_enemies(count: int) -> void:
	if enemy_spawner == null:
		return
	var puzzle_floor := _puzzle_floor()
	if puzzle_floor == null:
		return
	enemy_spawner.spawn_count(easy_combat, count, puzzle_floor)

## Al salir de la sala, desvincula al jugador para no resetearla desde fuera y
## detiene las oleadas (no deben seguir apareciendo enemigos en una sala vacía).
func _on_room_trigger_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.current_room == self:
		body.current_room = null
		_stop_enemy_waves()
		_halt_timed_puzzles()

## Recorre las 4 puertas y cierra (vuelve muro con colisión) solo aquellas que
## estaban abiertas porque conectaban con un vecino.
func _close_all_active_doors() -> void:
	_close_door_if_active(doors.get_node_or_null("NorthDoor"), _n_active)
	_close_door_if_active(doors.get_node_or_null("SouthDoor"), _s_active)
	_close_door_if_active(doors.get_node_or_null("EastDoor"), _e_active)
	_close_door_if_active(doors.get_node_or_null("WestDoor"), _w_active)

## Convierte una puerta abierta en muro: visible y con colisión activa.
func _close_door_if_active(door: Node2D, was_active: bool) -> void:
	if door == null or not was_active:
		return
	door.visible = true
	var collision := door.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", false)

## API pública: marca el puzzle como resuelto y reabre las puertas que conectan
## con vecinos, restaurando el estado original guardado en configure_room().
func complete_puzzle() -> void:
	is_puzzled_cleared = true
	# Puzzle resuelto: dejan de aparecer enemigos.
	_stop_enemy_waves()
	_open_active_doors()
	# Avisa al administrador del nivel (contador de puzzles y desbloqueo del Boss).
	room_cleared.emit(self)

## Reabre (restaura como pasillo) las puertas que conectan con un vecino, según el
## estado original guardado en configure_room().
func _open_active_doors() -> void:
	_configure_door(doors.get_node_or_null("NorthDoor"), _n_active)
	_configure_door(doors.get_node_or_null("SouthDoor"), _s_active)
	_configure_door(doors.get_node_or_null("EastDoor"), _e_active)
	_configure_door(doors.get_node_or_null("WestDoor"), _w_active)

## Sala del Boss: queda bloqueada de inicio cerrando (volviendo muro) las puertas
## que conectan con vecinos, hasta que el nivel la desbloquee.
func _lock_boss_room() -> void:
	_close_all_active_doors()

## API pública: desbloquea el acceso físico a la sala del Boss, reabriendo sus
## puertas hacia los vecinos. La llama el administrador del nivel al completar los puzzles.
func unlock_boss_room() -> void:
	_open_active_doors()

## API pública (botón "reset"): destruye el contenido dinámico actual del puzzle
## y vuelve a instanciar una copia limpia de la escena guardada.
func reset_current_puzzle() -> void:
	if room_type != ROOM_TYPE_PUZZLE or _current_puzzle_scene == null:
		return
	# Una vez resuelto el puzzle, las puertas quedan abiertas: reiniciar no tendría
	# sentido y dejaría el estado inconsistente, así que se ignora.
	if is_puzzled_cleared:
		return
	if content == null:
		return

	# El reset suele dispararse desde un callback de física (la placa de presión del
	# propio puzzle), momento en el que el motor está "flushing queries" y no permite
	# alterar el árbol ni el monitoring de las Area2D. Se difiere la reconstrucción
	# para ejecutarla fuera del flush y evitar el error del depurador.
	_rebuild_puzzle.call_deferred()

## Reconstrucción diferida del puzzle: elimina el contenido actual e instancia una
## copia limpia con el reto original. No llamar directamente; usar reset_current_puzzle().
func _rebuild_puzzle() -> void:
	if content == null:
		return

	# Marca los hijos actuales para eliminación.
	for child in content.get_children():
		child.queue_free()

	# Instancia una copia nueva (node_id distinto al hijo anterior).
	var instance := _current_puzzle_scene.instantiate()
	# Reimpone el reto original ANTES de añadirlo al árbol, para que su _ready() no
	# vuelva a sortearlo (Pila/Cola y orden; o la compuerta del láser).
	if instance is PuzzleStackQueue and _puzzle_mode != -1:
		instance.apply_fixed_config(_puzzle_mode, _puzzle_order)
	elif instance is PuzzleLaser and _puzzle_mode != -1:
		var objective_code := _puzzle_order[0] if not _puzzle_order.is_empty() else ""
		instance.apply_fixed_mode(_puzzle_mode, objective_code)
	content.add_child(instance)

	# El reset siempre ocurre con el jugador dentro de la sala, así que reanuda el
	# ciclo de los puzzles con temporizador propio sobre la copia nueva.
	if instance is PuzzleArithmetic:
		instance.begin()

	# Cada reinicio con F vuelve a mostrar la pista/objetivo del puzzle, para
	# recordarle al jugador qué debe hacer tras un fallo (el aritmético ya la
	# muestra en su begin(); este reset cubre el de Pila/Cola y el de láser).
	_hint_shown = false
	_show_puzzle_hint()

	# Notifica el reset para que la UI/sistemas externos se reconecten.
	puzzle_reset.emit()
