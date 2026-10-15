class_name Pedestrians
extends Node3D

signal dialogo_concluido(nome_npc: String, e_carro: bool)

@export var target_path: NodePath = NodePath("../GridMapWorld")
@export var count := 13
@export var pedestrian_scenes: Array[PackedScene] = []
@export_range(0.1, 5.0, 0.1) var speed := 0.6
@export var speed_variation := 0.25
@export var travel_height := 0.0
@export var pedestrian_scale := 0.12
@export var ground_offset := 0.0
@export_range(-1.0, 1.0, 0.01) var ground_lift := -0.15
@export var yaw_offset_deg := 180.0
@export var max_lifetime := 180.0
@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export_range(1.0, 30.0) var interact_refresh := 5.0
@export_range(0.4, 10.0, 0.1) var dialog_zoom_dist := 0.7
@export var dialog_zoom_pitch := 2.0
@export_range(0.4, 10.0, 0.1) var car_dialog_zoom_dist := 1.8
@export_range(-20.0, 45.0, 1.0) var car_dialog_zoom_pitch := 0.0
@export_file("*.json") var dialog_path := ""
## Desligado na cena CityNotebook: mantém NPCs andando, sem clique/diálogo/ícone.
@export var enable_interaction := true

const DIRS := [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

const CORNER_R := 0.45
const SMOOTH_STEP := 0.1
const MIN_PATH := 6

const ANIM_IDLE := "Armature|Idle"
const ANIM_WALK := "Armature|Walk"

const FALLBACK_PATHS := [
	"res://Assets/CUTES Part One.undefined-glb/Generic Male.glb",
	"res://Assets/CUTES Part One.undefined-glb/Generic Female.glb",
	"res://Assets/CUTES Part One.undefined-glb/Citizen 1.glb",
	"res://Assets/CUTES Part One.undefined-glb/Citizen 2.glb",
	"res://Assets/CUTES Part One.undefined-glb/Citizen 3.glb",
	"res://Assets/CUTES Part One.undefined-glb/Crypto Bro.glb",
	"res://Assets/CUTES Part One.undefined-glb/Food Worker.glb",
	"res://Assets/CUTES Part One.undefined-glb/Retail Worker.glb",
	"res://Assets/CUTES Part One.undefined-glb/Male Officer.glb",
	"res://Assets/CUTES Part One.undefined-glb/Female Officer.glb",
	"res://Assets/CUTES Part One.undefined-glb/Prisoner.glb",
	"res://Assets/CUTES Part One.undefined-glb/Santa Claus.glb",
	"res://Assets/CUTES Part One.undefined-glb/Chicken Guy.glb",
]

var _sw: Dictionary = {}
var _adj: Dictionary = {}
var _pool: Array[PackedScene] = []
var _peds: Array[Dictionary] = []
var _grid: GridMap
var _spawn_seq := 0
var _region_center := Vector3.ZERO
var _camera_rig: CameraOrbit
var _icon: Label
var _dialog: Panel
var _dialog_name: Label
var _dialog_text: RichTextLabel
var _dialog_vbox: VBoxContainer
var _dialog_buttons: Array[Button] = []
var _interact_ped: Dictionary = {}
var _interact_timer := 0.0
var _dialog_ped: Dictionary = {}
var _dialog_opcoes: Array = []
var _dialog_perguntas: Array = []
var _dialog_entrevista: Dictionary = {}
var _dialog_aberturas: Array = []
var _dialog_encerramento := ""
var _dialog_perguntas_padrao: Array = []
var _dialog_by_name: Dictionary = {}
var _dialog_fila: Array = []
var _dialog_phase := ""
var _dialog_typing := false
var _dialog_car := false
var _dialog_ccps := 45.0
var _btn_avancar: Button
## O btn1 do bloco de perguntas vira este rótulo quando só há fala pra ler.
const AVANCAR_TEXTO := "Avançar ▶"

## Tolerância (px de viewport) entre "toque para falar" e "arrastar a câmera".
const TAP_TOLERANCE := 28.0
var _press_pos := Vector2.ZERO
var _press_dragged := false

## Balão de diálogo ancorado acima da cabeça de quem fala.
const BALAO_GAP := 14.0
const BALAO_MARGEM := 12.0
## Altura do balão quando ancorado (o da cena é 350 — não cabe acima da
## cabeça numa janela de 720px de altura).
const BALAO_ALTURA := 320.0
## Câmera mira um pouco ACIMA da cabeça: sobra espaço pro balão.
const BALAO_AIMOFS := 0.06
const RABO_LARGURA := 22.0
const RABO_ALTURA := 14.0
var _balao_alvo := Vector3.ZERO
var _balao_pos := Vector2.ZERO
var _balao_tamanho := Vector2.ZERO
var _balao_salvo := false
var _balao_rabo: Polygon2D

func _ready() -> void:
	var node: Node = get_node_or_null(target_path)
	if node is GridMap:
		_grid = node
	if _grid == null:
		push_warning("Pedestrians: GridMap nao encontrado em ", target_path)
		return
	_pool = _load_pool()
	if _pool.is_empty():
		push_warning("Pedestrians: nenhum personagem CUTES disponivel")
		return
	_build_sidewalk_graph()
	if _sw.is_empty():
		push_warning("Pedestrians: nenhuma calcada nos cantos das ruas")
		return
	_load_dialogs()
	for i in count:
		_create_pedestrian(i)
	_build_ui()
	if enable_interaction:
		_bind_hud()
	var rig: Node = get_node_or_null(camera_rig_path)
	if rig is CameraOrbit:
		_camera_rig = rig

func _load_dialogs() -> void:
	_dialog_aberturas = []
	_dialog_encerramento = ""
	_dialog_perguntas_padrao = []
	_dialog_by_name = {}
	var data: Variant = NarrativaManager.get_dialogos()
	if data == null or (data is Dictionary and (data as Dictionary).is_empty()):
		if dialog_path.is_empty() or not FileAccess.file_exists(dialog_path):
			push_warning("Pedestrians: dialogos nao encontrados (manager vazio ou dialog_path indefinido)")
			return
		var file := FileAccess.open(dialog_path, FileAccess.READ)
		if file == null:
			push_warning("Pedestrians: falha ao abrir ", dialog_path)
			return
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary:
			push_warning("Pedestrians: JSON de dialogos invalido em ", dialog_path)
			return
		data = parsed
	if not data is Dictionary:
		return
	var d := data as Dictionary
	if d.has("aberturas") and d["aberturas"] is Array:
		_dialog_aberturas = d["aberturas"]
	if d.has("encerramento") and d["encerramento"] is String:
		_dialog_encerramento = d["encerramento"]
	if d.has("perguntas_padrao") and d["perguntas_padrao"] is Array:
		_dialog_perguntas_padrao = d["perguntas_padrao"]
	if d.has("personagens") and d["personagens"] is Dictionary:
		_dialog_by_name = d["personagens"]

func _entrevista_for(ped: Dictionary) -> Dictionary:
	var ped_name := str(ped.get("name", ""))
	var dados: Dictionary = {}
	if _dialog_by_name.has(ped_name) and _dialog_by_name[ped_name] is Dictionary:
		dados = _dialog_by_name[ped_name]
	var nome := str(dados.get("nome", ped_name))
	var abertura := str(dados.get("abertura", _pick_from(_dialog_aberturas, "Ola! O que deseja saber?")))
	var encerramento := str(dados.get("encerramento", _dialog_encerramento))
	var perguntas: Array = []
	if dados.has("perguntas") and dados["perguntas"] is Array:
		for q: Variant in dados["perguntas"]:
			if q is Dictionary:
				perguntas.append(q)
	if perguntas.is_empty():
		perguntas = _dialog_perguntas_padrao.duplicate()
	return {"nome": nome, "abertura": abertura, "encerramento": encerramento, "perguntas": perguntas}

func _pick_from(list: Array, fallback: String) -> String:
	if list.is_empty():
		return fallback
	return str(list[randi() % list.size()])

func _load_pool() -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	var list: Array[PackedScene] = []
	if pedestrian_scenes.is_empty():
		for path: String in FALLBACK_PATHS:
			var scene: PackedScene = load(path)
			if scene != null:
				list.append(scene)
	else:
		list = pedestrian_scenes.duplicate()
	for scene: PackedScene in list:
		if scene == null:
			continue
		var probe: Node = scene.instantiate()
		var player: AnimationPlayer = _find_anim(probe)
		var keep: bool = player != null and (player.has_animation(ANIM_WALK) or not player.get_animation_list().is_empty())
		probe.free()
		if keep:
			pool.append(scene)
	return pool

func _item_name(cell: Vector3i) -> String:
	if _grid.get_cell_item(cell) == -1:
		return ""
	return _grid.mesh_library.get_item_name(_grid.get_cell_item(cell))

func _is_crossing(cell: Vector3i) -> bool:
	return "travessia" in _item_name(cell).to_lower()

func _is_road(cell: Vector3i) -> bool:
	var nm: String = _item_name(cell).to_lower()
	return "road" in nm and not _is_crossing(cell)

func _is_walkable(cell: Vector3i) -> bool:
	return _grid.get_cell_item(cell) != -1 and not _is_road(cell)

func _build_sidewalk_graph() -> void:
	_sw.clear()
	_adj.clear()
	for cell: Vector3i in _grid.get_used_cells():
		if _is_walkable(cell):
			_sw[cell] = true
	for c: Vector3i in _sw:
		var neigh: Array[Vector3i] = []
		for d: Vector3i in DIRS:
			if _sw.has(c + d):
				neigh.append(c + d)
		_adj[c] = neigh
	var acc := Vector3.ZERO
	for c: Vector3i in _sw:
		acc += _world(c)
	_region_center = acc / float(_sw.size())

func _pick_corner() -> Vector3i:
	var crosses: Array[Vector3i] = []
	for c: Vector3i in _sw:
		if _is_crossing(c):
			crosses.append(c)
	if not crosses.is_empty():
		return crosses[randi() % crosses.size()]
	var cells: Array[Vector3i] = []
	for c: Vector3i in _sw:
		if not (_adj[c] as Array).is_empty():
			cells.append(c)
	if cells.is_empty():
		cells = _sw.keys()
	return cells[randi() % cells.size()]

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
			if _sw.has(straight) and not opts.has(straight):
				opts.insert(0, straight)
		if opts.is_empty():
			break
		opts.shuffle()
		if opts.has(start) and path.size() >= MIN_PATH:
			path.append(start)
			return path
		var choose: Vector3i = opts[0]
		prev = current
		current = choose
		path.append(current)
		if current == start and path.size() >= MIN_PATH:
			return path
		guard += 1
	return path

func _centers(path: Array) -> Array:
	var half := Vector3(_grid.cell_size.x, 0.0, _grid.cell_size.z) * 0.5
	var out: Array = []
	for cell: Vector3i in path:
		var p := _world(cell)
		var d := p - _region_center
		d.y = 0.0
		var dd := Vector3(signf(d.x), 0.0, signf(d.z))
		if dd == Vector3.ZERO:
			dd = Vector3.FORWARD
		out.append(p + dd * half.x)
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

func _drive(ped: Dictionary, s: float) -> Dictionary:
	var pts: PackedVector3Array = ped["points"]
	var cum: Array = ped["cum"]
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

func _create_pedestrian(index: int) -> void:
	var start := _pick_corner()
	var path: Array[Vector3i] = []
	for tries in 20:
		start = _pick_corner()
		path = _make_path(start)
		if path.size() >= MIN_PATH:
			break
	if path.size() < MIN_PATH:
		return
	var smooth := _smooth_path(_centers(path), CORNER_R)
	var holder := Node3D.new()
	_spawn_seq += 1
	holder.name = "Pedestre %d-%d" % [index + 1, _spawn_seq]
	add_child(holder)
	holder.position = (smooth["points"] as PackedVector3Array)[0]
	var model: Node3D = _make_model(_pool[mini(index, _pool.size() - 1)])
	holder.add_child(model)
	_play(model, ANIM_IDLE)
	var base := speed * maxf(1.0 + randf_range(-speed_variation, speed_variation), 0.2)
	_peds.append({
		"holder": holder,
		"model": model,
		"index": index,
		"name": _scene_name(_pool[mini(index, _pool.size() - 1)].resource_path),
		"points": smooth["points"],
		"cum": smooth["cum"],
		"total": smooth["total"],
		"s": 0.0,
		"speed": base,
		"lifetime": 0.0,
	})

func _respawn(ped: Dictionary) -> void:
	var holder: Node3D = ped["holder"]
	if is_instance_valid(holder):
		holder.queue_free()
	_peds.erase(ped)
	_create_pedestrian(ped["index"])

func _make_model(scene: PackedScene) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * pedestrian_scale
	model.rotation_degrees = Vector3(0.0, yaw_offset_deg, 0.0)
	var min_y := _feet_y(model)
	if min_y < 0.0:
		model.position.y -= min_y
	model.position.y += _model_height(model) * ground_lift + ground_offset
	return model

func _scene_name(path: String) -> String:
	return path.get_file().get_basename()

func _feet_y(model: Node3D) -> float:
	var min_y := INF
	var stack: Array[Array] = [[model, Transform3D()]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node3D = entry[0] as Node3D
		var acc: Transform3D = entry[1]
		var t: Transform3D = acc * node.transform
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, t])
			if c is MeshInstance3D:
				var m := (c as MeshInstance3D).mesh
				if m == null:
					continue
				min_y = minf(min_y, (t * m.get_aabb()).position.y)
	if min_y == INF:
		return 0.0
	return min_y

