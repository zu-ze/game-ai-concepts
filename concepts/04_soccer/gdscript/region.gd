class_name Region extends RefCounted

enum RegionModifier { HALF_SIZE, NORMAL }

var id: int
var top: float
var left: float
var right: float
var bottom: float
var width: float
var height: float
var center: Vector2

func _init(p_left: float, p_top: float, p_right: float, p_bottom: float, p_id: int = -1) -> void:
	left = p_left
	top = p_top
	right = p_right
	bottom = p_bottom
	id = p_id
	
	width = abs(right - left)
	height = abs(bottom - top)
	center = Vector2((left + right) * 0.5, (top + bottom) * 0.5)

func inside(pos: Vector2, modifier: RegionModifier = RegionModifier.NORMAL) -> bool:
	if modifier == RegionModifier.NORMAL:
		return pos.x > left and pos.x < right and pos.y > top and pos.y < bottom
	else:
		var margin_x = width * 0.25
		var margin_y = height * 0.25
		return pos.x > (left + margin_x) and pos.x < (right - margin_x) and pos.y > (top + margin_y) and pos.y < (bottom - margin_y)

func get_random_position() -> Vector2:
	return Vector2(randf_range(left, right), randf_range(top, bottom))
