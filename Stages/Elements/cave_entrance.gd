extends StaticBody2D
## Entrada a la cueva desde el bosque. Mientras queden niveles por completar, lleva
## al jugador a la cueva (siguiente nivel). Una vez completados todos los niveles, la
## cueva (puzzle) ya está resuelta y no vuelve a ser accesible; el jefe final se accede
## por el BossPortal del bosque.

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	# Completados todos los niveles: el puzzle de la cueva ya está resuelto.
	if SaveManager.levels_completed >= SaveManager.TOTAL_LEVELS:
		var player := get_tree().get_first_node_in_group("Player")
		if player != null and player.has_method("show_message"):
			player.show_message("El puzzle ya está completado.")
		return
	# El run de cueva no se persiste: si el jugador sale a mitad, reanuda en el bosque.
	GameManager.load_scene(GameScenes.STARTCAVE)
