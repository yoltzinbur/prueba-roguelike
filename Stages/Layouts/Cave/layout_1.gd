class_name RoomLayout
extends Node2D
## Plantilla de sala procedural. `configure_room()` ajusta las puertas (muro o
## apertura), inyecta el contenido interior y configura el EnemySpawner según el
## tipo de sala recibido desde el generador (cave_main.gd).

# Listas de contenido instanciable (configurables desde el editor).
@export var puzzle_list: Array[PackedScene]
@export var rest_list: Array[PackedScene]
@export var combat_list: Array[PackedScene] ## Layouts internos de combate.

# Pools de enemigos por dificultad, inyectadas al EnemySpawner.
@export var easy_combat: Array[SpawnCategory]
@export var medium_combat: Array[SpawnCategory]
@export var hard_combat: Array[SpawnCategory]
@export var boss_combat: Array[SpawnCategory]

# Cantidad máxima de enemigos por tipo de sala de combate.
@export var easy_max_enemies: int = 4
@export var medium_max_enemies: int = 6
@export var hard_max_enemies: int = 8
@export var boss_max_enemies: int = 1

@onready var doors: Node2D = $Doors
@onready var content: Node2D = $Content
@onready var enemy_spawner: Node2D = $EnemySpawner

## Emitida tras reinstanciar el contenido del puzzle en reset_current_puzzle().
## La UI o los sistemas externos pueden reconectarse al nuevo contenido aquí.
signal puzzle_reset

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
const WAVE_INTERVAL_SECONDS: float = 10.0
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
			_setup_combat(easy_combat, easy_max_enemies)
		ROOM_TYPE_MEDIUM:
			_setup_combat(medium_combat, medium_max_enemies)
		ROOM_TYPE_HARD:
			_setup_combat(hard_combat, hard_max_enemies)
		ROOM_TYPE_BOSS:
			_setup_combat(boss_combat, boss_max_enemies)
		ROOM_TYPE_PUZZLE:
			_setup_peaceful(puzzle_list)
		ROOM_TYPE_REST:
			_setup_peaceful(rest_list)
		_:
			# Sala de Inicio (Start) u otras: pacífica y sin contenido.
			_clear_spawner()

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

## Sala de combate: inyecta las pools al spawner y, si existen, instancia un
## layout interno de combate al azar.
func _setup_combat(pools: Array[SpawnCategory], max_enemies: int) -> void:
	_spawn_interior(combat_list)

	if enemy_spawner == null:
		return
	# El spawner ejecuta spawn_all_categories() de forma diferida en su _ready();
	# configure_room() corre antes de ese diferido, así que basta actualizar sus
	# propiedades aquí para que use las pools correctas.
	enemy_spawner.spawn_categories = pools
	enemy_spawner.max_enemies = max_enemies

## Sala pacífica (Puzzle/Rest): instancia contenido y limpia el spawner.
func _setup_peaceful(scene_list: Array[PackedScene]) -> void:
	# Guarda la escena elegida antes de instanciarla para poder clonarla en el
	# reset. En salas Rest queda registrada también, pero reset_current_puzzle()
	# solo actúa sobre salas de tipo Puzzle.
	var instance := _spawn_interior(scene_list)
	# Recuerda modo y secuencia sorteados por el puzzle para conservarlos en los
	# reinicios.
	if instance is PuzzleStackQueue:
		_puzzle_mode = instance.mode
		_puzzle_order = instance.target_order.duplicate()
	_clear_spawner()

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

## Vacía las categorías del spawner para que no aparezcan enemigos.
func _clear_spawner() -> void:
	if enemy_spawner == null:
		return
	var empty: Array[SpawnCategory] = []
	enemy_spawner.spawn_categories = empty
	enemy_spawner.max_enemies = 0

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

## Pide al puzzle de la sala que muestre momentáneamente la pista del orden en
## la UI, solo la primera vez. No hace nada si el contenido no es un
## PuzzleStackQueue o si la pista ya se mostró antes.
func _show_puzzle_hint() -> void:
	if _hint_shown:
		return
	for child in content.get_children():
		if child is PuzzleStackQueue:
			child.show_order_hint()
			_hint_shown = true
			return

## Arranca las oleadas periódicas de enemigos. El temporizador se crea la primera
## vez y se reutiliza; el conteo de oleadas NO se reinicia, para que la dificultad
## siga escalando aunque el jugador entre y salga.
func _start_enemy_waves() -> void:
	print("Wave")
	if _wave_timer == null:
		_wave_timer = Timer.new()
		_wave_timer.wait_time = WAVE_INTERVAL_SECONDS
		_wave_timer.timeout.connect(_on_wave_timer_timeout)
		add_child(_wave_timer)
	_wave_timer.start()

## Detiene las oleadas sin destruir el temporizador ni perder el conteo.
func _stop_enemy_waves() -> void:
	if _wave_timer:
		_wave_timer.stop()

## Cada oleada lanza enemigos básicos (easy); cada MEDIUM_EVERY_WAVES oleadas,
## además, enemigos medianos. Que sufra el jugador.
func _on_wave_timer_timeout() -> void:
	print("New wave: ", _wave_count)
	if enemy_spawner == null or is_puzzled_cleared:
		print("Error 1. New wave: ", _wave_count)
		return
	# Reapunta el spawner al piso del puzzle actual (cambia tras cada reinicio).
	if not _aim_spawner_at_puzzle_floor():
		print("Error 2. New wave: ", _wave_count)
		return
	_wave_count += 1
	enemy_spawner.spawn_pool(easy_combat)
	if _wave_count % MEDIUM_EVERY_WAVES == 0:
		enemy_spawner.spawn_pool(medium_combat)

## Apunta el spawner al piso navegable del puzzle (su corredor) y le pasa el
## jugador para respetar la distancia mínima de aparición. Devuelve false si no
## encuentra un FloorLayer donde spawnear.
func _aim_spawner_at_puzzle_floor() -> bool:
	for child in content.get_children():
		var floor_node := child.get_node_or_null("FloorLayer")
		if floor_node is TileMapLayer:
			enemy_spawner.floor_layer = floor_node
			enemy_spawner.player = get_tree().get_first_node_in_group("Player")
			return true
	return false

## Al salir de la sala, desvincula al jugador para no resetearla desde fuera y
## detiene las oleadas (no deben seguir apareciendo enemigos en una sala vacía).
func _on_room_trigger_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.current_room == self:
		body.current_room = null
		_stop_enemy_waves()

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
	_configure_door(doors.get_node_or_null("NorthDoor"), _n_active)
	_configure_door(doors.get_node_or_null("SouthDoor"), _s_active)
	_configure_door(doors.get_node_or_null("EastDoor"), _e_active)
	_configure_door(doors.get_node_or_null("WestDoor"), _w_active)

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

	# Marca los hijos actuales para eliminación.
	for child in content.get_children():
		child.queue_free()

	# Instancia una copia nueva (node_id distinto al hijo anterior).
	var instance := _current_puzzle_scene.instantiate()
	# Reimpone modo y secuencia originales ANTES de añadirlo al árbol, para que su
	# _ready() no vuelva a sortear el reto (naturaleza Pila/Cola y orden).
	if instance is PuzzleStackQueue and _puzzle_mode != -1:
		instance.apply_fixed_config(_puzzle_mode, _puzzle_order)
	content.add_child(instance)

	# Notifica el reset para que la UI/sistemas externos se reconecten.
	puzzle_reset.emit()
