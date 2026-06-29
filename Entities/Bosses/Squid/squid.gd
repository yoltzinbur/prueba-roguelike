extends CharacterBody2D
## Raíz del Jefe Squid (jefe final). Nace inerte (process_mode = DISABLED en la escena) y
## sólo empieza a procesar —perseguir/atacar— cuando la arena lo activa al detectar al
## jugador (LayoutFinal: RoomTrigger / solape inicial).

var _activated: bool = false

## Llamada por la arena del jefe final cuando el jugador entra. Saca al Squid del estado
## inerte para que su StateMachine y componentes vuelvan a procesar. Idempotente.
func activate() -> void:
	if _activated:
		return
	_activated = true
	process_mode = Node.PROCESS_MODE_INHERIT

## Aturde al jefe (Guard Break): fuerza el estado Stun por `duration` segundos. La llama el
## jugador al completar el 3er reflejo. change_state ejecuta el exit() del estado actual (p. ej.
## desactiva el hitbox si estaba atacando) y deja al jefe quieto hasta volver a Chase.
func stun(duration: float = 3.0) -> void:
	var sm := $StateMachine
	if sm and sm.states.has("Stun") and sm.current_state:
		sm.change_state(sm.current_state, "Stun", {"duration": duration})
