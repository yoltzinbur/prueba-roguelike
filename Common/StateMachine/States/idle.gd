extends State

var input_component: InputComponent
var health_component: HealthComponent

func enter(args := {}):
	input_component = target.get_node("InputComponent")
	health_component = target.get_node("HealthComponent")
	
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	
	anim.play("idle")
	
func state_process(delta: float) -> void:
	if input_component:
		if input_component.input_motion != Vector2.ZERO:
			var next_state = "Chase" if target.is_in_group("Enemy") else "Walk" 
			emit_signal("transitioned", self, next_state, {})
			
		if input_component.input_attack:
			emit_signal("transitioned", self, "IdleAttack", {})
			
		if input_component.input_heal:
			emit_signal("transitioned", self, "Heal", {})

func _on_damaged():
	emit_signal("transitioned", self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
