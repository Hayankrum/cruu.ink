extends Button

const MENU_SCENE := "res://Scenes/menu_inicial.tscn"

var _overlay: Control
var _game_ui: Node

func _ready() -> void:
	pressed.connect(_open)
	_game_ui = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	text = "≡"
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", Color(0.09, 0.1, 0.12, 0.95))
	add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0, 1.0))
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
	bg.color = Color(0.88, 0.9, 0.93, 0.6)
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
	card.custom_minimum_size = Vector2(260, 0)
	card.add_theme_stylebox_override("panel", _make_box(Color(1, 1, 1, 1), Color(0.84, 0.86, 0.9, 1), 12, 0))
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
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.09, 0.1, 0.12, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.88, 0.89, 0.92, 1)
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

	return root

func _make_button(label: String, _accent := false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.09, 0.1, 0.12, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.02, 0.03, 0.04, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.25, 0.27, 0.31, 1))
	btn.add_theme_color_override("font_focus_color", Color(0.09, 0.1, 0.12, 1))
	btn.add_theme_stylebox_override("normal", _make_box(Color(1, 1, 1, 1), Color(0.8, 0.82, 0.86, 1)))
	btn.add_theme_stylebox_override("hover", _make_box(Color(0.95, 0.96, 0.97, 1), Color(0.62, 0.65, 0.7, 1)))
	btn.add_theme_stylebox_override("pressed", _make_box(Color(0.87, 0.89, 0.92, 1), Color(0.5, 0.53, 0.58, 1)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _make_box(bg: Color, border: Color, raio := 10, margem := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(raio)
	box.set_content_margin_all(margem)
	box.shadow_color = Color(0.06, 0.08, 0.12, 0.12)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
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
