extends "res://Scripts/glass_panel.gd"
## Painel de objetivos: acompanha as entrevistas com os cidadaos e o
## motorista do carro, atualizando a barra de progresso e a historinha.
## Quando tudo e cumprido, revela o btn_im para ir ao notebook.


const NOTEBOOK_SCENE := "res://Scenes/CityNotebook.tscn"

@export var pedestrians_path: NodePath = NodePath("../../Pedestrians")
@export_range(1, 12, 1) var npcs_necessarios := 3
@export var precisa_falar_com_carro := true
## true na CityNotebook: abre/fecha overlay local em vez de change_scene.
@export var open_as_overlay := false
@export var notebook_overlay_path: NodePath = NodePath("../../NotebookOverlay/NotebookWindow")

@onready var _barra: ProgressBar = $ProgressBar
@onready var _label: RichTextLabel = $objetivo
@onready var _btn_im: Button = $btn_im

var _entrevistados: Dictionary = {}
var _carro_entrevistado := false
var _concluido := false
var _cfg: Dictionary = {}


func _ready() -> void:
	super()
	_cfg = NarrativaManager.get_objetivo()
	if _cfg.has("npcs_necessarios"):
		npcs_necessarios = int(_cfg.get("npcs_necessarios", npcs_necessarios))
	if _cfg.has("precisa_falar_com_carro"):
		precisa_falar_com_carro = bool(_cfg.get("precisa_falar_com_carro", precisa_falar_com_carro))
	_label.bbcode_enabled = true
	_btn_im.visible = false
	_btn_im.add_theme_stylebox_override("normal", _accent_box(Color(1.0, 0.72, 0.2, 0.95)))
	_btn_im.add_theme_stylebox_override("hover", _accent_box(Color(1.0, 0.82, 0.35, 1.0)))
	_btn_im.add_theme_stylebox_override("pressed", _accent_box(Color(0.9, 0.6, 0.12, 1.0)))
	_btn_im.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_btn_im.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
	_btn_im.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.01))
	_btn_im.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.01))
	_btn_im.add_theme_font_size_override("font_size", 12)
	_btn_im.pressed.connect(_ir_para_notebook)
	var peds: Node = get_node_or_null(pedestrians_path)
	if peds != null:
		peds.dialogo_concluido.connect(_ao_concluir_dialogo)
	_atualizar()


func _accent_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color(1, 1, 0.85, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(8)
	box.shadow_color = Color(1, 0.72, 0.2, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 2)
	return box


func _ao_concluir_dialogo(nome_npc: String, e_carro: bool) -> void:
	if _concluido:
		return
	if e_carro:
		_carro_entrevistado = true
	elif not nome_npc.is_empty():
		_entrevistados[nome_npc] = true
	_atualizar()


func _etapas_faltantes() -> int:
	var faltam := maxi(npcs_necessarios - _entrevistados.size(), 0)
	if precisa_falar_com_carro and not _carro_entrevistado:
		faltam += 1
	return faltam


func _atualizar() -> void:
	var faltam := _etapas_faltantes()
	var total := npcs_necessarios + (1 if precisa_falar_com_carro else 0)
	var concluidas := maxi(total - faltam, 0)
	var antes := _barra.value
	_barra.max_value = maxf(total, 1.0)
	_barra.value = concluidas
	_label.text = _texto_objetivo()
	if faltam == 0 and not _concluido:
		_concluido = true
		AudioManager.play("chime")
		_label.text = _texto_concluido()
		_btn_im.visible = true
	elif concluidas > antes:
		AudioManager.play("blip")


func _texto_objetivo() -> String:
	var linhas: Array[String] = []
	var tpl_aberto := str(_cfg.get("texto_aberto", "[color=#ffc83d][b]CASO ABERTO[/b][/color]\n[color=#8b9bb8]Entrevistas[/color]  [color=#8fe0a0][b]{feitas}/{total}[/b][/color]"))
	var tpl_completo := str(_cfg.get("texto_aberto_completo", "[color=#ffc83d][b]CASO ABERTO[/b][/color]\n[color=#8b9bb8]Entrevistas[/color]  [color=#8fe0a0][b]completo[/b][/color]"))
	var tpl_carro_pend := str(_cfg.get("texto_carro_pendente", "[color=#8b9bb8]Fale com[/color]  [color=#4cc2ff][b]o motorista[/b][/color]"))
	var tpl_carro_ok := str(_cfg.get("texto_carro_ok", "[color=#8b9bb8]Motorista[/color]  [color=#8fe0a0][b]ouvido[/b][/color]"))
	if _entrevistados.size() < npcs_necessarios:
		linhas.append(tpl_aberto.replace("{feitas}", str(_entrevistados.size())).replace("{total}", str(npcs_necessarios)))
	else:
		linhas.append(tpl_completo)
	if precisa_falar_com_carro:
		linhas.append(tpl_carro_ok if _carro_entrevistado else tpl_carro_pend)
	return "\n".join(linhas)


func _texto_concluido() -> String:
	return str(_cfg.get("texto_concluido", "[color=#8fe0a0][b]Caso fechado![/b][/color]\n[color=#9fb4d4]Abra o notebook.[/color]"))


func _ir_para_notebook() -> void:
	AudioManager.play("click")
	if open_as_overlay:
		var ov := get_node_or_null(notebook_overlay_path)
		if ov != null and ov.has_method("toggle"):
			ov.call("toggle")
		return
	SceneTransition.change_scene(NOTEBOOK_SCENE)
