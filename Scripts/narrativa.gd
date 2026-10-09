extends Control
## Tela de narrativa: fundo sólido + texto datilografado.
## Preencha SceneTransition.titulo_narrativa / texto_narrativa / proxima_cena
## antes de change_scene para esta cena.

const VELOCIDADE := 45.0
const MENU_SCENE := "res://Scenes/menu_inicial.tscn"

@onready var _titulo: Label = $Margem/VBox/Titulo
@onready var _texto: RichTextLabel = $Margem/VBox/Texto
@onready var _pular: Label = $Margem/VBox/Pular
@onready var _btn: Button = $Margem/VBox/Btn

var _total := 0
var _completo := false
var _tw: Tween
var _blip_acc := 0

func _ready() -> void:
	_titulo.text = SceneTransition.titulo_narrativa
	_texto.text = SceneTransition.texto_narrativa
	if _texto.text.is_empty():
		_texto.text = "Texto da narrativa."
	var proxima := SceneTransition.proxima_cena
	if proxima.is_empty():
		proxima = MENU_SCENE
	_btn.visible = false
	_btn.pressed.connect(func() -> void:
		AudioManager.play("click")
		SceneTransition.change_scene(proxima))
	_estilizar_btn()
	await get_tree().create_timer(0.4).timeout
	_total = _texto.get_total_character_count()
	_texto.visible_characters = 0
	_pular.visible = true
	if _total <= 0:
		_completar()
		return
	_tw = create_tween()
	_tw.tween_method(_set_chars, 0, _total, float(_total) / VELOCIDADE)
	_tw.tween_callback(_completar)

func _set_chars(n: int) -> void:
	_texto.visible_characters = n
	_blip_acc += 1
	if _blip_acc >= 4:
		_blip_acc = 0
		AudioManager.play("blip", -18.0)

func _completar() -> void:
	if _completo:
		return
	_completo = true
	AudioManager.play("chime", -8.0)
	_texto.visible_characters = -1
	_pular.visible = false
	_btn.visible = true
	_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _completo:
		return
	if not _quer_pular(event):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_completar()
	get_viewport().set_input_as_handled()

## Aceita espaço/enter, clique do mouse e toque na tela.
func _quer_pular(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)
	return false

func _estilizar_btn() -> void:
	_btn.add_theme_font_size_override("font_size", 16)
	_btn.add_theme_stylebox_override("normal", _caixa(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.22)))
	_btn.add_theme_stylebox_override("hover", _caixa(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.4)))
	_btn.add_theme_stylebox_override("pressed", _caixa(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.3)))
	_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_btn.add_theme_color_override("font_color", Color(0.93, 0.95, 1, 0.85))
	_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_btn.add_theme_color_override("font_pressed_color", Color(0.93, 0.95, 1, 0.7))

func _caixa(bg: Color, borda: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = borda
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	return box
