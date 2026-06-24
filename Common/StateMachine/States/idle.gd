extends State

func enter(args := {}):
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)

	anim.play("idle")

func state_process(delta: float) -> void:
	if input_component:
		if input_component.input_motion != Vector2.ZERO:
			var next_state = "Chase" if target.is_in_group("Enemy") else "Walk"
			transitioned.emit(self, next_state, {})

		if input_component.input_attack:
			transitioned.emit(self, "IdleAttack", {})

		if input_component.input_heal:
			transitioned.emit(self, "Heal", {})

		if input_component.input_dodge:
			transitioned.emit(self, "Dodge", {})

func _on_damaged():
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
