extends State

@export var velocity_component: VelocityComponent
var parent: Node2D
var original_velocity: Vector2

func enter(args := {}):	
	# Guardar la velocidad original antes de aplicar retroceso
	if velocity_component:
		original_velocity = velocity_component.velocity
	
	# Aplicar retroceso suave
	if velocity_component and original_velocity != Vector2.ZERO:
		# Retroceso de 100 unidades en dirección opuesta al movimiento
		var knockback_direction = -original_velocity.normalized()
		var knockback_force = 100.0
		velocity_component.velocity = knockback_direction * knockback_force
	
	if anim and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	
	if velocity_component:
		# Detener movimiento durante el daño
		velocity_component.move(get_process_delta_time(), Vector2.ZERO)
		set_process_input(false)
	
	# Esperar 1 segundo antes de continuar
	await get_tree().create_timer(1.0).timeout
	
	# Restaurar velocidad original si es necesario
	if velocity_component:
		velocity_component.velocity = original_velocity
	
	# Transicionar al siguiente estado
	var next_state = "Chase" if target.is_in_group("Enemy") else "Walk"
	emit_signal("transitioned", self, next_state, {})
