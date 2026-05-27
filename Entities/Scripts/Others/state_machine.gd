class_name StateMachine
extends Node

@export var initial_state: State
@export var animation_sprite: AnimatedSprite2D
@export var target: Node2D

var states: Dictionary
var current_state: State

func _ready():
	for child in get_children():
		child.target = target
		child.anim = animation_sprite
		child.transitioned.connect(change_state)
		states[child.name] = child
	
	current_state = initial_state
	current_state.enter()
	
func _process(delta: float) -> void:
	if current_state:
		current_state.state_process(delta)
		
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.state_physics_process(delta)
		
func change_state(state: State, new_state_name: String, args: Dictionary) -> void:
	if state != current_state:
		return
	
	var new_state: State = states[new_state_name]
	if not new_state:
		return
		 
	if current_state:
		current_state.exit()
		current_state = new_state
		new_state.enter(args)


func _on_hurt_box_area_entered(area: Area2D) -> void:
	pass # Replace with function body.
