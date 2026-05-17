class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)

@export var MAX_HEALTH: int
@export var stamina: int
@export var animatedSprite: AnimatedSprite2D

@onready var current_health := MAX_HEALTH:
	set(value):
		current_health = clampi(value, 0, MAX_HEALTH)
		emit_signal("health_changed", current_health, MAX_HEALTH)
		#current_health = clampi(current_health, 0, MAX_HEALTH)
		if current_health <= 0:
			kill()

func heal(value: int) -> void:
	current_health += value

func damage(value: int) -> void:
	current_health -= value
	animatedSprite.play("hit")

func kill() -> void:
	get_parent().queue_free()
