extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")

var _player: Player
var _grenades_label: Label
var _notice: Label
var _notice_left := 7.0

@onready var _crosshair: Control = $Crosshair
@onready var _hitmarker: Label = $Hitmarker
@onready var _health_label: Label = $Health
@onready var _ammo_label: Label = $Ammo
@onready var _audio: AudioStreamPlayer = $HitAudio
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _zone_label: Label = $Top/Zone
@onready var _objective_label: Label = $Top/Objective
@onready var _capture_bar: ProgressBar = $Top/Capture
@onready var _buffs_label: Label = $Buffs


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_style_hud()
	_player.grenades_changed.connect(_on_grenades_changed)
	_on_grenades_changed(_player.grenades_remaining)
	_player.weapon.ammo_changed.connect(_on_ammo_changed)
	_player.weapon.reload_started.connect(func(_t): _ammo_label.text = "换弹中…")
	_player.weapon.hit_landed.connect(_on_hit_landed)
	_player.health.damaged.connect(_on_player_damaged)
	_on_ammo_changed(_player.weapon.ammo, _player.weapon.reserve)

	var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	_zone_label.text = "%02d / %02d  ·  %s" % [director.zone_index + 1, RunState.ZONE_SCENES.size(), ZoneDirector.ZONE_TITLES[director.zone_index]]
	director.supply_changed.connect(_show_notice)
	director.objective_changed.connect(_on_objective_changed)
	director.enemies_changed.connect(_on_enemies_changed)
	director.capture_point.progress_changed.connect(func(p: float): _capture_bar.value = p * 100.0)
	_on_enemies_changed(director.enemies_total, director.enemies_total)
	_capture_bar.visible = false
	var titles: PackedStringArray = []
	for buff: Buff in RunState.buffs:
		titles.append(buff.title)
	_buffs_label.text = "增益：" + "、".join(titles) if not titles.is_empty() else ""


func _process(_delta: float) -> void:
	_notice_left = maxf(_notice_left - _delta, 0.0)
	_notice.modulate.a = clampf(_notice_left, 0.0, 1.0)
	var health := _player.health
	_health_label.text = "生命 %d / %d" % [ceili(health.health), ceili(health.max_health)]
	# Project the spread angle onto the screen so the gap matches where bullets can land.
	var camera := get_viewport().get_camera_3d()
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := deg_to_rad(_player.weapon.spread_degrees())
	_crosshair.gap = 4.0 + half_height * tan(spread) / tan(deg_to_rad(camera.fov) * 0.5)
	_crosshair.visible = not _player.is_aiming()
	_crosshair.queue_redraw()


func _on_ammo_changed(current: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current, reserve]


func _on_hit_landed(headshot: bool, killed: bool) -> void:
	_hitmarker.modulate = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	_hitmarker.scale = Vector2.ONE * (1.4 if killed else 1.0)
	var tween := create_tween()
	tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.25).from(1.0)
	_audio.stream = HIT_HEAD if headshot else HIT_BODY
	_audio.play()


func _on_player_damaged(amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.4).from(clampf(amount / 40.0, 0.15, 0.45))


func _on_enemies_changed(alive: int, total: int) -> void:
	if alive > 0:
		_objective_label.text = "消灭所有敌人（剩余 %d / %d）" % [alive, total]


func _on_objective_changed(text: String) -> void:
	_objective_label.text = text
	_capture_bar.visible = text == "前往据点并占领"


func _on_grenades_changed(remaining: int) -> void:
	_grenades_label.text = "AK47   /   G 手雷 %d / 3" % remaining


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice_left = 4.0


func _style_hud() -> void:
	_panel(Vector2(20, 20), Vector2(550, 130), false)
	_panel(Vector2(-320, 18), Vector2(320, 166), false, true)
	_panel(Vector2(20, -120), Vector2(400, -20), true)
	_panel(Vector2(-410, -135), Vector2(-20, -20), true, false, true)
	var title := _label("BATTLEFIELD ROUGE", 24)
	title.position = Vector2(36, 30)
	title.modulate = Color(1.0, 0.82, 0.45)
	add_child(title)
	_buffs_label.position = Vector2(36, 76)
	_buffs_label.add_theme_font_size_override("font_size", 20)
	_buffs_label.size.x = 500
	var tips := _label("WASD 移动 · Shift 冲刺 · Space 跳跃\n左键射击 · 右键瞄准 · R 换弹 · G 手雷", 20)
	tips.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tips.position = Vector2(-340, -84)
	tips.size = Vector2(680, 64)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tips)
	_grenades_label = _label("", 22)
	_grenades_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_grenades_label.position = Vector2(-390, -121)
	_grenades_label.size = Vector2(358, 32)
	_grenades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_grenades_label)
	_notice = _label("击碎侧路补给箱，靠近拾取弹药与手雷", 24)
	_notice.set_anchors_preset(Control.PRESET_CENTER)
	_notice.position = Vector2(-480, 170)
	_notice.size = Vector2(960, 50)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_notice)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _panel(from: Vector2, to: Vector2, bottom: bool, center := false, right := false) -> void:
	var panel := ColorRect.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.color = Color(0.035, 0.045, 0.055, 0.76)
	if center:
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
	elif right:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
	if bottom:
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
	panel.offset_left = from.x
	panel.offset_top = from.y
	panel.offset_right = to.x
	panel.offset_bottom = to.y
	add_child(panel)
	move_child(panel, 0)
