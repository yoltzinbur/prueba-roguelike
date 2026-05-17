extends State

var navigation_component: NavigationComponent
var velocity_component: VelocityComponent

func enter(args := {}):
	navigation_component = target.get_node("")
	velocity_component = target.get_node("")
	
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")
		
func state_physics_process(delta: float) -> void:
	var direction: Vector2 = navigation_component.get_next_direction(target)
	
	if direction.x != 0 and anim:
		anim.scale.x = roundi(sign(direction.x))
		
	velocity_component.move(delta, direction)
