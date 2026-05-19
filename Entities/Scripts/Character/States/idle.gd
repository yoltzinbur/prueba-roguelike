extends State

var input_component: InputComponent

func enter(args := {}):
	input_component = target.get_node("InputComponent")
	anim.play("idle")
	
func state_process(delta: float) -> void:
	if input_component.input_motion != Vector2.ZERO:
		var next_state = "Chase" if target.is_in_group("Enemy") else "Walk" 
		emit_signal("transitioned", self, next_state, {})
		
	if input_component.input_attack:
		emit_signal("transitioned", self, "IdleAttack", {})
		
	if input_component.input_heal:
		emit_signal("transitioned", self, "Heal", {})
