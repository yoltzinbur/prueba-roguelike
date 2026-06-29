class_name PuzzleLaser
extends Node2D
## Lógica global del segundo puzzle. Dos tótems disparan un láser horizontal hacia
## su receptor. Cada láser pertenece a un grupo (A = arriba, B = abajo) y cada caja
## también (mostrado con una letra sobre ella):
##   - Grupo A: láser A (Totem/Laser), cajas Box1 y Box3.
##   - Grupo B: láser B (Totem2/Laser2), cajas Box2 y Box4.
##
## Estado de cada tótem, leído del RayCast2D vía get_collider():
##   - LIBRE   (FREE):   el láser llega a su receptor, sin caja en medio (destapado).
##   - TAPADO  (COVERED): bloqueado por una caja de SU MISMO grupo (legítimo).
##   - CRUCE   (CROSSED): bloqueado por una caja del OTRO grupo → penalización inmediata.
##
## La compuerta (AND/OR/XOR) y su objetivo concreto se sortean al instanciarse y la
## sala los persiste para que los reinicios conserven el reto (igual que el puzzle 1).

## Emitida cuando el puzzle se resuelve correctamente (la sala reabre las puertas).
signal puzzle_solved
## Emitida cuando un láser es interrumpido por una caja del grupo equivocado (cruce).
signal penalty_triggered

## Compuertas lógicas posibles. El entero (AND=0, OR=1, XOR=2) es lo que la sala
## guarda en su persistencia para reimponerlo en los reinicios.
enum LogicMode { AND, OR, XOR }
## Estado de un tótem frente a su láser.
enum Status { FREE, COVERED, CROSSED }

## Compuerta activa. Se sortea en _ready() la primera vez; en los reinicios la sala
## la vuelve a fijar con apply_fixed_mode().
var _current_mode: LogicMode = LogicMode.AND

## Objetivo concreto sorteado para la compuerta, persistido junto al modo:
##   _obj_action: "TAPAR" | "DESTAPAR"   _obj_group: "A" | "B" | "AMBOS"
var _obj_action: String = "TAPAR"
var _obj_group: String = "AMBOS"

var _is_solved: bool = false
# Cuando la sala impone el reto (en un reinicio) se evita re-sortearlo.
var _config_fixed: bool = false
# Estado de cruce del frame anterior, para penalizar solo en el flanco de entrada.
var _was_crossed: bool = false

# Colores del haz según el estado del tótem.
const BEAM_FREE := Color(0.4, 1.0, 0.4)
const BEAM_COVERED := Color(1.0, 0.85, 0.3)
const BEAM_CROSSED := Color(1.0, 0.25, 0.25)
const BEAM_WIDTH := 1.0

## Grupo lógico de cada caja, por nombre de nodo.
const BOX_GROUPS := {
	"Box1": "A", "Box3": "A",
	"Box2": "B", "Box4": "B",
}
## Caja que arranca sobre el láser de cada grupo (la que define el estado inicial
## "tapado"); las demás (Box1, Box2) quedan alejadas como herramientas del jugador.
const BEAM_BOX := { "A": "Box3", "B": "Box4" }

## Fuente compartida por las etiquetas de letra de las cajas (estilo pixel-art).
const LABEL_FONT := preload("res://Assets/Fonts/Minecraft.ttf")

@onready var interaction_objects: Node2D = $InteractionObjects
@onready var laser_a: RayCast2D = $InteractionObjects/Laser
@onready var laser_b: RayCast2D = $InteractionObjects/Laser2
@onready var receptor_a: StaticBody2D = $InteractionObjects/Receptor
@onready var receptor_b: StaticBody2D = $InteractionObjects/Receptor2

func _ready() -> void:
	# Solo se sortea el reto en la primera instanciación. En los reinicios la sala ya
	# lo fijó con apply_fixed_mode(), conservando compuerta y objetivo originales.
	if not _config_fixed:
		_randomize_challenge()

	_setup_beam(laser_a)
	_setup_beam(laser_b)
	_apply_box_layout()
	_create_box_labels()
	_create_totem_labels()

# --- Sorteo y persistencia del reto ------------------------------------------

## Elige compuerta y, según ella, el objetivo concreto. Solo en la 1ª instanciación.
func _randomize_challenge() -> void:
	_current_mode = [LogicMode.AND, LogicMode.OR, LogicMode.XOR].pick_random()
	match _current_mode:
		LogicMode.AND:
			# Igualdad estricta: hay que tapar ambos o destapar ambos, según lo pedido.
			_obj_group = "AMBOS"
			_obj_action = ["TAPAR", "DESTAPAR"].pick_random()
		LogicMode.OR:
			# Dirigida: una instrucción exacta sobre un grupo.
			_obj_group = ["A", "B"].pick_random()
			_obj_action = ["TAPAR", "DESTAPAR"].pick_random()
		LogicMode.XOR:
			# Selección única: tapar exactamente el grupo indicado.
			_obj_group = ["A", "B"].pick_random()
			_obj_action = "TAPAR"

