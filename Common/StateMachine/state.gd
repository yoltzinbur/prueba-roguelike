class_name State
extends Node

signal transitioned(state: State, new_state_name: String, args: Dictionary)

var target: Node2D
var anim: AnimatedSprite2D
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
