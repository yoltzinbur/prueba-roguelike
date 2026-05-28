extends State

@export var hitbox: CollisionShape2D

var health_component: HealthComponent

func enter(args := {}):	
	health_component = target.get_node("HealthComponent")
	
	anim.play("attack")
	
	if hitbox:
		hitbox.disabled = false
	
	await get_tree().create_timer(0.5).timeout
	emit_signal("transitioned", self, "Idle", {})

func exit():
	if hitbox:
		hitbox.disabled = true