func _model_height(model: Node3D) -> float:
	var min_y := INF
	var max_y := -INF
	var stack: Array[Array] = [[model, Transform3D()]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node3D = entry[0] as Node3D
		var acc: Transform3D = entry[1]
		var t: Transform3D = acc * node.transform
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, t])
			if c is MeshInstance3D:
				var m := (c as MeshInstance3D).mesh
				if m == null:
					continue
				var box := t * m.get_aabb()
				min_y = minf(min_y, box.position.y)
				max_y = maxf(max_y, box.position.y + box.size.y)
	if min_y == INF:
		return 0.0
	return max_y - min_y

func _play(model: Node3D, anim_name: String) -> void:
	var player: AnimationPlayer = _find_anim(model)
	if player == null:
		return
	if player.current_animation == anim_name:
		return
	if player.has_animation(anim_name):
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		player.play(anim_name)
		player.speed_scale = 1.0
	else:
		var list := player.get_animation_list()
		if not list.is_empty():
			player.get_animation(list[0]).loop_mode = Animation.LOOP_LINEAR
			player.play(list[0])

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

func _process(delta: float) -> void:
	if not enable_interaction:
		_interact_ped = {}
		_interact_timer = 0.0
	if _dialog_ped.is_empty():
		_interact_timer += delta
		if _interact_timer >= interact_refresh:
			_interact_timer = 0.0
			if enable_interaction and not _peds.is_empty():
				_interact_ped = _peds[randi() % _peds.size()]
	if _dialog_typing and _dialog_text != null:
		var total := float(_dialog_text.get_total_character_count())
		if total > 0.0:
			_dialog_text.visible_ratio += _dialog_ccps * delta / total
		else:
			_dialog_text.visible_ratio = 1.0
		if _dialog_text.visible_ratio >= 1.0:
			_dialog_text.visible_ratio = 1.0
			_dialog_typing = false
	if not _dialog_ped.is_empty():
		_atualizar_balao()
	_update_icon()
	for ped: Dictionary in _peds.duplicate():
		if ped == _dialog_ped:
			_play(ped["model"] as Node3D, ANIM_IDLE)
			continue
		ped["lifetime"] = float(ped["lifetime"]) + delta
		if float(ped["lifetime"]) > max_lifetime:
			_respawn(ped)
			continue
		ped["s"] = float(ped["s"]) + float(ped["speed"]) * delta
		if float(ped["s"]) >= float(ped["total"]):
			var pts: PackedVector3Array = ped["points"]
			ped["holder"].position = pts[pts.size() - 1]
			_respawn(ped)
			continue
		if not _peds.has(ped):
			continue
		_play(ped["model"] as Node3D, ANIM_WALK)
		var r := _drive(ped, float(ped["s"]))
		ped["holder"].position = r["pos"]
		ped["holder"].rotation = Vector3(0.0, atan2(-(r["dir"] as Vector3).x, -(r["dir"] as Vector3).z), 0.0)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_icon = Label.new()
	_icon.text = "!"
	_icon.size = Vector2(48, 48)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.add_theme_font_size_override("font_size", 30)
	_icon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	_icon.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_icon.add_theme_constant_override("shadow_offset_x", 2)
	_icon.add_theme_constant_override("shadow_offset_y", 2)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	ui.add_child(_icon)

