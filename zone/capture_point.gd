class_name CapturePoint
extends Area3D
## Stand inside to capture. Locked until the zone director calls open().
## Progress drains slowly while the player is outside.

signal progress_changed(progress: float)
signal captured

const COLOR_LOCKED := Color(0.5, 0.5, 0.5, 0.25)
const COLOR_OPEN := Color(0.2, 0.6, 1.0, 0.35)
const COLOR_CAPTURED := Color(0.3, 0.9, 0.4, 0.4)

@export var capture_time := 6.0
## Progress lost per second while empty, as a fraction of capture_time.
@export var decay_rate := 0.5

var locked := true
var progress := 0.0

var _player_inside := false
var _material := StandardMaterial3D.new()

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.ACTORS
	monitorable = false
	body_entered.connect(func(body: Node3D): if body.is_in_group("player"): _player_inside = true)
	body_exited.connect(func(body: Node3D): if body.is_in_group("player"): _player_inside = false)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _material
	_update_color()


func open() -> void:
	locked = false
	_update_color()


func is_captured() -> bool:
	return progress >= 1.0


func _physics_process(delta: float) -> void:
	if locked or is_captured():
		return
	var before := progress
	if _player_inside:
		progress = minf(progress + delta / capture_time, 1.0)
	else:
		progress = maxf(progress - decay_rate * delta / capture_time, 0.0)
	if progress != before:
		progress_changed.emit(progress)
	if is_captured():
		_update_color()
		captured.emit()


func _update_color() -> void:
	if is_captured():
		_material.albedo_color = COLOR_CAPTURED
	elif locked:
		_material.albedo_color = COLOR_LOCKED
	else:
		_material.albedo_color = COLOR_OPEN
