extends Control

func _ready():
	$AnimationPlayer.play("RESET")

func resume():
	get_tree().paused=false
	$AnimationPlayer.play_backwards("blur")
	
func pause():
	get_tree().paused= true
	$AnimationPlayer.play("blur")
	
func testEsc():
	if Input.is_action_just_pressed("pause") and get_tree().paused==false:
		pause()
	elif Input.is_action_just_pressed("pause") and get_tree().paused==true:
		resume()
		

func _on_reanudar_pressed() -> void:
	resume() # Replace with function body.
	

func _on_reiniciar_pressed() -> void:
	get_tree().paused=false
	get_tree().reload_current_scene() # Replace with function body.
	
	

func _on_salir_pressed() -> void:
	get_tree().quit() # Replace with function body.
	
func _process(delta):
	testEsc()
