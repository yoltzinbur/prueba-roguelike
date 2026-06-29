extends Node
## Router de arranque: revisa el guardado y entra al bosque o a la cueva. Es la
## escena principal del proyecto (el usuario la asigna en project.godot ->
## run/main_scene). Mantiene MainBueno.tscn fuera del flujo.

func _ready() -> void:
	# Se difiere para no cambiar de escena durante la inicialización del árbol.
	_route.call_deferred()

## Carga la escena que corresponde al punto de guardado.
func _route() -> void:
	if SaveManager.save_location == "forest":
		GameManager.load_scene(GameScenes.FORESTMAIN)
	else:
		GameManager.load_scene(GameScenes.MAINBUENO)
