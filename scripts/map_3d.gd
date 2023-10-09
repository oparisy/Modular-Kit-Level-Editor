extends Node3D

# A GridMap-like node and data structure with non-homogeneous z cells size

# Set by main script
var structures

# A Vector2i -> Array (stack) of asset map, where "back" is "top"
# We make sure the Array is never empty (cell is removed in this case)
var cells = {}

# Return the index of the item at this position, or -1 if empty
func get_cell_item(cell: Vector3i) -> int:
	var stack = _get_stack(cell)
	return -1 if stack == null else stack.back().index

func push_cell_item(cell:Vector3i, index:int, yRotationDegrees:float):
	# If there is anything stored here, remove it
	#clear_cell_item(cell)

	# Add asset to scene
	var _model : Node3D = structures[index].model.instantiate()
	_model.position.x = cell.x
	_model.position.z = cell.z
	_model.position.y = get_cell_height(cell)
	_model.set_rotation_degrees(Vector3(0, yRotationDegrees, 0))
	add_child(_model)

	# Update data structure
	var cellObj = {}
	cellObj.index = index
	cellObj.yRotationDegrees = yRotationDegrees
	cellObj.model = _model
	cellObj.aabb = compute_aabb(_model)
	_push_cell(cell, cellObj)

# Return the AABB of the item at this position, or null if empty
func get_cell_aabb(cell: Vector3i):
	var stack = _get_stack(cell)
	return null if stack == null else stack.back().aabb

func clear_top_cell_item(cell:Vector3i):
	var stack = _get_stack(cell)
	if stack == null || stack.is_empty():
		# Do not crash on empty cell
		return
	var cellObj = stack.pop_back()
	_remove_owned_model(cellObj.model)
	if (stack.is_empty()):
		_erase_cell(cell)
	
func clear_cell_items(cell:Vector3i):
	var stack = _get_stack(cell)
	if stack != null:
		for cellObj in stack:
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

# Return the stack at this position, or null
func _get_stack(cell:Vector3i):
	return cells.get(_to_cell_coords(cell))

# Append the cell object at this position
func _push_cell(cell:Vector3i, obj):
	var stack = _get_stack(cell)
	if stack == null:
		stack = []
		cells[_to_cell_coords(cell)] = stack
	stack.push_back(obj)

func _erase_cell(cell:Vector3i):
	cells.erase(_to_cell_coords(cell))

func get_cell_height(cell:Vector3i) -> float:
	var stack = _get_stack(cell)
	var height = 0.
	if stack != null:
		for obj in stack:
			height += obj.aabb.size.y
	return height	

# TODO Should we compute and cache those at loading time?
# It's not clear if we can compute them from PackedScene though
func compute_aabb(node : Node3D) -> AABB:
	#print("Node class: ", node.get_class())
	var result = (node as MeshInstance3D).get_aabb() if node is MeshInstance3D else AABB()
	for c in node.get_children():
		result = result.merge(compute_aabb(c))
	return result
