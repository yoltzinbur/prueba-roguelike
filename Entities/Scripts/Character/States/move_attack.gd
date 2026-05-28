extends State

var health_component: HealthComponent

@export var hitbox: CollisionShape2D

func enter(args := {}):
	health_component = target.get_node("HealthComponent")
	
	if args.has("direction"):
		anim.play("attack")
		args["velocity_component"].move(0, args["direction"] * args["force"])
	
	if hitbox:
		hitbox.disabled = false
	
	await get_tree().create_timer(0.5).timeout
	emit_signal("transitioned", self, "Idle", {})

func exit():
	if hitbox:
		hitbox.disabled = true
