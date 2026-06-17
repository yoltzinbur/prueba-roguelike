extends State

var input_component: InputComponent
var velocity_component: VelocityComponent
var health_component: HealthComponent
var audioWalk: AudioStreamPlayer 
var hitbox: HitBox

func enter(args := {}):
	input_component = target.get_node("InputComponent")
	velocity_component = target.get_node("VelocityComponent")
	health_component = target.get_node("HealthComponent")
	audioWalk = target.get_node_or_null("Audios/Walk")
	hitbox = target.get_node("HitBox")
	
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")
		if audioWalk:
			audioWalk.play()
	
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	
	# Ajustar posición de la hitbox según dirección
	adjust_hitbox_position()

func state_process(delta: float) -> void:
	if input_component.input_motion == Vector2.ZERO:
		emit_signal("transitioned", self, "Idle", {})
	elif input_component.input_motion.x != 0:
		target.get_node("AnimatedSprite2D").scale.x = roundi(input_component.input_motion.x)
		target.get_node("HitBox").scale.x = roundi(input_component.input_motion.x)

	velocity_component.move(delta, input_component.input_motion)

	if input_component.input_attack:
		emit_signal("transitioned", self, "MoveAttack", {
			"direction": input_component.input_motion,
			"velocity_component": velocity_component,
			"force": 10
		})
		
	if input_component.input_heal:
		emit_signal("transitioned", self, "Heal", {})

func _on_damaged():
	emit_signal("transitioned", self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
	
	if audioWalk:
		audioWalk.stop()

func adjust_hitbox_position():
	if hitbox == null:
		return
		
	# Ajustar posición de la hitbox según dirección del movimiento
	if input_component.input_motion.y < 0:  # Mirando hacia arriba
		hitbox.position = Vector2(0, -19)
	elif input_component.input_motion.y > 0:  # Mirando hacia abajo
		hitbox.position = Vector2(0, 27)
	else:  # En otras direcciones, posición por defecto
		hitbox.position = Vector2(0, 0)
