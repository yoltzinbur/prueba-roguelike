extends State

var navigation_component: NavigationComponent
var velocity_component: VelocityComponent

func enter(args := {}):
	navigation_component = target.get_node("NavigationComponent")
	velocity_component = target.get_node("VelocityComponent")
	
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")

func state_physics_process(delta: float) -> void:	
	var direction: Vector2 = navigation_component.get_next_direction(target)
	
	print(direction)
	
	if direction == Vector2.ZERO:
		if not navigation_component.player or not is_instance_valid(navigation_component.player):
			emit_signal("transitioned", self, "Idle", {})
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
		
	velocity_component.move(delta, direction)
	
