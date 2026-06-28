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

# Piso navegable propio de la sala: sobre sus celdas aparecen los enemigos de las
# salas de combate. Se resuelve solo desde $Layers (no requiere asignación manual
# en el inspector), priorizando la capa dedicada "navigation_floor".
@onready var floor_layer: TileMapLayer = _find_floor_layer()

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

## Sala de combate: instancia (si existe) un layout interno de combate y pide al
## spawner que aparezca la pool sobre el piso de la sala. El spawneo se difiere
## para que el mapa de navegación ya esté listo cuando aparezcan los enemigos.
func _setup_combat(pools: Array[SpawnCategory]) -> void:
	_spawn_interior(combat_list)

	if enemy_spawner == null:
		return
	enemy_spawner.call_deferred("spawn_pool", pools, floor_layer)

## Sala del Jefe: instancia su layer dedicado (BossRoom), que trae su propio mapa y
## al jefe ya colocado dentro, y bloquea las puertas hasta que el nivel desbloquee la
## sala (al completar los puzzles). No usa el EnemySpawner: el jefe es parte de la
## escena instanciada, no se spawnea desde una pool.
func _setup_boss() -> void:
	_spawn_interior(boss_list)
	_lock_boss_room()

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

## Busca la capa de piso navegable de la sala bajo $Layers. Prioriza la capa
## dedicada "navigation_floor" (separada del "floor" visual); si no existe, cae a
## la primera TileMapLayer cuyo nombre contenga "floor" (escenas antiguas).
## Devuelve null si no encuentra ninguna.
func _find_floor_layer() -> TileMapLayer:
	var layers := get_node_or_null("Layers")
	if layers == null:
		push_warning("[RoomLayout] No se encontró el nodo 'Layers' con el piso navegable.")
		return null
	var nav := layers.get_node_or_null("navigation_floor")
	if nav is TileMapLayer:
		return nav
	for child in layers.get_children():
		if child is TileMapLayer and "floor" in String(child.name).to_lower():
			return child
	push_warning("[RoomLayout] No se encontró una TileMapLayer de piso ('navigation_floor' o 'floor') bajo 'Layers'.")
	return null

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
	if room_type != ROOM_TYPE_PUZZLE or is_puzzled_cleared:
		return
	_close_all_active_doors()
	_show_puzzle_hint()
	_start_enemy_waves()
	_begin_timed_puzzles()

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

	# Notifica el reset para que la UI/sistemas externos se reconecten.
	puzzle_reset.emit()
