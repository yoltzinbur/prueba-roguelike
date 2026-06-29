extends Node2D
## Escena del bosque (hub). Instancia al jugador bajo el nodo Sorting (para que use
## el y-sort de la aldea), restaura su estado guardado y marca el bosque como punto
## de guardado al llegar.

const PLAYER_SCENE := "res://Entities/Player/Player.tscn"

@onready var sorting: Node2D = $Sorting

func _ready() -> void:
	var player := _spawn_player()
	if player != null:
		SaveManager.register_forest_arrival(player)

## Instancia al jugador como hijo de Sorting en el marcador que corresponde al caso.
func _spawn_player() -> Node:
	var scene: PackedScene = load(PLAYER_SCENE)
	if scene == null:
		return null
	var player := scene.instantiate()
	sorting.add_child(player)
	var spawn := _spawn_marker()
	if player is Node2D and spawn != null:
		player.global_position = spawn.global_position
	return player

## Marcador de aparición según por qué se llega al bosque (lo fija SaveManager):
## "savepoint" (frente al SavePoint), "level2" (frente a la cueva) o "level1" (defecto).
func _spawn_marker() -> Marker2D:
	match SaveManager.consume_forest_spawn():
		"savepoint":
			return $Sorting/SpawnSavePoint
		"level2":
			return $Sorting/SpawnLevel2
		_:
			return $Sorting/SpawnLevel1
