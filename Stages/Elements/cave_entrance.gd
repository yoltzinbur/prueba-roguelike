extends StaticBody2D
## Entrada a la cueva desde el bosque. Mientras queden niveles por completar, lleva
## al jugador a la cueva (siguiente nivel). Una vez completados todos los niveles, la
## cueva deja de ser accesible y da paso al jefe final (aún por implementar).

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	# Completados todos los niveles: la cueva ya no es accesible; toca el jefe final.
	if SaveManager.levels_completed >= SaveManager.TOTAL_LEVELS:
		var player := get_tree().get_first_node_in_group("Player")
		if player != null and player.has_method("show_message"):
			player.show_message("¡El jefe final llegará pronto!")
		# TODO: cuando exista la escena del jefe final, cargarla aquí en vez del aviso:
		# GameManager.load_scene(GameScenes.FINAL_BOSS)
		return
	# El run de cueva no se persiste: si el jugador sale a mitad, reanuda en el bosque.
	GameManager.load_scene(GameScenes.STARTCAVE)
