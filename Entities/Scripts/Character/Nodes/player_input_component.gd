class_name PlayerInputComponent
extends InputComponent

func _process(delta: float) -> void:
	input_motion = Input.get_vector("left", "right", "up", "down")
	input_attack = Input.is_action_just_pressed("attack")
	input_heal = Input.is_action_just_pressed("heal")
	input_action = Input.is_action_just_pressed("enter")
	input_dodge = Input.is_action_just_pressed("dodge")

	if input_motion != Vector2.ZERO:
		TutorialManager.registrar_accion("moverse")
	
	if input_attack:
		TutorialManager.registrar_accion("atacar")
		
	if input_heal:
		TutorialManager.registrar_accion("curar")
