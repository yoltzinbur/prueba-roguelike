extends State

var audioWalk: AudioStreamPlayer
var hitbox: HitBox
var current_dir: String = ""

func enter(args := {}):
	audioWalk = target.get_node_or_null("Audios/Walk")
	hitbox = target.get_node_or_null("HitBox")

	current_dir = input_component.last_direction if input_component else "down"
	play_directional_anim("walk")
	if audioWalk:
		audioWalk.play()

	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)

func state_process(delta: float) -> void:
	if input_component.input_motion == Vector2.ZERO:
		transitioned.emit(self, "Idle", {})
		return

	var new_dir = input_component.last_direction if input_component else "down"
	if new_dir != current_dir:
		current_dir = new_dir
		play_directional_anim("walk")

	velocity_component.move(delta, input_component.input_motion)

	if input_component.input_attack:
		transitioned.emit(self, "MoveAttack", {
			"direction": input_component.input_motion,
			"velocity_component": velocity_component,
			"force": 10
		})

	if input_component.input_heal:
		transitioned.emit(self, "Heal", {})

	if input_component.input_dodge:
		transitioned.emit(self, "Dodge", {})

	if input_component.input_parry:
		transitioned.emit(self, "Parry", {})

	adjust_hitbox_position()

func _on_damaged():
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)

	if audioWalk:
		audioWalk.stop()

func adjust_hitbox_position():
	if hitbox == null:
		return

	# Usamos la dirección dominante ya calculada (abs(x) vs abs(y)) en lugar de
	# mirar input_motion.y/x sueltos: con el joystick analógico un empuje lateral
	# casi siempre deja un residuo vertical mínimo, y comprobar la "y" primero
	# hacía que la hitbox nunca apuntara a los lados.
	match input_component.last_direction:
		"up":
			hitbox.position = Vector2(0, -19)
		"down":
			hitbox.position = Vector2(0, 27)
		"right":
			hitbox.position = Vector2(20, 5)
		"left":
			hitbox.position = Vector2(-20, 5)