func _bind_hud() -> void:
	_dialog = get_node_or_null("../CanvasLayer/Panel_dialgo") as Panel
	if _dialog == null:
		push_warning("Pedestrians: Panel_dialgo nao encontrado na cena")
		return
	_dialog.visible = false
	# Balão inteiro deixa o clique passar pro mundo (avança o diálogo);
	# só os botões (▼ e perguntas) capturam o clique.
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignorar_clique(_dialog)
	_balao_rabo = Polygon2D.new()
	_balao_rabo.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(RABO_LARGURA, 0.0),
		Vector2(RABO_LARGURA * 0.5, RABO_ALTURA),
	])
	_balao_rabo.color = Color(0.04, 0.05, 0.08, 0.92)
	_balao_rabo.visible = false
	_dialog.add_child(_balao_rabo)
	_dialog_name = _dialog.get_node_or_null("MarginContainer/VBoxContainer/autor") as Label
	_dialog_text = _dialog.get_node_or_null("MarginContainer/VBoxContainer/dialogo") as RichTextLabel
	if _dialog_text != null:
		_dialog_text.bbcode_enabled = true
		_dialog_text.scroll_following = true
	_btn_avancar = _dialog.get_node_or_null("MarginContainer/VBoxContainer/dialogo/avançar_dialogo") as Button
	if _btn_avancar != null:
		_btn_avancar.pressed.connect(_avancar_dialogo)
	_dialog_vbox = _dialog.get_node_or_null("vbox_btn") as VBoxContainer
	if _dialog_vbox == null:
		push_warning("Pedestrians: vbox_btn (VBoxContainer) nao encontrado na cena")
		return
	_dialog_vbox.visible = false
	_dialog_buttons.clear()
	var idx := 0
	for child: Node in _dialog_vbox.get_children():
		if child is Button:
			var btn := child as Button
			btn.visible = false
			btn.pressed.connect(_on_choice.bind(idx))
			_dialog_buttons.append(btn)
			idx += 1

