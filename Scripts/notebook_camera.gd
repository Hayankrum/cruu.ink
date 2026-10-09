extends Camera3D
# Câmera do notebook:
# - Home bem atrás e alinhada com a tela (lado do usuário)
# - O eixo de giro é a PRÓPRIA câmera: a posição fica fixa e ela
#   rotaciona no lugar (não orbita em torno do notebook)
# - Sempre parte olhando para o centro da tela; giro limitado

## Centro da tela em espaço do parent (Notebook 0.21,0,-0.12 + CENTER_OFFSET).
@export var face_offset := Vector3(0.078, 0.0875, 0.075)
## Home: atrás da tela e alinhada em X com o centro (visao do usuario).
@export var home_offset := Vector3(0.078, 0.26, -0.35)
@export_range(0.0, 89.0) var yaw_range_deg := 35.0
## Pitch absoluto da direcao de visao (graus; negativo = olhando p/ baixo).
@export var pitch_min_deg := -45.0
@export var pitch_max_deg := -5.0
@export var rotate_speed := 0.004
@export var pitch_speed := 0.06

var _face := Vector3.ZERO
var _home := Vector3.ZERO
var _pitch := -22.0
var _yaw := 0.0
var _home_yaw := 0.0
var _home_pitch := -22.0
var _panel: Control
var _drag_active := false

func _ready() -> void:
	_home = _to_global(home_offset)
	_face = _to_global(face_offset)
	global_position = _home
	var look := _face - _home
	var len := look.length()
	_home_pitch = clampf(rad_to_deg(asin(clampf(look.y / maxf(len, 1e-5), -1.0, 1.0))), pitch_min_deg, pitch_max_deg)
	_home_yaw = atan2(look.x, look.z)
	_pitch = _home_pitch
	_yaw = _home_yaw
	_panel = _find_ui_panel()
	_apply()

func _to_global(local: Vector3) -> Vector3:
	var st := get_parent()
	if st is Node3D:
		return (st as Node3D).global_transform * local
	return local

func _refresh_points() -> void:
	_face = _to_global(face_offset)
	_home = _to_global(home_offset)

func _find_ui_panel() -> Control:
	var root := get_tree().current_scene
	if root != null:
		var n := root.get_node_or_null("ui_notbook")
		if n is Control:
			return n
		var found := root.find_child("ui_notbook", true, false)
		if found is Control:
			return found
	var st: Node = get_parent()
	while st != null:
		if st.name == "ui_notbook" and st is Control:
			return st
		for c in st.get_children():
			if c.name == "ui_notbook" and c is Control:
				return c
		st = st.get_parent()
	return null

func _clamp_cam() -> void:
	_yaw = _home_yaw + clampf(wrapf(_yaw - _home_yaw, -PI, PI), -deg_to_rad(yaw_range_deg), deg_to_rad(yaw_range_deg))
	_pitch = clampf(_pitch, pitch_min_deg, pitch_max_deg)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			# Igual à câmera da cidade: girar só com o botão direito.
			_drag_active = mb.pressed and not _over_panel(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _drag_active or (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
			_drag_active = false
			return
		_yaw -= mm.relative.x * rotate_speed
		_pitch -= mm.relative.y * pitch_speed
		_clamp_cam()
		_apply()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_drag_active = st.pressed and not _over_panel(st.position)
	elif event is InputEventScreenDrag and _drag_active:
		var sd := event as InputEventScreenDrag
		_yaw -= sd.relative.x * rotate_speed
		_pitch -= sd.relative.y * pitch_speed
		_clamp_cam()
		_apply()
		get_viewport().set_input_as_handled()

func _over_panel(p: Vector2) -> bool:
	return _panel != null and _panel.visible and _panel.get_global_rect().has_point(p)

func _apply() -> void:
	_refresh_points()
	global_position = _home
	var p := deg_to_rad(_pitch)
	var forward := Vector3(sin(_yaw) * cos(p), sin(p), cos(_yaw) * cos(p))
	look_at(global_position + forward, Vector3.UP)