## La sala fija el reto ANTES de añadir el nodo al árbol, para que _ready() no lo
## vuelva a sortear. `fixed_objective` es el código devuelto por get_objective_code().
func apply_fixed_mode(fixed_mode: int, fixed_objective: String) -> void:
	_current_mode = fixed_mode as LogicMode
	var parts := fixed_objective.split(":")
	if parts.size() == 2:
		_obj_action = parts[0]
		_obj_group = parts[1]
	_config_fixed = true

## Código compacto del objetivo para que la sala lo guarde ("TAPAR:AMBOS", etc.).
func get_objective_code() -> String:
	return "%s:%s" % [_obj_action, _obj_group]

# --- Disposición inicial de cajas --------------------------------------------

## Configura el estado inicial de cada láser según el objetivo, retirando la caja
## que esté sobre el láser de un grupo que deba arrancar LIBRE. Garantiza que el
## puzzle NO esté resuelto al iniciar y que sea alcanzable. Box1/Box2 (alejadas)
## siempre permanecen como herramientas del jugador.
func _apply_box_layout() -> void:
	var cover_a := false
	var cover_b := false

	match _current_mode:
		LogicMode.AND:
			# Arranque desigual (A tapado, B libre): ninguna igualdad se cumple aún.
			cover_a = true
			cover_b = false
		LogicMode.OR:
			# El grupo objetivo arranca en el estado CONTRARIO al pedido; el otro
			# grupo, neutro (libre).
			var want_cover := _obj_action == "TAPAR"
			if _obj_group == "A":
				cover_a = not want_cover
			else:
				cover_b = not want_cover
		LogicMode.XOR:
			# Ambos libres: el jugador tapa solo el grupo indicado.
			cover_a = false
			cover_b = false

	if not cover_a:
		_remove_box(BEAM_BOX["A"])
	if not cover_b:
		_remove_box(BEAM_BOX["B"])

func _remove_box(box_name: String) -> void:
	var box := interaction_objects.get_node_or_null(box_name)
	if box:
		box.queue_free()

## Crea una etiqueta con la letra (A/B) sobre cada caja presente, para que el
## jugador sepa a qué láser pertenece (todas comparten el mismo sprite).
func _create_box_labels() -> void:
	for box_name in BOX_GROUPS:
		var box := interaction_objects.get_node_or_null(box_name) as Node2D
		if box == null:
			continue
		_add_label(box, BOX_GROUPS[box_name], Vector2(-2.0, -12.0))

## Rotula cada tótem con su grupo (A arriba, B abajo) para que el jugador sepa qué
## caja le corresponde a cada láser.
func _create_totem_labels() -> void:
	_add_label(interaction_objects.get_node_or_null("Totem") as Node2D, "A", Vector2(12.0, -12.0))
	_add_label(interaction_objects.get_node_or_null("Totem2") as Node2D, "B", Vector2(12.0, -12.0))

## Añade una etiqueta de texto pixel-art como hija del nodo dado, en la posición
## local indicada. No hace nada si el nodo es null.
func _add_label(target: Node2D, text: String, offset: Vector2) -> void:
	if target == null:
		return
	var label := Label.new()
	label.text = text
	label.label_settings = _label_settings()
	label.position = offset
	target.add_child(label)

func _label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = LABEL_FONT
	settings.font_size = 8
	return settings

# --- Lectura de láseres y evaluación -----------------------------------------

func _physics_process(_delta: float) -> void:
	if _is_solved:
		return

	var status_a := _scan(laser_a, receptor_a, "A")
	var status_b := _scan(laser_b, receptor_b, "B")
	_update_beam_visual(laser_a, status_a)
	_update_beam_visual(laser_b, status_b)

	# Penalización universal: cualquier láser interrumpido por una caja del grupo
	# equivocado. Se dispara solo en el flanco de entrada al cruce.
	var crossing := status_a == Status.CROSSED or status_b == Status.CROSSED
	if crossing and not _was_crossed:
		_trigger_penalty()
	_was_crossed = crossing

	evaluate_puzzle(status_a, status_b)

## Determina el estado del tótem leyendo a quién golpea su láser.
func _scan(laser: RayCast2D, receptor: Node, group: String) -> Status:
	laser.force_raycast_update()
	if not laser.is_colliding():
		return Status.FREE
	var collider := laser.get_collider()
	if collider == receptor:
		return Status.FREE
	if collider is Box:
		var box_group: String = BOX_GROUPS.get(String(collider.name), "")
		return Status.COVERED if box_group == group else Status.CROSSED
	# Pared u otro cuerpo inesperado: se trata como destapado.
	return Status.FREE

