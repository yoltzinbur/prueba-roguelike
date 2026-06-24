extends State

@export var dodge_duration: float = 0.3
@export var dodge_speed: float = 250.0

var dodge_direction: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0
var hurtbox: Area2D

func enter(args := {}):
	time_elapsed = 0.0
	hurtbox = target.get_node_or_null("HurtBox")

	dodge_direction = input_component.input_motion if input_component else Vector2.ZERO
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.RIGHT if anim.scale.x >= 0 else Vector2.LEFT
	dodge_direction = dodge_direction.normalized()

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)

	anim.modulate = Color(1, 1, 1, 0.5)

	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")

func state_physics_process(delta: float) -> void:
	time_elapsed += delta

	if time_elapsed >= dodge_duration:
		transitioned.emit(self, "Idle", {})
		return

	target.velocity = dodge_direction * dodge_speed
	target.move_and_slide()

func exit():
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)

	anim.modulate = Color(1, 1, 1, 1)
