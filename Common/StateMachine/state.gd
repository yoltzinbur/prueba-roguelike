class_name State
extends Node

signal transitioned(state: State, new_state_name: String, args: Dictionary)

var target: Node2D
var anim: AnimatedSprite2D

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
