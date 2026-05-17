extends State

var healt_component: HealthComponent

func enter(args := {}):
	healt_component = target.get_node("HealthComponent")
	
	anim.play("heal")
	
	healt_component.heal(15)
	print(healt_component.current_health)
	
	await get_tree().create_timer(0.5).timeout
	emit_signal("transitioned", self, "Idle", {})
	
