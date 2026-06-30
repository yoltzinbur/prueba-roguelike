class_name State
extends Node

signal transitioned(state: State, new_state_name: String, args: Dictionary)

var target: Node2D
var anim: AnimatedSprite2D
var weapon_anim: AnimatedSprite2D
var input_component: InputComponent
var velocity_component: VelocityComponent
var health_component: HealthComponent
var navigation_component: NavigationComponent

func enter(args := {}):
	pass
	
func exit():
	pass
	
func state_process(delta: float) -> void:
	pass

func state_physics_process(delta: float) -> void:
	pass
	
func state_input(event: InputEvent) -> void:
	pass

func play_directional_anim(base_name: String) -> void:
	if not anim:
		return
	var dir = input_component.last_direction if input_component else "down"
	var full_name = base_name + "_" + dir

	if anim.sprite_frames.has_animation(full_name):
		anim.play(full_name)
	elif anim.sprite_frames.has_animation(base_name):
		anim.play(base_name)

	# Reproduce la misma animación en el arma
	if weapon_anim:
		if weapon_anim.sprite_frames.has_animation(full_name):
			weapon_anim.play(full_name)
		elif weapon_anim.sprite_frames.has_animation(base_name):
			weapon_anim.play(base_name)
