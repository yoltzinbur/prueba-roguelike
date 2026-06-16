extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

func _on_reiniciar_pressed():
	get_tree().paused = false
	queue_free()  # ← elimina el GameOver primero
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().paused = false
	queue_free()  # ← también aquí
	get_tree().change_scene_to_file("res://Utilities/MainMenu/MainMenu.tscn")