## Evalúa la condición de victoria según la compuerta y el objetivo. Un cruce
## (caja equivocada) nunca resuelve: solo penaliza.
func evaluate_puzzle(status_a: Status, status_b: Status) -> void:
	if _is_solved:
		return
	if status_a == Status.CROSSED or status_b == Status.CROSSED:
		return

	var covered_a := status_a == Status.COVERED
	var covered_b := status_b == Status.COVERED
	var solved := false

	match _current_mode:
		LogicMode.AND:
			# Estricto: se cumple solo la igualdad pedida por el objetivo sorteado
			# ("Tapar ambos" => ambos tapados; "Destapar ambos" => ambos libres).
			var want_cover := _obj_action == "TAPAR"
			solved = covered_a == want_cover and covered_b == want_cover
		LogicMode.OR:
			# Dirigida: solo el grupo objetivo debe cumplir su instrucción.
			var want_cover := _obj_action == "TAPAR"
			solved = (covered_a if _obj_group == "A" else covered_b) == want_cover
		LogicMode.XOR:
			# Selección única: el grupo objetivo tapado y el otro libre.
			if _obj_group == "A":
				solved = covered_a and status_b == Status.FREE
			else:
				solved = covered_b and status_a == Status.FREE

	if solved:
		_mark_solved()

# --- Resolución y penalización -----------------------------------------------

func _mark_solved() -> void:
	if _is_solved:
		return
	_is_solved = true
	set_physics_process(false)
	# Bloquea las cajas para que el jugador no pueda deshacer la solución moviéndolas.
	_lock_boxes()
	$AudioStreamPlayer.play()
	_show_message("PUZZLE RESUELTO")
	puzzle_solved.emit()
	# Avisa a la sala para que reabra las puertas, si el puzzle vive dentro de una.
	var room := _find_room()
	if room:
		room.complete_puzzle()

## Fija todas las cajas del puzzle en su sitio (ignoran empujones posteriores).
func _lock_boxes() -> void:
	for child in interaction_objects.get_children():
		if child is Box:
			child.lock()

## Penalización por usar una caja cruzada (grupo equivocado). No resuelve; invoca
## una oleada extra de enemigos en la sala (si el puzzle vive dentro de una).
func _trigger_penalty() -> void:
	_show_message("CRUCE INVÁLIDO")
	penalty_triggered.emit()
	trigger_trap_or_enemies()

## Penalización configurable. Por defecto pide a la sala una oleada extra de
## enemigos; si el puzzle corre fuera de una sala, simplemente no hace nada.
func trigger_trap_or_enemies() -> void:
	var room := _find_room()
	if room:
		room.spawn_penalty_wave()

# --- Feedback y utilidades de escena -----------------------------------------

## Prepara el RayCast y su Line2D de feedback.
func _setup_beam(laser: RayCast2D) -> void:
	laser.enabled = true
	var line := laser.get_node_or_null("Line2D") as Line2D
	if line:
		line.width = BEAM_WIDTH
		line.default_color = BEAM_FREE

## Dibuja el haz desde el tótem hasta donde impacta y lo tiñe según el estado:
## verde (libre), ámbar (tapado legítimo) o rojo (cruce). Resalta el receptor si
## el láser llega hasta él.
func _update_beam_visual(laser: RayCast2D, status: Status) -> void:
	var line := laser.get_node_or_null("Line2D") as Line2D
	if line:
		var end_point := laser.target_position
		if laser.is_colliding():
			end_point = laser.to_local(laser.get_collision_point())
		line.points = PackedVector2Array([Vector2.ZERO, end_point])
		match status:
			Status.FREE:
				line.default_color = BEAM_FREE
			Status.COVERED:
				line.default_color = BEAM_COVERED
			Status.CROSSED:
				line.default_color = BEAM_CROSSED

	var receptor: Node = receptor_a if laser == laser_a else receptor_b
	if receptor is CanvasItem:
		receptor.modulate = BEAM_FREE if status == Status.FREE else Color.WHITE

## Muestra en la UI el objetivo de la compuerta actual. La llama la sala al entrar.
func show_gate_hint() -> void:
	_show_message(_objective_message())

## Mensaje legible del objetivo, con la compuerta al inicio:
## "<AND|OR|XOR>: <Tapar|Destapar> <A|B|ambos>".
func _objective_message() -> String:
	return "%s: %s %s" % [_gate_name(), _obj_action.capitalize(), _group_display()]

func _gate_name() -> String:
	match _current_mode:
		LogicMode.AND:
			return "AND"
		LogicMode.OR:
			return "OR"
		LogicMode.XOR:
			return "XOR"
	return ""

func _group_display() -> String:
	return "ambos" if _obj_group == "AMBOS" else _obj_group

## Sube por el árbol hasta encontrar la sala (RoomLayout) que contiene el puzzle.
func _find_room() -> RoomLayout:
	var node: Node = get_parent()
	while node != null and not (node is RoomLayout):
		node = node.get_parent()
	return node as RoomLayout

## Envía el texto de retroalimentación al Label de la UI del jugador. Si no se
## encuentra al jugador (puzzle fuera de una partida), simplemente no muestra nada.
func _show_message(text: String) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_message"):
		player.show_message(text)