func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")

## Varre o balão deixando tudo que não é botão sem capturar o mouse.
func _ignorar_clique(no: Node) -> void:
	for c: Node in no.get_children():
		_ignorar_clique(c)
		if c is Button:
			continue
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_opcoes(opcoes: Array) -> void:
	_dialog_opcoes = opcoes
	for i in _dialog_buttons.size():
		var btn := _dialog_buttons[i]
		if i < _dialog_opcoes.size():
			var op: Dictionary = _dialog_opcoes[i]
			btn.text = str(op.get("texto", "..."))
			btn.visible = true
		else:
			btn.visible = false
	_dialog_vbox.alignment = VBoxContainer.ALIGNMENT_BEGIN
	_dialog_vbox.visible = true
	_dialog_phase = "perguntas"
	if _btn_avancar != null:
		_btn_avancar.visible = false
	if not _dialog_buttons.is_empty():
		_dialog_buttons[0].grab_focus()

## Clique nas falas: btn1 = "Avançar"; nas perguntas = responder.
func _on_choice(idx: int) -> void:
	if _dialog_ped.is_empty():
		return
	if _dialog_phase != "perguntas":
		_avancar_dialogo()
		return
	if idx >= _dialog_opcoes.size():
		return
	var op: Dictionary = _dialog_opcoes[idx]
	match str(op.get("tipo", "pergunta")):
		"continuar":
			_abrir_perguntas()
		"encerrar":
			close_dialog()
		_:
			_fazer_pergunta(op)

