class_name SteeringPath

var waypoints: Array[Vector2] = []
var current_waypoint_index: int = 0
var loop: bool = false

func _init(points: Array[Vector2] = [], p_loop: bool = false) -> void:
	waypoints = points
	loop = p_loop

func get_current_waypoint() -> Vector2:
	if waypoints.is_empty():
		return Vector2.ZERO
	return waypoints[current_waypoint_index]

func is_finished() -> bool:
	return not loop and current_waypoint_index >= waypoints.size() - 1

func set_next_waypoint() -> void:
	if waypoints.is_empty():
		return
	
	if loop:
		current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
	else:
		if current_waypoint_index < waypoints.size() - 1:
			current_waypoint_index += 1
