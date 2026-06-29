extends Node2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	$Control/AudioStart.play()
	get_tree().change_scene_to_file("res://Stages/Main/MainBueno.tscn")

func _on_options_pressed() -> void:
	$Control/AudioStart.play()
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	$Control/AudioStart.play()
	get_tree().quit()# Replace with function body.
