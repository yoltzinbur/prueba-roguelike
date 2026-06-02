class_name HurtBox
extends Area2D

signal received_damage(damage: int)

@export var health: HealthComponent

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		connect("area_entered", _on_area_entered)

func _on_area_entered(hitbox: HitBox) -> void:
	if hitbox != null:
		received_damage.emit(hitbox.damage)
		
		if health:
			health.damage(hitbox.damage)
