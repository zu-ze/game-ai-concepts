class_name CellSpacePartition

var _cells: Array[Array] = []
var _space_width: float
var _space_height: float
var _num_cells_x: int
var _num_cells_y: int
var _cell_size_x: float
var _cell_size_y: float

func _init(width: float, height: float, cells_x: int, cells_y: int) -> void:
	_space_width = width
	_space_height = height
	_num_cells_x = cells_x
	_num_cells_y = cells_y
	_cell_size_x = width / cells_x
	_cell_size_y = height / cells_y
	
	for i in range(cells_x * cells_y):
		_cells.append([])

func add_entity(entity: Vehicle) -> void:
	var idx = _position_to_index(entity.global_position)
	_cells[idx].append(entity)

func update_entity(entity: Vehicle, old_pos: Vector2) -> void:
	var old_idx = _position_to_index(old_pos)
	var new_idx = _position_to_index(entity.global_position)
	
	if old_idx == new_idx:
		return
		
	_cells[old_idx].erase(entity)
	_cells[new_idx].append(entity)

func calculate_neighbors(target_pos: Vector2, query_radius: float) -> Array[Vehicle]:
	var neighbors: Array[Vehicle] = []
	var query_box = Rect2(target_pos.x - query_radius, target_pos.y - query_radius, query_radius * 2, query_radius * 2)
	
	# Determine range of cells to check
	var start_x = floor(query_box.position.x / _cell_size_x)
	var end_x = floor(query_box.end.x / _cell_size_x)
	var start_y = floor(query_box.position.y / _cell_size_y)
	var end_y = floor(query_box.end.y / _cell_size_y)
	
	start_x = clamp(start_x, 0, _num_cells_x - 1)
	end_x = clamp(end_x, 0, _num_cells_x - 1)
	start_y = clamp(start_y, 0, _num_cells_y - 1)
	end_y = clamp(end_y, 0, _num_cells_y - 1)
	
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			var idx = y * _num_cells_x + x
			for entity in _cells[idx]:
				if entity.global_position.distance_squared_to(target_pos) < query_radius * query_radius:
					neighbors.append(entity)
					
	return neighbors

func _position_to_index(pos: Vector2) -> int:
	var idx_x = int(clamp(pos.x / _cell_size_x, 0, _num_cells_x - 1))
	var idx_y = int(clamp(pos.y / _cell_size_y, 0, _num_cells_y - 1))
	return idx_y * _num_cells_x + idx_x

func empty_cells() -> void:
	for cell in _cells:
		cell.clear()
