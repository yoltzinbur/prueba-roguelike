extends SamuraiState
## Reposo del Jefe. Es el estado inicial (mientras el jefe está inerte queda congelado aquí)
## y el de retorno. En cuanto hay un jugador válido pasa a perseguir.

func enter(args := {}):
	super.enter(args)
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	orient_body(direction_to_player())
	if anim and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

func state_process(delta: float) -> void:
	if is_instance_valid(player):
		transitioned.emit(self, "Chase", {})

func _on_damaged() -> void:
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
