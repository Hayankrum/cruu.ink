class_name Traffic
extends Node3D

@export var target_path: NodePath = NodePath("../GridMapWorld")
@export_range(1, 8, 1) var count := 4
@export var car_scenes: Array[PackedScene] = []
@export_range(0.1, 20.0, 0.1) var speed := 2.0
@export var speed_variation := 0.0
@export var travel_height := 0.0
@export var vehicle_scale := 1.0
@export_range(0.0, 1.0, 0.01) var raise_ratio := 0.15
@export var lane_offset := 0.35
@export var yaw_offset_deg := 0.0
@export var max_lifetime := 180.0

@export var parking_cell := Vector3i(2, 0, 3)
@export_range(0.5, 4.0, 0.1) var park_pick_radius := 1.2
@export_range(1.0, 60.0, 0.5) var park_cooldown := 10.0
@export var closed_edges: Array[Vector3i] = [
	Vector3i(1, 0, 3), Vector3i(0, 0, 3),
]
@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export var pedestrian_path: NodePath = NodePath("../Pedestrians")
@export_range(1.0, 12.0, 0.1) var dialog_zoom_dist := 3.0
@export var dialog_zoom_pitch := 8.0
## Desligado na cena CityNotebook: mantém carros andando, sem clique/diálogo/ícone.
@export var enable_interaction := true

