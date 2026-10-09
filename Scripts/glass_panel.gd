extends Panel

@export var border_px := 1.5
@export var blur_radius := 0.0
@export var bg_alpha := 0.0
@export var corner_radius := 14.0
@export var accent_width := 0.0
@export var accent_color := Color(1.0, 0.78, 0.25, 1.0)
@export var border_color := Color(1.0, 1.0, 1.0, 0.14)

func _ready() -> void:
	_fit()
	resized.connect(_fit)

func _fit() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("panelSize", size)
	if border_px > 0.0:
		mat.set_shader_parameter("borderPx", border_px)
	if blur_radius > 0.0:
		mat.set_shader_parameter("blurRadius", blur_radius)
	if bg_alpha > 0.0:
		mat.set_shader_parameter("bgAlpha", bg_alpha)
	mat.set_shader_parameter("cornerRadius", corner_radius)
	mat.set_shader_parameter("accentWidth", accent_width)
	mat.set_shader_parameter("accentColor", accent_color)
	mat.set_shader_parameter("borderColor", border_color)
