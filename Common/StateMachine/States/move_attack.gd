extends State

@export var hitbox: CollisionShape2D

var audioAttack: AudioStreamPlayer

# Crítico (Guard Break): multiplicador aplicado a este golpe y daño base a restaurar.
var _crit_mult: int = 1
var _base_damage: int = 0

func enter(args := {}):
	audioAttack = target.get_node_or_null("Audios/Attack")

	if args.has("direction"):
		play_directional_anim("attack")
		args["velocity_component"].move(0, args["direction"] * args["force"])

		if audioAttack:
			audioAttack.play()

	if hitbox:
		hitbox.disabled = false
		_apply_crit()

	await get_tree().create_timer(0.5).timeout
	transitioned.emit(self, "Idle", {})

func exit():
	if hitbox:
		hitbox.disabled = true
	_restore_crit()

## Si hay ventana de Guard Break activa, multiplica el daño del HitBox para este golpe.
func _apply_crit() -> void:
	_crit_mult = 1
	if target and target.has_method("consume_crit_multiplier"):
		_crit_mult = target.consume_crit_multiplier()
	if _crit_mult > 1:
		var hb := hitbox.get_parent()
		if hb:
			_base_damage = hb.damage
			hb.damage = _base_damage * _crit_mult

## Restaura el daño base del HitBox tras un golpe crítico.
func _restore_crit() -> void:
	if _crit_mult > 1 and hitbox:
		var hb := hitbox.get_parent()
		if hb:
			hb.damage = _base_damage
	_crit_mult = 1