func _abrir_perguntas() -> void:
	if _dialog_text == null:
		return
	_mostrar_perguntas()

func _mostrar_perguntas() -> void:
	if _dialog_text == null:
		return
	if _dialog_perguntas.is_empty():
		var npc := str(_dialog_entrevista.get("encerramento", ""))
		if npc.is_empty():
			close_dialog()
			return
		_dialog_mostrar_mensagens([{"autor": str(_dialog_entrevista.get("nome", "Entrevistado")), "texto": npc}], "encerramento")
		return
	var n := mini(_dialog_perguntas.size(), _dialog_buttons.size())
	var opcoes: Array = []
	for i in n:
		var q: Dictionary = _dialog_perguntas[i]
		opcoes.append({"texto": str(q.get("pergunta", "...")), "tipo": "pergunta", "pergunta": q})
	_set_opcoes(opcoes)

func _fazer_pergunta(op: Dictionary) -> void:
	if _dialog_text == null:
		return
	var q: Dictionary = op.get("pergunta", {})
	var idx := _dialog_perguntas.find(q)
	if idx >= 0:
		_dialog_perguntas.remove_at(idx)
	var pergunta := str(q.get("pergunta", "..."))
	var resposta := str(q.get("resposta", ""))
	var fila: Array = [{"autor": "Voce", "texto": pergunta}]
	if not resposta.is_empty():
		var native := str(_dialog_entrevista.get("nome", "Entrevistado"))
		fila.append({"autor": native, "texto": resposta})
	_dialog_mostrar_mensagens(fila, "resposta")

