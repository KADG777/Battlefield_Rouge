extends CanvasLayer
## Pauses the game and offers buffs as buttons. Emits `chosen` once.

signal chosen(buff: Buff)

@onready var _choices: HBoxContainer = $Center/Box/Choices


func setup(buffs: Array[Buff]) -> void:
	for i in buffs.size():
		var buff := buffs[i]
		var button := Button.new()
		button.text = "%d. %s\n\n%s" % [i + 1, buff.title, buff.description]
		button.custom_minimum_size = Vector2(280, 160)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_stylebox_override("normal", _card(Color(0.12, 0.13, 0.15, 0.95)))
		button.add_theme_stylebox_override("hover", _card(Color(0.2, 0.32, 0.5, 0.95)))
		button.add_theme_stylebox_override("focus", _card(Color(0.2, 0.32, 0.5, 0.95)))
		button.add_theme_stylebox_override("pressed", _card(Color(0.25, 0.45, 0.7, 0.95)))
		button.pressed.connect(_choose.bind(buff))
		_choices.add_child(button)


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	# Number keys 1-3 pick a buff too.
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _choices.get_child_count():
			_choices.get_child(index).pressed.emit()


func _card(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	return style


func _choose(buff: Buff) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(buff)
	queue_free()
