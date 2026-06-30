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

# Escudo del parry: mientras está activo, el dueño de esta HurtBox ignora el daño melé
# de enemigos normales y de los proyectiles (que se reflejan aparte). Lo activa/desactiva
# el estado Parry del jugador con set_guard(). Los ataques melé de JEFES sí atraviesan.
var _guard: bool = false

## Activa o desactiva el escudo de parry. Llamado por el estado Parry al entrar/salir.
func set_guard(active: bool) -> void:
	_guard = active

func _ready() -> void:
	# El daño periódico solo corre cuando hay un HitBox dentro (se activa al entrar).
	set_physics_process(false)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(hitbox: HitBox) -> void:
	if hitbox == null:
		return
	# El escudo del parry bloquea este golpe (enemigo normal o proyectil): no hay daño.
	if _is_parried(hitbox):
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
	# Durante una transición de escena el nodo puede estar liberándose y Godot
	# apaga el monitoreo del área; pedir las áreas solapadas en ese estado lanza
	# un error. Si el monitoreo está apagado, detenemos el proceso periódico.
	if not monitoring:
		set_physics_process(false)
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var hit_any := false
	for area in get_overlapping_areas():
		if area is HitBox and not _is_parried(area):
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

## Decide si el escudo del parry anula este golpe. Bloquea cuando el escudo está activo y
## el golpe es un proyectil (se refleja aparte) o un ataque melé de un enemigo NORMAL. Los
## ataques melé de los JEFES (entidad en el grupo "Boss") atraviesan el escudo y sí dañan.
func _is_parried(hitbox: HitBox) -> bool:
	if not _guard:
		return false
	if hitbox.has_method("reflect"):
		return true
	var source := hitbox.get_source_entity()
	if source and source.is_in_group("Boss"):
		return false
	return true
