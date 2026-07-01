extends Node2D
## Arena del jefe final. Instancia al jugador (con su estado guardado), activa al Squid cuando
## el jugador entra y, al derrotarlo, muestra la victoria y regresa al bosque. La arena no se
## persiste: no cambia el punto de guardado (si el jugador muere o sale, reanuda en el bosque).

const PLAYER_SCENE := "res://Entities/Player/Player.tscn"

@onready var room_trigger: Area2D = $RoomTrigger
@onready var squid: Node = $Squid
@onready var player_spawn: Marker2D = $PlayerSpawn

# Evita disparar la victoria dos veces.
var _victory: bool = false
# Evita repetir el aviso de parry cada vez que se reevalúa la activación del jefe.
var _hint_shown: bool = false

func _ready() -> void:
	var player := _spawn_player()
	if player != null:
		SaveManager.apply_player_state(player)

	if is_instance_valid(squid):
		squid.tree_exited.connect(_on_boss_defeated)

	if room_trigger:
		room_trigger.body_entered.connect(_on_room_trigger_entered)

	# La arena coincide con el RoomTrigger, así que el jugador suele aparecer ya dentro:
	# se comprueba el solape tras un frame de física para activar al jefe igualmente.
	await get_tree().physics_frame
	_activate_if_player_inside()

## Instancia al jugador en el marcador de aparición.
func _spawn_player() -> Node:
	var scene: PackedScene = load(PLAYER_SCENE)
	if scene == null:
		return null
	var player := scene.instantiate()
	add_child(player)
	if player is Node2D and player_spawn != null:
		player.global_position = player_spawn.global_position
	return player

func _on_room_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_activate_boss()

func _activate_if_player_inside() -> void:
	if room_trigger == null:
		return
	for body in room_trigger.get_overlapping_bodies():
		if body.is_in_group("Player"):
			_activate_boss()
			return

func _activate_boss() -> void:
	if is_instance_valid(squid) and squid.has_method("activate"):
		squid.activate()
	# Al entrar a la arena, recuerda al jugador cómo reflejar los proyectiles del jefe.
	# Solo una vez, aunque la activación se reevalúe (trigger + chequeo de solape inicial).
	if not _hint_shown:
		_hint_shown = true
		var player := get_tree().get_first_node_in_group("Player")
		if player != null and player.has_method("show_message"):
			player.show_message("Refleja proyectiles con [img=12]res://Utilities/UI/TouchControls/Icons/parry_white.svg[/img]", 5.0)

## El jefe murió (salió del árbol): victoria y regreso al bosque.
func _on_boss_defeated() -> void:
	# El Squid también sale del árbol al desmontarse TODA la escena (p. ej. al usar el
	# menú del Game Over tras morir). Eso NO es derrotarlo: si la propia arena ya salió
	# del árbol, se ignora para no persistir la victoria ni tocar un get_tree() nulo.
	if not is_inside_tree():
		return
	if _victory:
		return
	_victory = true
	# Persistir la derrota del jefe: el BossPortal desaparece y la arena ya no es accesible.
	SaveManager.boss_defeated = true
	SaveManager.save_game()
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("show_message"):
		player.show_message("¡Has derrotado al Tótem!", 3.0)
	await get_tree().create_timer(2.5).timeout
	GameManager.load_scene(GameScenes.FORESTMAIN)
