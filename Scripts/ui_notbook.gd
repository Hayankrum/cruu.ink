extends Panel
# Quiz em duas partes:
#  - O CONTEUDO (enunciado da questao) e desenhado NA TELA do notebook, via o
#    SubViewport Tela/Desktop/cquestion que vira a textura da tela.
#  - Os BOTOES de escolha ficam no painel branco do canto inferior direito
#    (mesmo estilo dos botoes de dialogo da cidade).

const MENU_SCENE := "res://Scenes/menu_inicial.tscn"
const NARRATIVA_SCENE := "res://Scenes/narrativa.tscn"

## Cores de feedback sobre botão branco (mais escuras que no vidro escuro).
const C_GREEN := Color(0.13, 0.55, 0.28)
const C_RED := Color(0.78, 0.18, 0.18)

const FONTE_TELA := 32
const FONTE_TELA_MIN := 14
## Distância das bordas do viewport (igual aos demais painéis da HUD).
const PAINEL_MARGEM := 24.0
## Folga interna em volta do conteúdo dos botões.
const PAINEL_PADDING := 14.0
const PAINEL_ALTURA_MIN := 120.0

@onready var _box: VBoxContainer = $VBoxContainer/box_btn

var _stage: Node
var _btns: Array[Button] = []
var _cquestion: RichTextLabel
var _q := 0
var _score := 0
var _answered := false
var _btn_submeter: Button
var _btn_finalizar: Button

var _quiz: Dictionary = {}
var _perguntas: Array = []
var _nota_aprovacao := 0.7
var _textos: Dictionary = {}

func _ready() -> void:
	_quiz = NarrativaManager.get_quiz()
	_perguntas = _quiz.get("perguntas", []) if _quiz.get("perguntas") is Array else []
	_nota_aprovacao = float(_quiz.get("nota_aprovacao", 0.7))
	_textos = _quiz.get("textos", {}) if _quiz.get("textos") is Dictionary else {}
	var idx := 0
	for child in _box.get_children():
		if child is Button:
			var b: Button = child
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.pressed.connect(_on_option.bind(idx))
			_btns.append(b)
			idx += 1
	_btn_submeter = _criar_botao_acao(_texto("enviar", "Enviar respostas"), _on_submeter)
	_btn_finalizar = _criar_botao_acao(_texto("finalizar", "Finalizar"), _on_finalizar)
	var s := _get_stage()
	if s != null:
		var desk := s.get_node_or_null("StageViewport/Tela/Desktop")
		if desk == null:
			desk = s.get_node_or_null("Tela/Desktop")
		if desk != null:
			_cquestion = desk.get_node_or_null("cquestion")
			if _cquestion != null:
				_cquestion.bbcode_enabled = true
				_cquestion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_cquestion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ajustar_painel()
	_start()

func _texto(chave: String, padrao: String) -> String:
	return str(_textos.get(chave, padrao))

## Ancora o painel no canto inferior direito e o redimensiona para caber
## nos botões (texto longo => botão mais alto => painel mais alto).
func _ajustar_painel() -> void:
	var vb := _box.get_parent() as Container
	if vb == null:
		return
	var min_sz: Vector2 = vb.get_combined_minimum_size()
	var h := maxf(min_sz.y + PAINEL_PADDING * 2.0, PAINEL_ALTURA_MIN)
	var w := maxf(min_sz.x + PAINEL_PADDING * 2.0, 268.0)
	offset_left = -(w + PAINEL_MARGEM)
	offset_top = -(h + PAINEL_MARGEM)
	offset_right = -PAINEL_MARGEM
	offset_bottom = -PAINEL_MARGEM

func _get_stage() -> Node:
	if _stage == null:
		_stage = get_tree().get_first_node_in_group("notebook_stage")
	return _stage

func _set_tela(text_bb: String) -> void:
	if _cquestion == null:
		return
	_cquestion.text = text_bb
	_cquestion.add_theme_font_size_override("normal_font_size", FONTE_TELA)
	var fs := FONTE_TELA
	while fs > FONTE_TELA_MIN and _cquestion.get_content_height() > _cquestion.size.y:
		fs -= 2
		_cquestion.add_theme_font_size_override("normal_font_size", fs)

func _start() -> void:
	_q = 0
	_score = 0
	_answered = false
	_show()

