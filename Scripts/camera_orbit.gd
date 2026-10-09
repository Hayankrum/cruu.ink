class_name CameraOrbit
extends Node3D

@export var target_path: NodePath = NodePath("../GridMapWorld")
@export var fit_on_start := true
@export_range(10.0, 85.0) var fit_pitch: float = 45.0
@export var distance: float = 15.0
@export_range(-85.0, 85.0) var pitch: float = 30.0
@export var yaw: float = 0.0
@export var min_distance: float = 4.0
@export var max_distance: float = 35.0
@export_range(0.0, 89.0) var max_pitch: float = 85.0
@export var min_camera_height: float = 0.15
@export var rotate_speed: float = 0.008
@export var pitch_speed: float = 0.18
@export var zoom_speed: float = 0.08
@export_range(20.0, 120.0, 0.5) var fov: float = 55.0

var _grid: GridMap

@onready var camera: Camera3D = $Camera3D

var _focus_active := false
var _focus_aim := Vector3.ZERO
var _focus_yaw := 0.0
var _focus_dist := 3.0
var _focus_pitch := 15.0
var _prev_distance := 15.0
var _prev_pitch := 30.0
var _prev_yaw := 0.0
var _animating := false

func _ready() -> void:
	var node: Node = get_node_or_null(target_path)
	if node is GridMap:
		_grid = node
	camera.fov = fov
	if _grid != null:
		var bounds := _target_bounds()
		global_position = bounds["center"]
		if fit_on_start:
			yaw = 0.0
			pitch = fit_pitch
			distance = _fit_distance(bounds["extent"])
		else:
			var delta: Vector3 = camera.global_position - global_position
			distance = clampf(delta.length(), min_distance, max_distance)
			yaw = atan2(delta.x, delta.z)
			pitch = rad_to_deg(asin(clampf(delta.y / distance, -1.0, 1.0)))
	distance = clampf(distance, min_distance, max_distance)
	_prev_distance = distance
	_prev_pitch = pitch
	_prev_yaw = yaw
	_apply()

func _process(delta: float) -> void:
	if not _animating:
		return
	var k := 1.0 - exp(-delta / 0.35)
	var ty: float = _focus_yaw if _focus_active else _prev_yaw
	var td: float = _focus_dist if _focus_active else _prev_distance
	var tp: float = _focus_pitch if _focus_active else _prev_pitch
	yaw += wrapf(ty - yaw, -PI, PI) * k
	distance = lerpf(distance, td, k)
	pitch = lerpf(pitch, tp, k)
	_apply()
	if absf(distance - td) < 0.002 and absf(pitch - tp) < 0.01 and absf(wrapf(ty - yaw, -PI, PI)) < 0.001:
		_animating = false
		yaw = ty

func focus_at(aim: Vector3, dist: float, pitch_deg: float) -> void:
	if _focus_active:
		return
	_prev_distance = distance
	_prev_pitch = pitch
	_prev_yaw = yaw
	_focus_aim = aim
	_focus_yaw = yaw
	_focus_dist = dist
	_focus_pitch = pitch_deg
	_focus_active = true
	_animating = true

func focus_at_front(aim: Vector3, fwd: Vector3, dist: float, pitch_deg: float) -> void:
	if _focus_active:
		return
	_prev_distance = distance
	_prev_pitch = pitch
	_prev_yaw = yaw
	var d := fwd
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	else:
		d = d.normalized()
	_focus_aim = aim
	_focus_yaw = atan2(d.x, d.z)
	_focus_dist = dist
	_focus_pitch = pitch_deg
	_focus_active = true
	_animating = true

func unfocus() -> void:
	if not _focus_active:
		return
	_focus_active = false
	_animating = true

func _take_control() -> void:
	if _focus_active:
		_focus_yaw = yaw
		_focus_dist = distance
		_focus_pitch = pitch
	_animating = false
	_apply()

var _touches: Dictionary = {}
var _pinch_last := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance * (1.0 - zoom_speed), min_distance, max_distance)
				_take_control()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance * (1.0 + zoom_speed), min_distance, max_distance)
				_take_control()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 2:
				_pinch_last = _pinch_distance()
		else:
			_touches.erase(st.index)
			_pinch_last = 0.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.size() >= 2:
			_touches[sd.index] = sd.position
			var d := _pinch_distance()
			if _pinch_last > 1.0 and d > 1.0:
				distance = clampf(distance * (_pinch_last / d), min_distance, max_distance)
				_take_control()
				_pinch_last = d
		else:
			yaw -= sd.relative.x * rotate_speed
			pitch = clampf(pitch + sd.relative.y * pitch_speed, -max_pitch, max_pitch)
			_take_control()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * rotate_speed
		pitch = clampf(pitch + mm.relative.y * pitch_speed, -max_pitch, max_pitch)
		_take_control()

func _pinch_distance() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)

func _target_bounds() -> Dictionary:
	var cells: Array[Vector3i] = _grid.get_used_cells()
	if cells.is_empty():
		return {"center": _grid.global_position, "extent": 10.0}
	var min_c: Vector3i = cells[0]
	var max_c: Vector3i = cells[0]
	for c in cells:
		min_c = min_c.min(c)
		max_c = max_c.max(c)
	@warning_ignore("integer_division")
	var mid := Vector3i((min_c.x + max_c.x) / 2, min_c.y, (min_c.z + max_c.z) / 2)
	var center := _grid.to_global(_grid.map_to_local(mid))
	var wx := float(max_c.x - min_c.x + 1) * _grid.cell_size.x
	var wz := float(max_c.z - min_c.z + 1) * _grid.cell_size.z
	var extent: float = max(wx, wz) * 0.5
	return {"center": center, "extent": extent}

func _fit_distance(extent: float) -> float:
	var vp_size: Vector2i = get_viewport().size
	var aspect := float(vp_size.x) / float(max(vp_size.y, 1))
	var vfov := deg_to_rad(camera.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	return extent / tan(hfov * 0.5) * 1.15

func _apply() -> void:
	var p := deg_to_rad(pitch)
	var dir := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p))
	var center := _focus_aim if _focus_active else global_position
	var pos: Vector3 = center + dir * distance
	var min_y: float = center.y + min_camera_height
	if pos.y < min_y:
		pos.y = min_y
	camera.global_position = pos
	camera.look_at(center, Vector3.UP)
