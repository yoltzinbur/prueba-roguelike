extends State

func enter(args := {}):
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)

	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")

func state_physics_process(delta: float) -> void:
	var direction: Vector2 = navigation_component.get_next_direction(target)
	var separation: Vector2 = velocity_component.get_separation_vector()

	var final_direction = (direction + separation * 0.75).normalized()

	if direction == Vector2.ZERO:
		if not navigation_component.player or not is_instance_valid(navigation_component.player):
			transitioned.emit(self, "Idle", {})
			return

		velocity_component.move(delta, Vector2.ZERO)

		if anim and anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

		return
	else:
		if anim and anim.sprite_frames.has_animation("walk"):
			anim.play("walk")

	if direction.x != 0:
		anim.scale.x = roundi(sign(direction.x))

	velocity_component.move(delta, final_direction)

func _on_damaged():
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
