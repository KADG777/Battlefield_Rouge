extends Control
## Four-line crosshair whose gap follows the weapon's current spread.

@export var line_length := 8.0
@export var thickness := 2.0
@export var color := Color(1, 1, 1, 0.9)

var gap := 6.0


func _draw() -> void:
	var c := size * 0.5
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * gap, c + dir * (gap + line_length), Color(0, 0, 0, 0.5), thickness + 2.0)
		draw_line(c + dir * gap, c + dir * (gap + line_length), color, thickness)
