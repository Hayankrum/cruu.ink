extends Button

const MENU_SCENE := "res://Scenes/menu_inicial.tscn"

var _overlay: Control
var _game_ui: Node

func _ready() -> void:
	pressed.connect(_open)
	_game_ui = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	text = "≡"
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(0.93, 0.95, 1, 0.9))
	add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.37))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _open() -> void:
	if _overlay != null:
		return
	AudioManager.play("open")
	get_tree().paused = true
	_overlay = _make_overlay()
	_game_ui.add_child(_overlay)
	var resume := _overlay.get_node_or_null("Center/Card/Margin/VBox/Resume") as Button
	if resume != null:
		resume.grab_focus()

func _make_overlay() -> Control:
	var root := Control.new()
	root.name = "MenuPause"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(280, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Scripts/frosted_glass.gdshader")
	mat.set_shader_parameter("blurRadius", 24.0)
	mat.set_shader_parameter("borderPx", 1.5)
	mat.set_shader_parameter("bgAlpha", 0.92)
	mat.set_shader_parameter("tint", Color(0.04, 0.05, 0.08, 0.94))
	mat.set_shader_parameter("borderColor", Color(1, 1, 1, 0.14))
	mat.set_shader_parameter("cornerRadius", 14.0)
	mat.set_shader_parameter("accentWidth", 3.0)
	mat.set_shader_parameter("accentColor", Color(1.0, 0.78, 0.25, 1.0))
	mat.set_shader_parameter("panelSize", Vector2(280, 340))
	card.material = mat
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSADO"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.37))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(1, 1, 1, 0.1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule)

	var resume := _make_button("CONTINUAR", false)
	resume.name = "Resume"
	resume.pressed.connect(_close)
	vbox.add_child(resume)

	var menu := _make_button("MENU PRINCIPAL", false)
	menu.pressed.connect(_go_menu)
	vbox.add_child(menu)

	var quit := _make_button("SAIR", false)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)

	card.resized.connect(func() -> void:
		mat.set_shader_parameter("panelSize", card.size))

	return root

func _make_button(label: String, _accent := false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.93, 0.95, 1))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.6))
	btn.add_theme_stylebox_override("normal", _make_box(Color(0.07, 0.09, 0.14, 0.78), Color(1, 1, 1, 0.12)))
	btn.add_theme_stylebox_override("hover", _make_box(Color(0.12, 0.16, 0.24, 0.92), Color(1.0, 0.84, 0.37, 0.7)))
	btn.add_theme_stylebox_override("pressed", _make_box(Color(0.05, 0.07, 0.11, 0.95), Color(1.0, 0.84, 0.37, 0.85)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _make_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(10)
	return box

func _close() -> void:
	if _overlay == null:
		return
	AudioManager.play("close")
	_overlay.queue_free()
	_overlay = null
	get_tree().paused = false

func _go_menu() -> void:
	_close()
	SceneTransition.change_scene(MENU_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if _overlay == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
