extends SquidState
## Reposo del Jefe. Estado inicial (mientras el jefe está inerte queda congelado aquí) y de
## retorno. Tras activarse espera unos segundos (margen de gracia) antes de detectar al
## jugador y empezar a perseguir. Si recibe daño antes, reacciona igualmente (Hit).

## Segundos de espera tras activarse antes de detectar al jugador.
@export var detection_delay: float = 5.0

# Tiempo acumulado desde que el jefe se activó (state_process sólo corre estando activo).
var _t: float = 0.0

func enter(args := {}):
	super.enter(args)
	_t = 0.0
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	if anim and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

func state_process(delta: float) -> void:
	_t += delta
	# El jugador puede no existir todavía cuando se ejecutó enter() (la arena instancia al
	# jugador después del jefe), así que se reintenta resolver cada frame.
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
	if _t >= detection_delay and is_instance_valid(player):
		transitioned.emit(self, "Chase", {})

func _on_damaged() -> void:
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
