extends Node3D

# A GridMap-like node and data structure with non-homogeneous z cells size

# Set by main script
var structures

# A Vector2i -> asset map
var cells = {}

# Return the index of the item at this position, or -1 if empty
func get_cell_item(cell: Vector3i) -> int:
	var cellObj = _get_cell(cell)
	return -1 if cellObj == null else cellObj.index

func set_cell_item(cell:Vector3i, index:int, yRotationDegrees:float):
	# If there is anything stored here, remove it
	clear_cell_item(cell)

	# Add asset to scene
	var _model : Node3D = structures[index].model.instantiate()
	_model.position.x = cell.x
	_model.position.z = cell.z
	_model.set_rotation_degrees(Vector3(0, yRotationDegrees, 0))
	add_child(_model)

	# Update data structure	
	var cellObj = {}
	cellObj.index = index
	cellObj.yRotationDegrees = yRotationDegrees
	cellObj.model = _model
	_set_cell(cell, cellObj)

func clear_cell_item(cell:Vector3i):
	var cellObj = _get_cell(cell)
	if cellObj != null:
		_remove_owned_model(cellObj.model)
		_erase_cell(cell)

func clear():
	cells = {}
	for n in get_children():
		_remove_owned_model(n)

func _remove_owned_model(n : Node):
	remove_child(n)
	n.queue_free()

func _to_cell_coords(cell:Vector3i):
	return Vector2i(cell.x, cell.z);

# Return the cell at this position, or null
func _get_cell(cell:Vector3i):
	return cells.get(_to_cell_coords(cell))

# Cell the cell object at this position
func _set_cell(cell:Vector3i, obj):
	cells[_to_cell_coords(cell)] = obj

func _erase_cell(cell:Vector3i):
	cells.erase(_to_cell_coords(cell))
