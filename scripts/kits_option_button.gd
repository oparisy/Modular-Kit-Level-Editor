extends OptionButton

# Called when the node enters the scene tree for the first time.
func _ready():
	# Filled with Kenny kits found in main script
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_item_selected(index):
	print("Item %s selected" % get_item_text(index))

func _on_mouse_exited():
	# Builder script needs this to ignores mouse clicks if a control has focus
	release_focus()
