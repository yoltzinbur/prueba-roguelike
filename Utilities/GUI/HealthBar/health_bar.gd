extends Control

var player: CharacterBody2D
var health_component: HealthComponent
@onready var progress_bar: TextureProgressBar = $Progress

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	health_component = player.get_node("HealthComponent")
	
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		
		progress_bar.max_value = health_component.MAX_HEALTH
		progress_bar.value = health_component.current_health
	else:
		push_warning("HealthBar: No se ha asignado ningún HealthComponent en el inspector.")

func _on_health_changed(current_health: int, max_health: int) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
