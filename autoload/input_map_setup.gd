extends Node
## Registers the input actions in code, so bindings stay reviewable in Git.
## Adapted from origin/sheji/autoload/input_setup.gd, cut down to what the MVP uses.

## "action": [InputEvent, ...]. Several entries are alternative bindings.
var _bindings := {
	"move_forward": [_key(KEY_W)],
	"move_back": [_key(KEY_S)],
	"move_left": [_key(KEY_A)],
	"move_right": [_key(KEY_D)],
	"jump": [_key(KEY_SPACE)],
	"sprint": [_key(KEY_SHIFT)],
	"fire": [_mouse(MOUSE_BUTTON_LEFT)],
	"aim": [_mouse(MOUSE_BUTTON_RIGHT)],
	"reload": [_key(KEY_R)],
	"grenade": [_key(KEY_G)],
	"interact": [_key(KEY_F)],
	"pause": [_key(KEY_ESCAPE)],
}


func _enter_tree() -> void:
	for action: String in _bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event: InputEvent in _bindings[action]:
			InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
