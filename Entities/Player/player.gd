extends CharacterBody2D

var current_interactable: Node = null

@onready var input_component: InputComponent = $InputComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const DIRECCIONES = ["down", "right", "up", "left"]

func _ready():
	_crear_animaciones_direccionales()
	animated_sprite.scale.x = abs(animated_sprite.scale.x)
	animated_sprite.play("idle_down")

func _process(_delta: float) -> void:
	if input_component.input_action and current_interactable:
		current_interactable.interact()

func _crear_animaciones_direccionales():
	var frames = animated_sprite.sprite_frames

	var hojas = {
		"idle": preload("res://Entities/Player/Art/Idle.png"),
		"walk": preload("res://Entities/Player/Art/Walk.png"),
		"attack": preload("res://Entities/Player/Art/Attack.png"),
	}

	for anim_name in hojas:
		var sheet = hojas[anim_name]
		for fila in 4:
			var dir_name = anim_name + "_" + DIRECCIONES[fila]
			frames.add_animation(dir_name)
			frames.set_animation_speed(dir_name, 10.0)
			frames.set_animation_loop(dir_name, true)
			for col in 4:
				var atlas = AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(col * 32, fila * 32, 32, 32)
				frames.add_frame(dir_name, atlas)

	var hit_sheet = preload("res://Entities/Player/Art/Hit.png")
	var hit_filas = {"down": 0, "right": 1, "up": 0, "left": 1}
	for dir in hit_filas:
		var fila = hit_filas[dir]
		var dir_name = "hit_" + dir
		frames.add_animation(dir_name)
		frames.set_animation_speed(dir_name, 10.0)
		frames.set_animation_loop(dir_name, false)
		for col in 4:
			var atlas = AtlasTexture.new()
			atlas.atlas = hit_sheet
			atlas.region = Rect2(col * 32, fila * 32, 32, 32)
			frames.add_frame(dir_name, atlas)
