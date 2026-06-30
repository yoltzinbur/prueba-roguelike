extends Node2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	$Control/AudioStart.play()
	# Arranca el router de boot, que decide si llevar al bosque o a la cueva según
	# el guardado. Antes saltaba directo a MainBueno y se brincaba ese ruteo.
	GameManager.load_scene(GameScenes.BOOT)

func _on_options_pressed() -> void:
	$Control/AudioStart.play()
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	$Control/AudioStart.play()
	get_tree().quit()# Replace with function body.
