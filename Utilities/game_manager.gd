extends Node

signal coins_updated(total_coins: int)

var coins: int = 0:
	set(value):
		coins = value
		coins_updated.emit(coins)

func add_coins(amount: int = 1) -> void:
	coins += amount

func load_scene(scene_path: String) -> void:
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("No se pudo cargar la escena en la ruta: " + scene_path)
