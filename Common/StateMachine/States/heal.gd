extends State

var health_component: HealthComponent

func enter(args := {}):
	health_component = target.get_node("HealthComponent")
	
	# 1. Verificar si el jugador tiene pociones disponibles (flasks)
	if health_component and health_component.flasks > 0:
		# 2. Restar una poción
		health_component.flasks -= 1
		
		# 3. Reproducir animación y curar
		anim.play("heal")
		health_component.heal(20)
	
	# Esperar a que termine la acción y regresar a Idle
	await get_tree().create_timer(0.5).timeout
	emit_signal("transitioned", self, "Idle", {})