const DIRS := [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

const CORNER_R := 0.5
const SMOOTH_STEP := 0.12

const FALLBACK_PATHS := [
	"res://Assets/CUTES Part One.undefined-glb/Vehicle.glb",
	"res://Assets/CUTES Part One.undefined-glb/Orange Vehicle.glb",
	"res://Assets/CUTES Part One.undefined-glb/Taxi Vehicle.glb",
	"res://Assets/CUTES Part One.undefined-glb/Police Car.glb",
]

var _roads: Dictionary = {}
var _adj: Dictionary = {}
var _corners: Array[Vector3i] = []
var _pool: Array[PackedScene] = []
var _cars: Array[Dictionary] = []
var _grid: GridMap
var _seg: float = 2.0
var _parking_pos := Vector3.ZERO
var _stopper: Dictionary = {}
var _icon: Label
var _camera_rig: CameraOrbit
var _pedestrians: Pedestrians
var _dialog_open := false
var _parker_idx := 0
var _releasing: Dictionary = {}
var _release_t := 0.0

func _ready() -> void:
	var node: Node = get_node_or_null(target_path)
	if node is GridMap:
		_grid = node
	if _grid == null:
		push_warning("Traffic: GridMap nao encontrado em ", target_path)
		return
	_seg = maxf(_grid.cell_size.x, 0.01)
	_pool = _load_pool()
	if _pool.is_empty():
		push_warning("Traffic: nenhum veiculo CUTES disponivel")
		return
	_build_road_graph()
	if _corners.is_empty():
		push_warning("Traffic: nenhum cruzamento disponivel para as rotas")
		return
	_parking_pos = _world(parking_cell)
	_build_icon()
	var rig: Node = get_node_or_null(camera_rig_path)
	if rig is CameraOrbit:
		_camera_rig = rig
	var p: Node = get_node_or_null(pedestrian_path)
	if p is Pedestrians:
		_pedestrians = p
	for i in count:
		_create_car(i)

func _load_pool() -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	var list: Array[PackedScene] = []
	if car_scenes.is_empty():
		for path: String in FALLBACK_PATHS:
			var scene: PackedScene = load(path)
			if scene != null:
				list.append(scene)
	else:
		list = car_scenes.duplicate()
	for scene: PackedScene in list:
		if scene != null:
			pool.append(scene)
	return pool

func _build_road_graph() -> void:
	_roads.clear()
	_adj.clear()
	_corners.clear()
	var ml: MeshLibrary = _grid.mesh_library
	if ml == null:
		return
	for cell: Vector3i in _grid.get_used_cells():
		var item: int = _grid.get_cell_item(cell)
		var nm: String = ml.get_item_name(item)
		if not "road" in nm.to_lower():
			continue
		_roads[cell] = true
	for cell: Vector3i in _roads:
		var neigh: Array[Vector3i] = []
		for d: Vector3i in DIRS:
			var nb := cell + d
			if _roads.has(nb) and not _edge_blocked(cell, nb):
				neigh.append(nb)
		_adj[cell] = neigh
	for cell: Vector3i in _roads:
		var nm: String = ml.get_item_name(_grid.get_cell_item(cell)).to_lower()
		if "cruzamento" in nm:
			_corners.append(cell)

func _edge_blocked(a: Vector3i, b: Vector3i) -> bool:
	for i in range(0, closed_edges.size(), 2):
		if i + 1 >= closed_edges.size():
			break
		if (closed_edges[i] == a and closed_edges[i + 1] == b) or (closed_edges[i] == b and closed_edges[i + 1] == a):
			return true
	return false

func _pick_corner() -> Vector3i:
	if _cars.is_empty():
		return _corners[randi() % _corners.size()]
	var best: Vector3i = _corners[0]
	var best_d: float = -1.0
	for c: Vector3i in _corners:
		var pos: Vector3 = _world(c)
		var d := INF
		for car: Dictionary in _cars:
			d = minf(d, pos.distance_to(car["holder"].global_position))
		if d > best_d:
			best_d = d
			best = c
	return best

func _make_path(start: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = [start]
	var current := start
	var prev := Vector3i(99999, 99999, 99999)
	var guard := 0
	while guard < 300:
		var opts: Array[Vector3i] = []
		for n: Vector3i in _adj[current]:
			if n != prev:
				opts.append(n)
		if prev != Vector3i(99999, 99999, 99999):
			var straight := current + (current - prev)
			if _roads.has(straight) and not opts.has(straight) and not _edge_blocked(current, straight):
				opts.insert(0, straight)
		if opts.is_empty():
			break
		opts.shuffle()
		if opts.has(start) and path.size() >= 6:
			path.append(start)
			return path
		var choose: Vector3i = opts[0]
		prev = current
		current = choose
		path.append(current)
		if current == start and path.size() >= 6:
			return path
		guard += 1
	return path

func _centers(path: Array) -> Array:
	var out: Array = []
	for cell: Vector3i in path:
		out.append(_world(cell))
	return out

func _smooth_path(centers: Array, radius: float) -> Dictionary:
	var verts: Array = []
	verts.append(centers[0])
	var n: int = centers.size()
	for i in range(1, n - 1):
		var a: Vector3 = centers[i - 1]
		var b: Vector3 = centers[i]
		var c: Vector3 = centers[i + 1]
		var t_dist: float = minf(minf(radius, a.distance_to(b) * 0.4), b.distance_to(c) * 0.4)
		var dir1: Vector3 = (b - a)
		if dir1.length_squared() < 0.0001:
			dir1 = Vector3.RIGHT
		dir1 = dir1.normalized()
		var dir2: Vector3 = (c - b)
		if dir2.length_squared() < 0.0001:
			dir2 = dir1
		dir2 = dir2.normalized()
		var p0: Vector3 = b - dir1 * t_dist
		var p2: Vector3 = b + dir2 * t_dist
		verts.append(p0)
		for k in range(1, 8):
			var u := float(k) / 8.0
			var q: Vector3 = (1.0 - u) * (1.0 - u) * p0 + 2.0 * u * (1.0 - u) * b + u * u * p2
			verts.append(q)
		verts.append(p2)
	verts.append(centers[n - 1])
	var points := PackedVector3Array()
	points.append(verts[0])
	for i in range(1, verts.size()):
		var from: Vector3 = verts[i - 1]
		var to: Vector3 = verts[i]
		var seg: float = from.distance_to(to)
		var m := maxi(int(seg / SMOOTH_STEP), 1)
		for k in range(1, m):
			points.append(from.lerp(to, float(k) / float(m)))
		points.append(to)
	var cum: Array = [0.0]
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		cum.append(total)
	return {"points": points, "cum": cum, "total": total}

func _drive(car: Dictionary, s: float) -> Dictionary:
	var pts: PackedVector3Array = car["points"]
	var cum: Array = car["cum"]
	var n := pts.size() - 1
	var idx := 0
	for k in range(0, n):
		if float(cum[k + 1]) >= s:
			idx = k
			break
	var d0 := float(cum[idx])
	var u := clampf((s - d0) / maxf(float(cum[idx + 1]) - d0, 0.0001), 0.0, 1.0)
	var pos: Vector3 = pts[idx].lerp(pts[idx + 1], u)
	var dir: Vector3 = (pts[idx + 1] - pts[idx])
	if dir.length_squared() < 0.0001:
		dir = pts[idx] - pts[maxi(idx - 1, 0)]
	dir = dir.normalized()
	return {"pos": pos, "dir": dir}

func _create_car(index: int) -> void:
	var wants_park := index == _parker_idx
	var path: Array[Vector3i] = []
	for tries in 80:
		path = _make_path(_pick_corner())
		if path.size() < 6:
			continue
		if _passes_parking(path) == wants_park:
			break
	if path.size() < 6:
		return
	var smooth := _smooth_path(_centers(path), CORNER_R)
	var pts: PackedVector3Array = smooth["points"]
	if pts.size() < 4:
		return
	var holder := Node3D.new()
	holder.name = "Carro %d" % (index + 1)
	add_child(holder)
	holder.position = pts[0]
	var model: Node3D = _pool[index % _pool.size()].instantiate()
	model.name = "Model"
	model.rotation_degrees = Vector3(0.0, yaw_offset_deg, 0.0)
	model.scale = Vector3.ONE * vehicle_scale
	model.position = Vector3(lane_offset, vehicle_scale * raise_ratio, 0.0)
	holder.add_child(model)
	var base := speed * maxf(1.0 + randf_range(-speed_variation, speed_variation), 0.2)
	var park_s := -1.0
	if _passes_parking(path):
		park_s = _nearest_s({"points": pts, "cum": smooth["cum"]}, _parking_pos)
	_cars.append({
		"holder": holder,
		"model": model,
		"index": index,
		"points": pts,
		"cum": smooth["cum"],
		"total": smooth["total"],
		"s": 0.0,
		"speed": base,
		"lifetime": 0.0,
		"parked": false,
		"park_s": park_s,
	})

func _respawn(dict: Dictionary) -> void:
	var holder: Node3D = dict["holder"]
	if not _stopper.is_empty() and dict["holder"] == _stopper.get("holder", null):
		_stopper = {}
		_dialog_open = false
	if is_instance_valid(holder):
		holder.queue_free()
	_cars.erase(dict)
	_create_car(dict["index"])

func _passes_parking(path: Array) -> bool:
	for cell: Vector3i in path:
		if _world(cell).distance_to(_parking_pos) < park_pick_radius:
			return true
	return false

func _rebuild_car(car: Dictionary, wants_park: bool) -> void:
	var path: Array[Vector3i] = []
	for tries in 80:
		path = _make_path(_pick_corner())
		if path.size() < 6:
			continue
		if _passes_parking(path) == wants_park:
			break
	if path.size() < 6:
		return
	var smooth := _smooth_path(_centers(path), CORNER_R)
	var pts: PackedVector3Array = smooth["points"]
	if pts.size() < 4:
		return
	var pos: Vector3 = car["holder"].global_position
	car["points"] = pts
	car["cum"] = smooth["cum"]
	car["total"] = smooth["total"]
	car["s"] = _nearest_s(car, pos)
	car["park_s"] = _nearest_s(car, _parking_pos) if wants_park else -1.0

func _rotate_parker() -> void:
	if _cars.is_empty():
		return
	_parker_idx = (_parker_idx + 1) % maxi(count, 1)
	for car: Dictionary in _cars:
		_rebuild_car(car, int(car["index"]) == _parker_idx)
	print("Traffic: novo candidato a interagir -> index ", _parker_idx)

func _nearest_s(car: Dictionary, target: Vector3) -> float:
	var pts: PackedVector3Array = car["points"]
	var cum: Array = car["cum"]
	var best_i := 0
	var best_d := INF
	for i in range(pts.size()):
		var d: float = pts[i].distance_to(target)
		if d < best_d:
			best_d = d
			best_i = i
	return float(cum[best_i])

func _park(car: Dictionary) -> void:
	car["parked"] = true
	car["park_cd"] = park_cooldown
	car["lifetime"] = 0.0
	car["s"] = _nearest_s(car, _parking_pos)
	car["holder"].position = _parking_pos
	_stopper = car

func _sync_dialog() -> void:
	if _stopper.is_empty():
		_dialog_open = false
		return
	var open := _pedestrians != null and _pedestrians.is_dialog_open()
	if _dialog_open and not open:
		var car: Dictionary = _stopper
		car["parked"] = false
		_stopper = {}
		_releasing = car
		_release_t = 0.0
	_dialog_open = open

func _process(delta: float) -> void:
	_sync_dialog()
	for car: Dictionary in _cars.duplicate():
		var parked := bool(car["parked"])
		if parked:
			continue
		var total: float = float(car["total"])
		car["park_cd"] = maxf(0.0, float(car.get("park_cd", 0.0)) - delta)
		car["lifetime"] = float(car["lifetime"]) + delta
		if float(car["lifetime"]) > max_lifetime:
			_respawn(car)
			continue
		var r := _drive(car, float(car["s"]))
		var next_s := float(car["s"]) + float(car["speed"]) * delta
		if next_s >= total:
			next_s = fmod(next_s, total)
		if not _cars.has(car):
			continue
		r = _drive(car, next_s)
		car["s"] = next_s
		var r_dir: Vector3 = r["dir"]
		car["holder"].position = r["pos"]
		car["holder"].rotation = Vector3(0.0, atan2(-r_dir.x, -r_dir.z), 0.0)
		if _stopper.is_empty() and float(car.get("park_cd", 0.0)) <= 0.0 and car["holder"].global_position.distance_to(_parking_pos) < park_pick_radius:
			_park(car)
	if not _releasing.is_empty() and _stopper.is_empty():
		_release_t += delta
		if _release_t > 1.5:
			_release_t = 0.0
			_releasing = {}
			_rotate_parker()
	_update_icon()

func _build_icon() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI_Carros"
	ui.layer = 11
	add_child(ui)
	_icon = Label.new()
	_icon.text = "!"
	_icon.size = Vector2(48, 48)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.add_theme_font_size_override("font_size", 30)
	_icon.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_icon.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_icon.add_theme_constant_override("shadow_offset_x", 2)
	_icon.add_theme_constant_override("shadow_offset_y", 2)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	ui.add_child(_icon)

func _update_icon() -> void:
	if not enable_interaction or _stopper.is_empty() or _dialog_open:
		_icon.visible = false
		return
	var cam: Camera3D = _camera_rig.camera if _camera_rig != null else null
	if cam == null:
		_icon.visible = false
		return
	var holder: Node3D = _stopper["holder"]
	var head: Vector3 = holder.global_position + Vector3(0.0, 1.2, 0.0)
	if cam.is_position_behind(head):
		_icon.visible = false
		return
	var sp: Vector2 = cam.unproject_position(head)
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	if sp.x < 0.0 or sp.y < 0.0 or sp.x > view.x or sp.y > view.y:
		_icon.visible = false
		return
	_icon.visible = true
	_icon.global_position = sp - _icon.size * 0.5
	_icon.pivot_offset = _icon.size * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if not enable_interaction:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _stopper.is_empty() or _dialog_open:
		return
	if _pedestrians != null and _pedestrians.is_dialog_open():
		return
	var cam: Camera3D = _camera_rig.camera if _camera_rig != null else null
	if cam == null:
		return
	var holder: Node3D = _stopper["holder"]
	if not _clique_no_carro(cam, holder, mb.position):
		return
	if _pedestrians != null:
		_pedestrians.open_car_dialog(holder, "carro")
		get_viewport().set_input_as_handled()

## Clique válido quando cai em cima do carro de verdade: projeta a caixa 3D
## do modelo na tela e testa o ponto contra esse polígono (com folga),
## em vez de comparar com um ponto fixo acima do veículo.
func _clique_no_carro(cam: Camera3D, holder: Node3D, pos: Vector2) -> bool:
	var modelo: Node3D = holder.get_node_or_null("Model") as Node3D
	if modelo == null:
		modelo = holder
	var centro: Vector3 = modelo.global_position + Vector3(0.0, 0.5, 0.0)
	var box := _aabb_mundo(modelo)
	if box.size == Vector3.ZERO:
		return _perto_de(cam, centro, pos, 72.0)
	var cantos := PackedVector3Array()
	for i in 8:
		cantos.append(box.position + Vector3(
			box.size.x * float(i & 1),
			box.size.y * float((i >> 1) & 1),
			box.size.z * float((i >> 2) & 1)))
	var visiveis := PackedVector2Array()
	var algum_atras := false
	for c: Vector3 in cantos:
		if cam.is_position_behind(c):
			algum_atras = true
			continue
		visiveis.append(cam.unproject_position(c))
	if visiveis.size() < 3:
		return _perto_de(cam, centro, pos, 96.0)
	if algum_atras:
		# Parte do carro atrás da câmera: projegação fica distorcida,
		# então usa a área dos cantos visíveis com folga maior.
		var min_p: Vector2 = visiveis[0]
		var max_p: Vector2 = visiveis[0]
		for p: Vector2 in visiveis:
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
		return Rect2(min_p, max_p - min_p).grow(24.0).has_point(pos)
	var casca := Geometry2D.convex_hull(visiveis)
	if casca.size() < 3:
		return _perto_de(cam, centro, pos, 72.0)
	if Geometry2D.is_point_in_polygon(pos, casca):
		return true
	return _dist_ate_poligono(pos, casca) <= 18.0

func _perto_de(cam: Camera3D, alvo: Vector3, pos: Vector2, raio: float) -> bool:
	if cam.is_position_behind(alvo):
		return false
	return cam.unproject_position(alvo).distance_to(pos) <= raio

## AABB mundial de todas as malhas sob o nó (mesma varredura do pedestrians).
func _aabb_mundo(no: Node3D) -> AABB:
	var box := AABB()
	var tem := false
	var pilha: Array[Node] = [no]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		for c: Node in n.get_children():
			pilha.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var t := mi.global_transform * mi.get_aabb()
			if not tem:
				box = t
				tem = true
			else:
				box = box.merge(t)
	return box if tem else AABB()

func _dist_ate_poligono(p: Vector2, poly: PackedVector2Array) -> float:
	var melhor := INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		melhor = minf(melhor, _dist_segmento(p, a, b))
	return melhor

func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _world(cell: Vector3i) -> Vector3:
	var p := _grid.to_global(_grid.map_to_local(cell))
	p.y += travel_height
	return p
