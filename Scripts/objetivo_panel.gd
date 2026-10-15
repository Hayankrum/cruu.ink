extends "res://Scripts/glass_panel.gd"
## Painel de objetivos: acompanha as entrevistas com os cidadaos e o
## motorista do carro, atualizando a barra de progresso e a historinha.
## Quando tudo e cumprido, revela o btn_im para ir ao notebook.


const NOTEBOOK_SCENE := "res://Scenes/CityNotebook.tscn"
const NOTEBOOK_SCENE_NOITE := "res://Scenes/CityNotebook_noite.tscn"

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
	_btn_im.add_theme_stylebox_override("normal", _caixa_branca(Color(1, 1, 1, 1), Color(0.8, 0.82, 0.86, 1)))
	_btn_im.add_theme_stylebox_override("hover", _caixa_branca(Color(0.95, 0.96, 0.97, 1), Color(0.62, 0.65, 0.7, 1)))
	_btn_im.add_theme_stylebox_override("pressed", _caixa_branca(Color(0.87, 0.89, 0.92, 1), Color(0.5, 0.53, 0.58, 1), 4))
	_btn_im.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_btn_im.add_theme_color_override("font_color", Color(0.09, 0.1, 0.12, 1))
	_btn_im.add_theme_color_override("font_hover_color", Color(0.02, 0.03, 0.04, 1))
	_btn_im.add_theme_color_override("font_pressed_color", Color(0.25, 0.27, 0.31, 1))
	_btn_im.add_theme_font_size_override("font_size", 11)
	_btn_im.pressed.connect(_ir_para_notebook)
	var peds: Node = get_node_or_null(pedestrians_path)
	if peds != null:
		peds.dialogo_concluido.connect(_ao_concluir_dialogo)
	_atualizar()


func _caixa_branca(bg: Color, borda: Color, margem := 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = borda
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(margem)
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
	_ajustar_altura()


func _texto_objetivo() -> String:
	var titulo := str(_cfg.get("texto_aberto", "[color=#15181d][b]CASO ABERTO[/b][/color]"))
	var conta := str(_cfg.get("texto_conta", "{feitas}/{total}")) \
		.replace("{feitas}", str(_entrevistados.size())) \
		.replace("{total}", str(npcs_necessarios))
	if _entrevistados.size() >= npcs_necessarios:
		titulo = str(_cfg.get("texto_aberto_completo", titulo))
		conta = str(_cfg.get("texto_conta_completa", "completo"))
	var segunda := "[color=#15181d][b]%s[/b][/color]" % conta
	if precisa_falar_com_carro:
		var carro := str(_cfg.get("texto_carro_ok" if _carro_entrevistado else "texto_carro_pendente", ""))
		if carro.is_empty():
			carro = "[color=#6b7280]Motorista ouvido[/color]" if _carro_entrevistado else "[color=#6b7280]Fale com o motorista[/color]"
		segunda += "   " + carro
	return titulo + "\n" + segunda


func _texto_concluido() -> String:
	return str(_cfg.get("texto_concluido", "[color=#15181d][b]Investigação concluída![/b][/color]\n[color=#6b7280]Abra o notebook.[/color]"))


func _ajustar_altura() -> void:
	if _label == null:
		return
	var conteudo := _label.get_combined_minimum_size().y
	var alvo := maxf(96.0, conteudo + 56.0)
	if absf(size.y - alvo) > 0.5:
		size.y = alvo


func _ir_para_notebook() -> void:
	AudioManager.play("click")
	if open_as_overlay:
		var ov := get_node_or_null(notebook_overlay_path)
		if ov != null and ov.has_method("toggle"):
			ov.call("toggle")
		return
	var cena_atual := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	# City_noite usa o notebook noturno; o resto mantém o de dia.
	var destino := NOTEBOOK_SCENE_NOITE if "City_noite" in cena_atual else NOTEBOOK_SCENE
	SceneTransition.change_scene(destino)