func _dialog_mostrar_mensagens(fila: Array, phase: String = "") -> void:
	_dialog_fila = fila.duplicate()
	if not phase.is_empty():
		_dialog_phase = phase
	_mostrar_botao_avancar()
	if _dialog_name != null:
		_dialog_name.text = ""
	_dialog_mostrar_proxima()

## Enquanto há fala pra ler, o primeiro botão de escolha vira "Avançar"
## (encostado no rodapé do balão); o ▼ solto fica escondido.
func _mostrar_botao_avancar() -> void:
	if _dialog_vbox == null:
		return
	for i in _dialog_buttons.size():
		var btn := _dialog_buttons[i]
		btn.visible = i == 0
		if i == 0:
			btn.text = AVANCAR_TEXTO
	_dialog_vbox.alignment = VBoxContainer.ALIGNMENT_END
	_dialog_vbox.visible = true
	if _btn_avancar != null:
		_btn_avancar.visible = false

func _dialog_mostrar_proxima() -> void:
	if _dialog_text == null:
		return
	if _dialog_fila.is_empty():
		match _dialog_phase:
			"apresentacao", "resposta":
				_mostrar_perguntas()
			"encerramento":
				close_dialog()
		return
	var msg: Dictionary = _dialog_fila.pop_front()
	if _dialog_name != null:
		_dialog_name.text = str(msg.get("autor", ""))
	_dialog_text.clear()
	var texto := str(msg.get("texto", ""))
	match str(msg.get("autor", "")):
		"Voce":
			texto = "[color=#4cc2ff]%s[/color]" % _escape_bbcode(texto)
		_:
			if not str(msg.get("autor", "")).is_empty():
				texto = "[color=#ffd766]%s[/color]" % _escape_bbcode(texto)
	_dialog_text.append_text(texto)
	_dialog_text.visible_ratio = 0.0
	_dialog_typing = true

func _avancar_dialogo() -> void:
	if _dialog_ped.is_empty() or _dialog_text == null:
		return
	if _dialog_typing:
		_dialog_typing = false
		_dialog_text.visible_ratio = 1.0
		return
	_dialog_mostrar_proxima()

func open_dialog(ped: Dictionary) -> void:
	if not _dialog_ped.is_empty() or _dialog == null:
		return
	_dialog_ped = ped
	_dialog_entrevista = _entrevista_for(ped)
	_dialog_perguntas = (_dialog_entrevista.get("perguntas", []) as Array).duplicate()
	_dialog_perguntas.shuffle()
	_balao_alvo = _head_world(ped["model"] as Node3D)
	_preparar_balao()
	_dialog.visible = true
	AudioManager.play("open")
	var abertura := str(_dialog_entrevista.get("abertura", ""))
	_dialog_mostrar_mensagens([{"autor": str(_dialog_entrevista.get("nome", "Cidadao")), "texto": abertura}], "apresentacao")
	_icon.visible = false
	_atualizar_balao()
	if _camera_rig != null:
		var aim: Vector3 = _balao_alvo + Vector3(0.0, BALAO_AIMOFS, 0.0)
		var r := _drive(ped, float(ped["s"]))
		_camera_rig.focus_at_front(aim, r["dir"], dialog_zoom_dist, dialog_zoom_pitch)

