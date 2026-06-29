extends StaticBody2D
## Punto de guardado del bosque. Al interactuar, rellena al jugador, fija el bosque
## como punto de guardado y persiste la partida.

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	SaveManager.apply_player_state(player)
	SaveManager.save_location = "forest"
	# Reaparecer frente al SavePoint al reanudar. El aviso "Partida guardada" lo emite
	# save_game() (se muestra en cada guardado real, no sólo aquí).
	SaveManager.forest_spawn = "savepoint"
	SaveManager.save_game()
