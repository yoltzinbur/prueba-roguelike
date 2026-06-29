extends State

func enter(args := {}):
	if health_component and health_component.flasks > 0:
		health_component.flasks -= 1
		$"../../Audios/Heal".play()
		anim.play("heal")
		health_component.heal(20)
		await get_tree().create_timer(0.5).timeout

	transitioned.emit(self, "Idle", {})
