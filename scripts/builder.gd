extends Node3D

@export var kitsPath : String # Path on disk to Kenney's kits

@export var structures: Array[Structure] = []

var map:DataMap

#var mapData: DataMap3D

var index:int = 0 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var cash_display:Label

# Map assets (instanciated scenes) will be under this node
@onready var mapNode = $"../Map"

@onready var kitOptionButton = $"../CanvasLayer/OptionButton"

# Default margin between selector and item (or ground) below
const SELECTOR_MARGIN = 0.25

# Name -> GLTF folder, for each kit found in kitsPath
var kits = {}

var plane:Plane # Used for raycasting mouse

# Used to detect cell change on mouse move
var last_cell = Vector3i()

func _ready():
	list_kits()
	for kitName in kits:
		kitOptionButton.add_item(kitName)
	
	setup()

func setup():
	map = DataMap.new()

	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	mapNode.structures = structures
	
	update_structure()
	update_cash()

# Browse available kits, fill "kits" Dictionary
func list_kits():
	var dir = DirAccess.open(kitsPath)
	if dir == null:
		var error = "Error %s" % DirAccess.get_open_error()
		OS.alert('Please specify a valid kits path (use kitsPath property)', error)
		get_tree().quit()
	
	var gltfFolders = []
	searchForFoldersNamed(kitsPath, "GLTF format", gltfFolders)

	for found in gltfFolders:
		# Keep it simple, we expect a given format
		var kitName = found.get_base_dir().get_base_dir().get_file()
		kits[kitName] = found

func searchForFoldersNamed(path:String, searchedName: String, result: Array):
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var fileName = dir.get_next()	
	while fileName != "":
		if dir.current_is_dir():
			var fullPath = path + "/" + fileName
			if fileName == searchedName:
				result.append(fullPath)
			else:
				searchForFoldersNamed(fullPath, searchedName, result)
		fileName = dir.get_next()

func _process(delta):
	
	# Controls
	
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	action_save() # Saving
	action_load() # Loading
	
	# Map position based on mouse
	
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var cell_x = round(world_position.x)
	var cell_z = round(world_position.z)
	var gridmap_position = Vector3(cell_x, 0, cell_z)
	selector.position = lerp(selector.position, gridmap_position, delta * 40)
	
	# Detect cell change
	var cell = Vector3i(cell_x, 0, cell_z)
	if cell != last_cell:
		update_selector_height(cell)
	last_cell = cell
	
	action_build(gridmap_position)
	action_demolish(gridmap_position)

# Return true if some Control currently has the focus
# (so we are probably in the process of interacting with it)
# We expect Controls to release focus when left (see OptionButton script)
func someControlHasFocus():
	var withFocus = get_viewport().gui_get_focus_owner()
	return withFocus != null

# Build (place) a structure

func action_build(gridmap_position):
	# Testing if we are in a control avoids reacting here to clicks on it
	# "Input's methods reflect the global input state and are not affected by
	# Control.accept_event() or Viewport.set_input_as_handled(), as those
	# methods only deal with the way input is propagated in the SceneTree."
	# => so we have to cheat a little
	# TODO It was recommended that I use _unhandled_input
	if Input.is_action_just_pressed("build") && !someControlHasFocus():
		
		# Update data structure
		var previous_tile = mapNode.get_cell_item(gridmap_position)
		var yRot = selector.get_rotation_degrees().y
		mapNode.push_cell_item(gridmap_position, index, yRot)
		update_selector_height(gridmap_position)
		
		if previous_tile != index:
			map.cash -= structures[index].price
			update_cash()

# Demolish (remove) a structure

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		mapNode.clear_top_cell_item(gridmap_position)
		update_selector_height(gridmap_position)

# Rotates the 'cursor' 90 degrees

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))

# Toggle between structures to build

func action_structure_toggle():
	var previous = index
	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, structures.size())
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size())

	if index != previous:
		update_structure()

# Update the structure visual in the 'cursor'

func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)

func update_selector_height(currentCell: Vector3i):
	#print("Cell changed to %s" % currentCell)
	selector_container.position.y = SELECTOR_MARGIN
	selector_container.position.y += mapNode.get_cell_height(currentCell)

func update_cash():
	cash_display.text = "$" + str(map.cash)

# Saving/load

func action_save():
	if Input.is_action_just_pressed("save"):
		print("Saving map...")
		
		map.structures.clear()
		for cell in mapNode.get_used_cells():
			
			var data_structure:DataStructure = DataStructure.new()
			
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = mapNode.get_cell_item_orientation(cell)
			data_structure.structure = mapNode.get_cell_item(cell)
			
			map.structures.append(data_structure)
			
		ResourceSaver.save(map, "user://map.res")
	
func action_load():
	if Input.is_action_just_pressed("load"):
		print("Loading map...")
		
		mapNode.clear()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			mapNode.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
			
		update_cash()


func _on_option_button_item_selected(index):
	var selectedKit = kitOptionButton.get_item_text(index)
	var pathToModels = kits[selectedKit]
	print("%s selected" % selectedKit)
	print("Loading models from %s" % pathToModels)
	
	var loadedModels = []
	var time_start = Time.get_ticks_msec()
	var dir = DirAccess.open(pathToModels)
	for modelFile in dir.get_files():
		var loader = GLTFDocument.new()
		var loaded = GLTFState.new()
		var toLoad = pathToModels + "/" + modelFile
		var err = loader.append_from_file(toLoad, loaded)
		if (err != OK):
			print("Error %s occurred while loading model %s" % [err, toLoad])
		else:
			# TODO Do something with loaded model (we want a PackedScene)
			print("Loaded %s" % modelFile)
			var model : Node = loader.generate_scene(loaded)
			var scene = PackedScene.new()
			err = scene.pack(model)
			if err != OK:
				print("Error %s occurred while packing %s" % [err, toLoad])
			else:
				loadedModels.append(scene)

	var time_now = Time.get_ticks_msec()
	var elapsed = time_now - time_start
	print("Models loading took %sms" % elapsed)
	
	structures.clear()
	for model in loadedModels:
		var structure = Structure.new()
		structure.model = model
		structure.price= 42
		structures.append(structure)
	
	setup()
	mapNode.clear()