func _show() -> void:
	if _q >= _perguntas.size():
		_finish()
		return
	var data: Dictionary = _perguntas[_q]
	_set_tela("[center]%s[/center]" % data["text"])
	for i in _btns.size():
		if i < data["options"].size():
			_btns[i].visible = true
			_btns[i].text = str(data["options"][i])
			_btns[i].disabled = false
			_btns[i].remove_theme_color_override("font_color")
			_btns[i].remove_theme_color_override("font_disabled_color")
		else:
			_btns[i].visible = false
	_ajustar_painel()

func _on_option(i: int) -> void:
	if _answered:
		return
	_answered = true
	var data: Dictionary = _perguntas[_q]
	var is_correct: bool = i == data["correct"]
	if is_correct:
		_score += 1
		AudioManager.play("correct")
	else:
		AudioManager.play("wrong")
	for j in _btns.size():
		_btns[j].disabled = true
		if j == data["correct"]:
			_btns[j].add_theme_color_override("font_color", C_GREEN)
			_btns[j].add_theme_color_override("font_disabled_color", C_GREEN)
		elif j == i:
			_btns[j].add_theme_color_override("font_color", C_RED)
			_btns[j].add_theme_color_override("font_disabled_color", C_RED)
	var correta_tpl := _texto("correta", "[center]{text}[/center]\n[center][color=#8fe0a0]Correta: {opcao}[/color][/center]")
	var correta := correta_tpl.replace("{text}", str(data["text"])).replace("{opcao}", str(data["options"][data["correct"]]))
	_set_tela(correta)
	await get_tree().create_timer(1.2).timeout
	_answered = false
	_q += 1
	_show()

func _criar_botao_acao(texto: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(240, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.visible = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(callback)
	_box.add_child(b)
	return b

func _finish() -> void:
	AudioManager.play("chime")
	var tpl := _texto("fim", "[center]Fim do quiz![/center]\n[center][color=#8fe0a0]Acertos: {score}/{total}[/color][/center]\n[center][color=#9fb4d4]Envie suas respostas.[/color][/center]")
	_set_tela(tpl.replace("{score}", str(_score)).replace("{total}", str(_perguntas.size())))
	for b in _btns:
		b.visible = false
	_btn_finalizar.visible = false
	_btn_finalizar.disabled = true
	_btn_submeter.visible = true
	_ajustar_painel()

func _on_submeter() -> void:
	_btn_submeter.visible = false
	var aprovado := _score >= ceili(_perguntas.size() * _nota_aprovacao)
	if aprovado:
		AudioManager.play("chime")
		var tpl := _texto("aprovado", "[center][color=#8fe0a0][font_size=42][b]✔[/b][/font_size][/color][/center]\n[center][color=#8fe0a0][b]APROVADO[/b][/color][/center]\n[center][color=#9fb4d4]{score}/{total} acertos[/color][/center]")
		_set_tela(tpl.replace("{score}", str(_score)).replace("{total}", str(_perguntas.size())))
	else:
		AudioManager.play("wrong")
		var tpl := _texto("reprovado", "[center][color=#e06060][font_size=42][b]✘[/b][/font_size][/color][/center]\n[center][color=#e06060][b]REPROVADO[/b][/color][/center]\n[center][color=#9fb4d4]{score}/{total} acertos[/color][/center]")
		_set_tela(tpl.replace("{score}", str(_score)).replace("{total}", str(_perguntas.size())))
	_btn_finalizar.visible = true
	_btn_finalizar.disabled = true
	_ajustar_painel()
	await get_tree().create_timer(0.8).timeout
	_btn_finalizar.disabled = false
	_btn_finalizar.grab_focus()

func _on_finalizar() -> void:
	AudioManager.play("click")
	_registrar_pontos()
	var outro := NarrativaManager.get_outro()
	SceneTransition.titulo_narrativa = str(outro.get("titulo", ""))
	SceneTransition.texto_narrativa = str(outro.get("texto", ""))
	SceneTransition.proxima_cena = MENU_SCENE
	SceneTransition.change_scene(NARRATIVA_SCENE)

## Regra "maior nota vence": registra acertos no perfil da sessão e sobe pra nuvem.
func _registrar_pontos() -> void:
	var nome := PontosStore.sessao_nome()
	if nome.is_empty():
		return
	var atualizado := PontosStore.registrar_pontos(nome, NarrativaManager.atual_id(), _score)
	if not atualizado.is_empty():
		SupabaseSync.subir_perfil(atualizado)
