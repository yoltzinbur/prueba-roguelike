extends Control

func _ready():
	$AnimationPlayer.play("RESET")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Fuerza también el CanvasLayer padre
	get_parent().process_mode = Node.PROCESS_MODE_ALWAYS

func resume():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	visible = false

func pause():
	print("pause llamado, visible antes: ", visible)
	visible = true
	print("visible ahora: ", visible)
	$AnimationPlayer.play("blur")
	get_tree().paused = true
	
func testEsc():
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused == false:
			pause()
		else:
			resume()

func _process(delta):
	testEsc()

# --- Señales de los botones ---
func _on_reanudar_pressed() -> void:
	resume()

func _on_reiniciar_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_salir_pressed() -> void:
	get_tree().quit()
