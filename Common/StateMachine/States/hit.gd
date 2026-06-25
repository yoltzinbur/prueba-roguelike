extends State

@export var knockback_duration: float = 0.25
@export var knockback_force: float = 100.0

var knockback_velocity: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0

func enter(args := {}):
	time_elapsed = 0.0

	var current_velocity = target.velocity
	if current_velocity != Vector2.ZERO:
		knockback_velocity = -current_velocity.normalized() * knockback_force
	elif input_component:
		match input_component.last_direction:
			"left": knockback_velocity = Vector2.RIGHT * knockback_force
			"right": knockback_velocity = Vector2.LEFT * knockback_force
			"up": knockback_velocity = Vector2.DOWN * knockback_force
			_: knockback_velocity = Vector2.UP * knockback_force
	else:
		knockback_velocity = Vector2.LEFT * knockback_force

	play_directional_anim("hit")

func state_physics_process(delta: float) -> void:
	time_elapsed += delta

	if time_elapsed >= knockback_duration:
		var next_state = "Chase" if target.is_in_group("Enemy") else "Walk"
		transitioned.emit(self, next_state, {})
		return

	var current_frame_knockback = knockback_velocity * (1.0 - (time_elapsed / knockback_duration))

	if velocity_component:
		velocity_component._apply_movement(current_frame_knockback)
