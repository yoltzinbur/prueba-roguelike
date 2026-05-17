extends State

var input_component: InputComponent

func enter(args := {}):
	input_component = target.get_node("InputComponent")
	anim.play("idle")
	
func state_process(delta: float) -> void:
	if input_component.input_motion != Vector2.ZERO:
		emit_signal("transitioned", self, "Walk", {})
		
	if input_component.input_attack:
		emit_signal("transitioned", self, "IdleAttack", {})
		
	if input_component.input_heal:
		emit_signal("transitioned", self, "Heal", {})
