extends CharacterBody2D
## Raíz del Jefe Samurai. Nace inerte (process_mode = DISABLED en la escena) y solo
## empieza a procesar —y por tanto a perseguir/atacar— cuando la sala del Jefe lo activa
## al detectar al jugador entrando (RoomTrigger → RoomLayout._activate_boss()).

var _activated: bool = false

## Llamada por la sala (RoomLayout) cuando el jugador entra a la sala del Jefe. Saca al
## Samurai del estado inerte para que su StateMachine y componentes vuelvan a procesar.
func activate() -> void:
	if _activated:
		return
	_activated = true
	process_mode = Node.PROCESS_MODE_INHERIT