func open_car_dialog(holder: Node3D, car_name: String) -> void:
	if not _dialog_ped.is_empty() or _dialog == null:
		return
	_dialog_ped = {"name": car_name, "holder": holder}
	_dialog_car = true
	_dialog_entrevista = _entrevista_for({"name": car_name})
	_dialog_perguntas = (_dialog_entrevista.get("perguntas", []) as Array).duplicate()
	_dialog_perguntas.shuffle()
	_balao_alvo = _head_world(holder)
	_preparar_balao()
	_dialog.visible = true
	AudioManager.play("open")
	var abertura := str(_dialog_entrevista.get("abertura", ""))
	_dialog_mostrar_mensagens([{"autor": str(_dialog_entrevista.get("nome", "Motorista")), "texto": abertura}], "apresentacao")
	_icon.visible = false
	_atualizar_balao()
	if _camera_rig != null:
		var aim: Vector3 = _balao_alvo + Vector3(0.0, BALAO_AIMOFS, 0.0)
		var fwd := -(holder.global_basis.z)
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		_camera_rig.focus_at_front(aim, fwd, car_dialog_zoom_dist, car_dialog_zoom_pitch)

## Guarda posição/tamanho originais do balão (canto da tela) na primeira
## abertura e encolhe ele pra caber acima da cabeça.
func _preparar_balao() -> void:
	if not _balao_salvo:
		_balao_pos = _dialog.position
		_balao_tamanho = _dialog.size
		_balao_salvo = true
	_dialog.size = Vector2(_dialog.size.x, BALAO_ALTURA)
	if _balao_rabo != null:
		_balao_rabo.visible = false

## Projeta a cabeça de quem fala na tela e põe o balão acima dela,
## preso às bordas do viewport (se não couber em cima, cai pra baixo).
func _atualizar_balao() -> void:
	if _dialog == null or _camera_rig == null or _dialog_ped.is_empty():
		return
	var cam := _camera_rig.camera
	if cam == null:
		return
	if cam.is_position_behind(_balao_alvo):
		_dialog.visible = false
		if _balao_rabo != null:
			_balao_rabo.visible = false
		return
	_dialog.visible = true
	var sp := cam.unproject_position(_balao_alvo)
	var vp := cam.get_viewport().get_visible_rect().size
	var sz := _dialog.size
	var x := clampf(sp.x - sz.x * 0.5, BALAO_MARGEM, maxf(vp.x - sz.x - BALAO_MARGEM, BALAO_MARGEM))
	var acima := sp.y - sz.y - BALAO_GAP >= BALAO_MARGEM
	var y: float = (sp.y - sz.y - BALAO_GAP) if acima else (sp.y + BALAO_GAP)
	y = clampf(y, BALAO_MARGEM, maxf(vp.y - sz.y - BALAO_MARGEM, BALAO_MARGEM))
	_dialog.position = Vector2(x, y)
	_posicionar_rabo(sp, acima)

## Ponta do balão apontando pra cabeça (some quando o balão fica embaixo).
func _posicionar_rabo(sp: Vector2, acima: bool) -> void:
	if _balao_rabo == null:
		return
	_balao_rabo.visible = acima
	if not acima:
		return
	var cx := clampf(sp.x - _dialog.position.x, RABO_LARGURA * 0.5 + 8.0, _dialog.size.x - RABO_LARGURA * 0.5 - 8.0)
	_balao_rabo.position = Vector2(cx - RABO_LARGURA * 0.5, _dialog.size.y - 1.0)

func is_dialog_open() -> bool:
	return not _dialog_ped.is_empty()

