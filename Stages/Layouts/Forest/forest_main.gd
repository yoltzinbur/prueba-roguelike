extends Node2D
## Escena del bosque (hub). Instancia al jugador bajo el nodo Sorting (para que use
## el y-sort de la aldea), restaura su estado guardado y marca el bosque como punto
## de guardado al llegar.

const PLAYER_SCENE := "res://Entities/Player/Player.tscn"

@onready var sorting: Node2D = $Sorting
@onready var player_spawn: Marker2D = $Sorting/PlayerSpawn

func _ready() -> void:
	var player := _spawn_player()
	if player != null:
		SaveManager.register_forest_arrival(player)

## Instancia al jugador como hijo de Sorting en la posición de PlayerSpawn.
func _spawn_player() -> Node:
	var scene: PackedScene = load(PLAYER_SCENE)
	if scene == null:
		return null
	var player := scene.instantiate()
	sorting.add_child(player)
	if player is Node2D and player_spawn != null:
		player.global_position = player_spawn.global_position
	return player
