extends Node2D

@onready var player_camera: Camera2D = $Player/AnchorCamara2d
@onready var tilemap: TileMapLayer = $TilemapLeyers/walls

func _ready() -> void:
	if tilemap and player_camera:
		camera_limits()
	else:
		push_error("No hay camera o el tilemap")

func camera_limits() -> void:
	var u_rect: Rect2i = tilemap.get_used_rect()
	var tile_size: Vector2i = tilemap.tile_set.tile_size
		
	player_camera.limit_left = u_rect.position.x * tile_size.x
	player_camera.limit_top = u_rect.position.y * tile_size.y
	player_camera.limit_right = u_rect.end.x * tile_size.x
	player_camera.limit_bottom = u_rect.end.y * tile_size.y
