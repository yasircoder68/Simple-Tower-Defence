@tool
extends SceneTree

func _init():
	print("Starting build_ui.gd...")
	
	# Create ghost tower scene
	var ghost_root = Node2D.new()
	ghost_root.name = "GhostTower"
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	ghost_root.add_child(sprite)
	sprite.owner = ghost_root
	
	var ghost_scene = PackedScene.new()
	ghost_scene.pack(ghost_root)
	ResourceSaver.save(ghost_scene, "res://scenes/ghost_tower.tscn")
	print("Saved ghost_tower.tscn")
	
	# Create build sidebar scene
	var sidebar = CanvasLayer.new()
	sidebar.name = "BuildSidebar"
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -150.0
	sidebar.add_child(panel)
	panel.owner = sidebar
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	panel.add_child(vbox)
	vbox.owner = sidebar
	
	var label = Label.new()
	label.name = "Label"
	label.text = "Build Towers"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	label.owner = sidebar
	
	var btn_archer = Button.new()
	btn_archer.name = "ArcherBtn"
	btn_archer.text = "Archer"
	btn_archer.icon = load("res://asserts/archer_tower.png")
	btn_archer.expand_icon = true
	btn_archer.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(btn_archer)
	btn_archer.owner = sidebar
	
	var btn_wizard = Button.new()
	btn_wizard.name = "WizardBtn"
	btn_wizard.text = "Wizard"
	btn_wizard.icon = load("res://asserts/wizard_tower.png")
	btn_wizard.expand_icon = true
	btn_wizard.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(btn_wizard)
	btn_wizard.owner = sidebar
	
	var sidebar_scene = PackedScene.new()
	sidebar_scene.pack(sidebar)
	ResourceSaver.save(sidebar_scene, "res://scenes/build_sidebar.tscn")
	print("Saved build_sidebar.tscn")
	
	quit()
