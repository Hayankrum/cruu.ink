class_name FOVOverlay
extends Camera3D

@export var enabled := true
@export var fog_color: Color = Color(0.002, 0.004, 0.02, 1.0)
@export_range(0.0, 1.0, 0.01) var fog_opacity: float = 1.0
@export_range(5.0, 200.0, 0.5) var radius: float = 14.0
@export_range(1.0, 179.0, 1.0) var cone_angle_deg: float = 70.0
@export var offset: Vector3 = Vector3.ZERO
@export var flat_cone := true

const SHADER_PATH := "res://Scripts/fov_cone.gdshader"

var _quad: MeshInstance3D
var _material: ShaderMaterial

func _ready() -> void:
	var shader: Shader = load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	_quad = MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1.0, 1.0)
	_quad.mesh = quad_mesh
	_quad.material_override = _material
	add_child(_quad)

func _process(_delta: float) -> void:
	if not enabled:
		_quad.visible = false
		return
	_quad.visible = true
	_fit_quad()
	_update_material()

func _fit_quad() -> void:
	var vp_size: Vector2i = get_viewport().size
	var aspect := float(vp_size.x) / float(max(vp_size.y, 1))
	var h := 2.0 * tan(deg_to_rad(fov) * 0.5)
	_quad.scale = Vector3(h * aspect, h, 1.0)
	_quad.position = Vector3(0.0, 0.0, -1.0)
	_quad.rotation = Vector3(0.0, PI, 0.0)

func _update_material() -> void:
	var origin := global_position + offset
	var facing := -global_basis.z
	if flat_cone:
		facing.y = 0.0
		facing = facing.normalized()
	_material.set_shader_parameter("fog_color", fog_color)
	_material.set_shader_parameter("fog_opacity", fog_opacity)
	_material.set_shader_parameter("cone_origin", origin)
	_material.set_shader_parameter("facing_dir", facing)
	_material.set_shader_parameter("cone_angle", deg_to_rad(cone_angle_deg))
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("flat_cone", flat_cone)