func close_dialog() -> void:
	if _dialog_ped.is_empty():
		return
	AudioManager.play("close")
	var nome_npc := str(_dialog_ped.get("name", "cidadao"))
	var e_carro := _dialog_car
	dialogo_concluido.emit(nome_npc, e_carro)
	_dialog_ped = {}
	_dialog_car = false
	_dialog_opcoes = []
	_dialog_perguntas = []
	_dialog_entrevista = {}
	_dialog_fila = []
	_dialog_phase = ""
	_dialog_typing = false
	if _dialog != null:
		_dialog.visible = false
		if _balao_salvo:
			_dialog.position = _balao_pos
			_dialog.size = _balao_tamanho
	if _balao_rabo != null:
		_balao_rabo.visible = false
	if _dialog_vbox != null:
		_dialog_vbox.visible = false
	if _btn_avancar != null:
		_btn_avancar.visible = false
	_interact_ped = {}
	_interact_timer = interact_refresh
	if _camera_rig != null:
		_camera_rig.unfocus()

func _update_icon() -> void:
	if not enable_interaction or not _dialog_ped.is_empty() or _interact_ped.is_empty() or not _peds.has(_interact_ped):
		_icon.visible = false
		return
	if _camera_rig == null:
		_icon.visible = false
		return
	var cam := _camera_rig.camera
	var model: Node3D = _interact_ped["model"] as Node3D
	if cam == null or model == null:
		_icon.visible = false
		return
	var head: Vector3 = _head_world(model)
	if cam.is_position_behind(head):
		_icon.visible = false
		return
	var sp: Vector2 = cam.unproject_position(head + Vector3(0.0, 0.15, 0.0))
	if sp.x < 0.0 or sp.y < 0.0 or sp.x > cam.get_viewport().get_visible_rect().size.x or sp.y > cam.get_viewport().get_visible_rect().size.y:
		_icon.visible = false
		return
	_icon.visible = true
	_icon.global_position = sp - _icon.size * 0.5
	_icon.pivot_offset = _icon.size * 0.5

func _input(event: InputEvent) -> void:
	if not enable_interaction:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press_dragged = false
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).position.distance_to(_press_pos) > TAP_TOLERANCE:
			_press_dragged = true

func _unhandled_input(event: InputEvent) -> void:
	if not enable_interaction:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not _dialog_ped.is_empty():
			if mb.pressed and _dialog_phase != "perguntas":
				_avancar_dialogo()
			return
		if mb.pressed:
			_press_pos = mb.position
			return
		if _press_dragged or mb.position.distance_to(_press_pos) > TAP_TOLERANCE:
			return
		_tentar_entrevistar(mb.position)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		if _dialog_ped.is_empty():
			return
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE:
			close_dialog()
		elif kc == KEY_ENTER or kc == KEY_SPACE:
			if _dialog_phase == "perguntas":
				for btn: Button in _dialog_buttons:
					if btn.visible:
						btn.pressed.emit()
						break
			else:
				_avancar_dialogo()

## Abre a entrevista se o ponto do clique/toque estiver perto de um cidadão.
func _tentar_entrevistar(pos: Vector2) -> void:
	if _camera_rig == null:
		return
	var cam := _camera_rig.camera
	if cam == null:
		return
	var best: Dictionary = {}
	var best_d := 56.0
	for ped: Dictionary in _peds:
		var model: Node3D = ped["model"] as Node3D
		if model == null:
			continue
		var head: Vector3 = _head_world(model)
		if cam.is_position_behind(head):
			continue
		var d: float = cam.unproject_position(head).distance_to(pos)
		if d < best_d:
			best_d = d
			best = ped
	if not best.is_empty():
		open_dialog(best)

func _head_world(model: Node3D) -> Vector3:
	var box := AABB()
	var has := false
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var t := mi.global_transform * mi.get_aabb()
			if has:
				box = box.merge(t)
			else:
				box = t
				has = true
	if not has:
		return model.global_position
	return box.get_center() + Vector3(0.0, box.size.y * 0.5, 0.0)

func _world(cell: Vector3i) -> Vector3:
	var p := _grid.to_global(_grid.map_to_local(cell))
	p.y += travel_height
	return p
