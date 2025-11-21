class_name Wall

var from: Vector2
var to: Vector2
var normal: Vector2

func _init(p_from: Vector2, p_to: Vector2, p_normal: Vector2 = Vector2.ZERO) -> void:
	from = p_from
	to = p_to
	if p_normal == Vector2.ZERO:
		_calculate_normal()
	else:
		normal = p_normal

func _calculate_normal() -> void:
	var direction = (to - from).normalized()
	normal = Vector2(-direction.y, direction.x) # Left normal
