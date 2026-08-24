extends Label

func _ready() -> void:
	# Reset scale to fix blurriness
	scale = Vector2.ONE
	
	# Create crisp label settings
	var settings = LabelSettings.new()
	settings.font_size = 32
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label_settings = settings

func _process(_delta: float) -> void:
	text = "FPS: " + str(Engine.get_frames_per_second())
	
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
