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

## Punto de entrada llamado por el generador. Abre/cierra las puertas según los
## vecinos e inyecta contenido o enemigos según el tipo de sala.
func configure_room(type: String, north: bool, south: bool, east: bool, west: bool) -> void:
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
	_spawn_interior(scene_list)
	_clear_spawner()

## Elige una escena al azar de la lista y la añade como hija de Content.
func _spawn_interior(scene_list: Array[PackedScene]) -> void:
	if scene_list.is_empty() or content == null:
		return
	var scene: PackedScene = scene_list.pick_random()
	if scene == null:
		return
	content.add_child(scene.instantiate())

## Vacía las categorías del spawner para que no aparezcan enemigos.
func _clear_spawner() -> void:
	if enemy_spawner == null:
		return
	var empty: Array[SpawnCategory] = []
	enemy_spawner.spawn_categories = empty
	enemy_spawner.max_enemies = 0
