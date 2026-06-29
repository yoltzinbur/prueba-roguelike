extends Node2D
## Escena del bosque (hub). Instancia al jugador bajo el nodo Sorting (para que use
## el y-sort de la aldea), restaura su estado guardado y marca el bosque como punto
## de guardado al llegar. También revela el BossPortal cuando se completaron todos los
## niveles y avisa de la aparición del Tótem al volver del segundo nivel.

const PLAYER_SCENE := "res://Entities/Player/Player.tscn"

@onready var sorting: Node2D = $Sorting
@onready var boss_portal: Node = $Sorting/BossPortal

func _ready() -> void:
	# El motivo de llegada (spawn) se consume UNA vez: decide el marcador y si avisar del Tótem.
	var spawn_key := SaveManager.consume_forest_spawn()
	var player := _spawn_player(spawn_key)
	if player != null:
		SaveManager.register_forest_arrival(player)

	_update_boss_portal()

	# Al volver tras completar el segundo nivel, aparece el portal del jefe final (Tótem).
	if spawn_key == "level2" and player != null and player.has_method("show_message"):
		player.show_message("Ha aparecido un Tótem desconocido...")

## Instancia al jugador como hijo de Sorting en el marcador que corresponde al caso.
func _spawn_player(spawn_key: String) -> Node:
	var scene: PackedScene = load(PLAYER_SCENE)
	if scene == null:
		return null
	var player := scene.instantiate()
	sorting.add_child(player)
	var spawn := _spawn_marker(spawn_key)
	if player is Node2D and spawn != null:
		player.global_position = spawn.global_position
	return player

## Marcador de aparición según por qué se llega al bosque:
## "savepoint" (frente al SavePoint), "level2" (frente a la cueva) o "level1" (defecto).
func _spawn_marker(spawn_key: String) -> Marker2D:
	match spawn_key:
		"savepoint":
			return $Sorting/SpawnSavePoint
		"level2":
			return $Sorting/SpawnLevel2
		_:
			return $Sorting/SpawnLevel1

## Configura el BossPortal según el progreso: si el jefe ya fue derrotado, queda "purificado"
## (oculto, sólo avisa al pasar); si se completaron los niveles y sigue vivo, queda activo;
## en otro caso, bloqueado.
func _update_boss_portal() -> void:
	if boss_portal == null:
		return
	if SaveManager.boss_defeated:
		if boss_portal.has_method("set_purified"):
			boss_portal.set_purified()
	elif boss_portal.has_method("set_active"):
		boss_portal.set_active(SaveManager.levels_completed >= SaveManager.TOTAL_LEVELS)
