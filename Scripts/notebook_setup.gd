extends Node3D
## Setup 3D do notebook no mundo da cidade (sem janela/canvas full-screen).
## - Laptop via GLB + shader de tela (SubViewport Tela só alimenta a textura)
## - Cidade fica de fundo (mesmo WorldEnvironment/GridMap da cena)

const NOTEBOOK_GLB := "res://Assets/obg/Notebook.glb"
const SCREEN_SHADER := "res://Scripts/notebook_screen.gdshader"

const SCREEN_ORIGIN := Vector3(-0.0177349597, 0.0293890703, 0.1687812954)
const SCREEN_AXIS_U := Vector3(-0.228530034, 0.0, 0.0)
const SCREEN_AXIS_V := Vector3(0.0, 0.116231231, 0.0519927)

var _mat: ShaderMaterial
var _vp: SubViewport

func _enter_tree() -> void:
	add_to_group("notebook_stage")
	_ensure_notebook()

func _ready() -> void:
	_vp = get_node_or_null("Tela") as SubViewport
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var lap := get_node_or_null("Notebook/laptop") as MeshInstance3D
	if lap == null:
		return
	var mat := lap.get_surface_override_material(1) as ShaderMaterial
	if mat == null:
		return
	_mat = mat
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.024, 0.034, 0.052, 1.0))
	_mat.set_shader_parameter("ui_texture", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("screen_origin", SCREEN_ORIGIN)
	_mat.set_shader_parameter("screen_axis_u", SCREEN_AXIS_U)
	_mat.set_shader_parameter("screen_axis_v", SCREEN_AXIS_V)

func _process(_delta: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("load_t", -1.0)
	_mat.set_shader_parameter("ui_enabled", true)
	if _vp != null:
		_mat.set_shader_parameter("ui_texture", _vp.get_texture())

func _ensure_notebook() -> void:
	if get_node_or_null("Notebook") != null:
		return
	var nb := Node3D.new()
	nb.name = "Notebook"
	add_child(nb)

	var glb: PackedScene = load(NOTEBOOK_GLB)
	if glb == null:
		push_warning("NotebookSetup: GLB nao encontrado em ", NOTEBOOK_GLB)
		return
	var tmp := glb.instantiate()
	var laptop := tmp.get_node_or_null("laptop") as MeshInstance3D
	if laptop == null:
		for c in tmp.get_children():
			if c is MeshInstance3D:
				laptop = c
				break
	if laptop == null:
		tmp.free()
		push_warning("NotebookSetup: mesh laptop nao encontrada no GLB")
		return
	tmp.remove_child(laptop)
	laptop.name = "laptop"
	laptop.owner = null
	nb.owner = null
	nb.add_child(laptop)
	tmp.free()

	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.09, 0.12, 0.13)
	body.roughness = 0.55
	var keys := StandardMaterial3D.new()
	keys.albedo_color = Color(0.15, 0.2, 0.21)
	keys.roughness = 0.9
	var screen := ShaderMaterial.new()
	screen.shader = load(SCREEN_SHADER)
	screen.set_shader_parameter("screen_origin", SCREEN_ORIGIN)
	screen.set_shader_parameter("screen_axis_u", SCREEN_AXIS_U)
	screen.set_shader_parameter("screen_axis_v", SCREEN_AXIS_V)
	laptop.set_surface_override_material(0, body)
	laptop.set_surface_override_material(1, screen)
	laptop.set_surface_override_material(2, keys)

	# Mesma pose do NotebookStage (câmera orbita esse centro).
	nb.position = Vector3(0.21, 0.0, -0.12)

