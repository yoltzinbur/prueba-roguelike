extends State

@export var velocity_component: VelocityComponent
var parent: Node2D

func enter(args := {}):	
	if anim and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	
	if velocity_component:
		velocity_component.move(get_process_delta_time(), Vector2.ZERO)
		set_process_input(false)
	
	if anim:
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.3).timeout
	
	var next_state = "Chase" if target.is_in_group("Enemy") else "Walk"
	emit_signal("transitioned", self, next_state, {})
