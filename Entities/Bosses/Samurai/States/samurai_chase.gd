extends SamuraiState
## Cerebro de combate del Jefe: persigue al jugador directamente (sin pathfinding, la sala
## del jefe es una arena abierta), lo orienta, y decide cuándo ejecutar el ataque melé
## (Attack) o la embestida (Charge). Alterna: melé cuando está cerca, embestida cuando hay
## algo más de distancia y el cooldown lo permite.

## Distancia a la que ejecuta el ataque cuerpo a cuerpo.
@export var melee_range: float = 36.0
## Distancia máxima desde la que puede lanzar la embestida (fuera del rango melé).
@export var charge_range: float = 150.0
## Tiempo mínimo entre embestidas, en segundos.
@export var charge_cooldown: float = 3.5

# Marca de tiempo (ms) de la última embestida, para respetar el cooldown entre estados.
var _last_charge_ms: float = -1.0e9

func enter(args := {}):
	super.enter(args)
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")

func state_physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		transitioned.emit(self, "Idle", {})
		return

	var dist := distance_to_player()
	var dir := direction_to_player()
	orient_body(dir)

	# En rango melé: golpear.
	if dist <= melee_range:
		transitioned.emit(self, "Attack", {})
		return

	# A media distancia y con el cooldown cumplido: embestida.
	var now := float(Time.get_ticks_msec())
	if dist <= charge_range and now - _last_charge_ms >= charge_cooldown * 1000.0:
		_last_charge_ms = now
		transitioned.emit(self, "Charge", {})
		return

	# Si no, perseguir en línea recta hacia el jugador.
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")
	velocity_component.move(delta, dir)

func _on_damaged() -> void:
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
