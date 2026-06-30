class_name HurtBox
extends Area2D

signal received_damage(damage: int)

@export var health: HealthComponent
## Segundos entre golpes mientras un HitBox siga solapado. Permite que los enemigos
## que atraviesan al objetivo le sigan haciendo daño de forma continua, en lugar de
## una sola vez al primer contacto. Es @export para poder ajustarlo por entidad.
@export var damage_interval: float = 1.0

# Cuenta atrás hasta el próximo golpe periódico mientras haya solapamiento.
var _cooldown: float = 0.0

func _ready() -> void:
	# El daño periódico solo corre cuando hay un HitBox dentro (se activa al entrar).
	set_physics_process(false)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(hitbox: HitBox) -> void:
	if hitbox == null:
		return
	# Primer golpe inmediato al contacto (conserva el comportamiento original).
	_apply_damage(hitbox.damage)
	# Reinicia la cuenta y empieza a vigilar el solapamiento para repetir el daño
	# mientras el HitBox no salga (p. ej. un enemigo que atraviesa al jugador).
	_cooldown = damage_interval
	set_physics_process(true)

## Mientras al menos un HitBox permanezca dentro, repite su daño cada
## damage_interval. En cuanto no queda ninguno, detiene el proceso para no gastar ciclos.
func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var hit_any := false
	for area in get_overlapping_areas():
		if area is HitBox:
			_apply_damage(area.damage)
			hit_any = true
	if hit_any:
		_cooldown = damage_interval
	else:
		set_physics_process(false)

func _apply_damage(amount: int) -> void:
	received_damage.emit(amount)
	if health:
		health.damage(amount)
