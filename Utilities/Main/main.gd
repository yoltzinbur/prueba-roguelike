extends Node2D

@onready var player_camera: Camera2D = $Player/AnchorCamara2d
@onready var tilemap: TileMapLayer = $TilemapLeyers/walls

func _ready() -> void:
	if tilemap and player_camera:
		camera_limits()
	else:
		push_error("No hay camera o el tilemap")
	
	# Conectar señal de muerte del player
	var health = get_node_or_null("Player/HealthComponent")
	if health:
		health.muerto.connect(_on_health_component_muerto)
		print("Señal muerto conectada correctamente")
	else:
		push_error("No se encontró HealthComponent")

func _on_health_component_muerto():
	print("Señal muerto recibida")
	get_tree().paused = true
	var game_over = preload("res://Utilities/GameOver/game_over.tscn").instantiate()
	get_tree().root.add_child(game_over)
	get_tree().paused = false

func camera_limits() -> void:
	var u_rect: Rect2i = tilemap.get_used_rect()
	var tile_size: Vector2i = tilemap.tile_set.tile_size
		
	player_camera.limit_left = u_rect.position.x * tile_size.x
	player_camera.limit_top = u_rect.position.y * tile_size.y
	player_camera.limit_right = u_rect.end.x * tile_size.x
	player_camera.limit_bottom = u_rect.end.y * tile_size.y
	
