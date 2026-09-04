extends CanvasLayer

signal start_drag(tower_type)

func _ready():
	var panel = Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -160.0
	panel.modulate = Color(1, 1, 1, 0.8)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 20
	vbox.offset_right = -10
	vbox.offset_bottom = -20
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "Build Tower\n(Drag or Click)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var btn_archer = Button.new()
	btn_archer.text = "Archer"
	btn_archer.icon = load("res://entities/towers/archer/archer_tower.png")
	btn_archer.expand_icon = true
	btn_archer.custom_minimum_size = Vector2(0, 100)
	btn_archer.button_down.connect(func(): start_drag.emit("archer"))
	vbox.add_child(btn_archer)
	
	var btn_wizard = Button.new()
	btn_wizard.text = "Wizard"
	btn_wizard.icon = load("res://entities/towers/wizard/wizard_tower.png")
	btn_wizard.expand_icon = true
	btn_wizard.custom_minimum_size = Vector2(0, 100)
	btn_wizard.button_down.connect(func(): start_drag.emit("wizard"))
	vbox.add_child(btn_wizard)
