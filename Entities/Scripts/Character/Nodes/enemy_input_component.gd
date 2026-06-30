class_name EnemyInputComponent
extends InputComponent

@export var attack_range: float

var player: CharacterBody2D
var target: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	target = get_parent()

func _process(delta: float) -> void:
	input_attack = false
	input_heal = false
	input_motion = Vector2.ZERO
	
	if not is_instance_valid(player):
		return
	
	var distance_to_player = target.global_position.distance_to(player.global_position)

	if distance_to_player <= attack_range:
		#input_attack = true
		#await get_tree().create_timer(0.5).timeout
		#input_motion = Vector2.ZERO
		#print(target, "\t | attack")
		pass
	
	else:
		input_motion = (player.global_position - target.global_position).normalized()
