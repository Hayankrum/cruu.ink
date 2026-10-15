extends Control

const CITY_SCENE := "res://Scenes/City.tscn"
const NARRATIVA_SCENE := "res://Scenes/narrativa.tscn"
const PERFIS_PATH := "user://perfis.json"
const SESSAO_PATH := "user://sessao.json"

var _perfis: Array[Dictionary] = []
var _paineis: Array[Control] = []
var _perfil_atual: Dictionary = {}

@onready var btn_comecar: Button = $barra_btn/btn_começar
@onready var btn_detalhes: Button = $barra_btn/btn_detalhes
@onready var btn_placar: Button = $barra_btn/btn_placar
@onready var btn_sair: Button = $barra_btn/btn_sair

@onready var tela_login: Panel = $tela_login
@onready var input_nome: LineEdit = $tela_login/input_nome
@onready var erro_label: Label = $tela_login/erro_label
@onready var btn_saves: Button = $tela_login/HBox_login_btn/btn_saves
@onready var btn_entrar: Button = $tela_login/HBox_login_btn/btn_entrar

@onready var tela_save: Panel = $tela_save
@onready var lista_save: VBoxContainer = $tela_save/ScrollContainer/lista_save
@onready var btn_volta: Button = $tela_save/btn_volta

@onready var tela_narrativas: Panel = $tela_narrativas
@onready var lista_narrativas: VBoxContainer = $tela_narrativas/ScrollContainer/lista_narrativas
@onready var btn_trocar: Button = $tela_narrativas/btn_trocar

@onready var tela_detalhe: Panel = $tela_detalhe
@onready var txt_detalhe: RichTextLabel = $tela_detalhe/txt_detalhe

@onready var tela_placar: Panel = $tela_placar
@onready var txt_placa: RichTextLabel = $tela_placar/txt_placa

## Toque: arrastar o dedo sobre a lista rola o ScrollContainer.
## Sem isso o arrasto é engolido pelos botões da lista e nada anda no celular.
const SCROLL_INICIO := 18.0
const SCROLL_DIAGONAL := 1.35
var _scroll_gesto := false
var _scroll_pos := Vector2.ZERO
var _scroll_alvo: ScrollContainer = null

func _ready() -> void:
	_carregar_perfis()
	_restaurar_sessao()
	_preencher_placar()
	_sync_remoto()
	txt_detalhe.bbcode_enabled = true
	txt_placa.bbcode_enabled = true
	txt_detalhe.text = NarrativaManager.get_ui("detalhe", "")

	_paineis = [tela_login, tela_save, tela_narrativas, tela_detalhe, tela_placar]

	btn_comecar.pressed.connect(_comecar)
	btn_detalhes.pressed.connect(_alternar_detalhe)
	btn_placar.pressed.connect(_alternar_placar)
	btn_sair.pressed.connect(func() -> void: get_tree().quit())

	btn_entrar.pressed.connect(_entrar)
	btn_saves.pressed.connect(_abrir_saves)
	btn_volta.pressed.connect(_fechar_saves)
	btn_trocar.pressed.connect(_trocar_usuario)

	var fecha_det := get_node_or_null("tela_detalhe/btn_fecha_detalhe") as Button
	if fecha_det != null:
		fecha_det.pressed.connect(func() -> void: tela_detalhe.hide())
	var fecha_pla := get_node_or_null("tela_placar/btn_fecha_placar") as Button
	if fecha_pla != null:
		fecha_pla.pressed.connect(func() -> void: tela_placar.hide())

	for b in [btn_comecar, btn_detalhes, btn_placar, btn_entrar, btn_saves, btn_volta, btn_trocar]:
		b.pressed.connect(func() -> void: AudioManager.play("click"))
	if fecha_det != null:
		fecha_det.pressed.connect(func() -> void: AudioManager.play("click"))
	if fecha_pla != null:
		fecha_pla.pressed.connect(func() -> void: AudioManager.play("click"))

	_estilizar_login()
	_atualizar_botao_barra()
	btn_comecar.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_scroll_gesto = false
			_scroll_pos = st.position
			_scroll_alvo = _scroll_por_posicao(st.position)
		else:
			_scroll_alvo = null
	elif event is InputEventScreenDrag:
		if _scroll_alvo == null:
			return
		var sd := event as InputEventScreenDrag
		if not _scroll_gesto:
			if sd.position.distance_to(_scroll_pos) < SCROLL_INICIO:
				return
			if absf(sd.relative.y) * SCROLL_DIAGONAL <= absf(sd.relative.x):
				_scroll_alvo = null
				return
			_scroll_gesto = true
		_rolar(_scroll_alvo, -sd.relative.y)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_scroll_gesto = false

## Lista rolável sob o ponto tocado (seletor de narrativas e lista de perfis).
func _scroll_por_posicao(pos: Vector2) -> ScrollContainer:
	for painel: Control in [tela_narrativas, tela_save]:
		if painel == null or not painel.is_visible_in_tree():
			continue
		var sc := painel.get_node_or_null("ScrollContainer") as ScrollContainer
		if sc != null and sc.get_global_rect().has_point(pos):
			return sc
	return null

func _rolar(sc: ScrollContainer, delta: float) -> void:
	var barra := sc.get_v_scroll_bar()
	if barra == null:
		return
	var maximo := int(barra.max_value - barra.page)
	if maximo <= 0:
		return
	sc.scroll_vertical = clampi(sc.scroll_vertical + int(delta), 0, maximo)

## true quando o gesto atual foi um arrasto de rolagem (não um toque para abrir).
func _foi_rolagem() -> bool:
	return _scroll_gesto

func _estilizar_login() -> void:
	btn_entrar.add_theme_stylebox_override("normal", _accent_box(Color(1.0, 0.72, 0.2, 0.95)))
	btn_entrar.add_theme_stylebox_override("hover", _accent_box(Color(1.0, 0.82, 0.35, 1.0)))
	btn_entrar.add_theme_stylebox_override("pressed", _accent_box(Color(0.9, 0.6, 0.12, 1.0)))
	btn_entrar.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_entrar.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
	btn_entrar.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.01))
	btn_entrar.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.01))

func _accent_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color(1, 1, 0.85, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(10)
	box.shadow_color = Color(1, 0.72, 0.2, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 2)
	return box

func _trocar_painel(painel: Control) -> void:
	if painel.visible:
		painel.hide()
		return
	for p: Control in _paineis:
		p.hide()
	painel.show()

func _abrir_login() -> void:
	_trocar_painel(tela_login)
	if tela_login.visible:
		_mostrar_erro("")
		input_nome.grab_focus()

## Botão da barra: "LOGAR" (deslogado) / "INICIAR" (logado).
func _atualizar_botao_barra() -> void:
	btn_comecar.text = "INICIAR" if _logado() else "LOGAR"

## Toggle: deslogado abre/fecha o login; logado abre/fecha o seletor de narrativa.
func _comecar() -> void:
	if _logado():
		if tela_narrativas.visible:
			tela_narrativas.hide()
		else:
			_abrir_narrativas()
	else:
		if tela_login.visible:
			tela_login.hide()
		else:
			_abrir_login()

func _logado() -> bool:
	return not _perfil_atual.is_empty()

func _entrar() -> void:
	var nome := input_nome.text.strip_edges()
	if nome.is_empty():
		AudioManager.play("error")
		_mostrar_erro("Informe seu nome para continuar.")
		input_nome.grab_focus()
		return
	AudioManager.play("click")
	_perfil_atual = _perfil_para(nome)
	_salvar_perfis()
	_salvar_sessao(str(_perfil_atual.get("nome", "")))
	_atualizar_botao_barra()
	_abrir_narrativas()

func _perfil_para(nome: String) -> Dictionary:
	for p: Dictionary in _perfis:
		if (p.get("nome") as String).to_lower() == nome.to_lower():
			return p
	var novo := {"nome": nome, "pontos": 0, "ultima": 0}
	_perfis.append(novo)
	return novo

func _abrir_saves() -> void:
	if not tela_save.visible:
		_reconstruir_lista_saves()
	_trocar_painel(tela_save)

func _reconstruir_lista_saves() -> void:
	for child in lista_save.get_children():
		child.queue_free()
	for p: Dictionary in _perfis:
		var btn := Button.new()
		var nome := str(p.get("nome", "Perfil"))
		var data := Time.get_datetime_string_from_unix_time(int(p.get("ultima", 0)))
		btn.text = "■   %s   pontos: %d   último acesso: %s" % [nome, int(p.get("pontos", 0)), data]
		btn.custom_minimum_size = Vector2(0, 64)
		btn.pressed.connect(_continuar_perfil.bind(p))
		lista_save.add_child(btn)
	if _perfis.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhum perfil salvo. Volte e escolha seu nome."
		vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vazio.add_theme_font_size_override("font_size", 14)
		lista_save.add_child(vazio)

func _continuar_perfil(p: Dictionary) -> void:
	if _foi_rolagem():
		return
	_perfil_atual = p
	input_nome.text = str(p.get("nome", ""))
	_salvar_sessao(str(p.get("nome", "")))
	_atualizar_botao_barra()
	_abrir_narrativas()

func _fechar_saves() -> void:
	tela_save.hide()
	tela_login.show()
	btn_saves.grab_focus()

func _abrir_narrativas() -> void:
	_reconstruir_lista_narrativas()
	_trocar_painel(tela_narrativas)
	if tela_narrativas.visible:
		for c: Node in lista_narrativas.get_children():
			if c is Button and not c.is_queued_for_deletion():
				(c as Button).grab_focus()
				break

## "TROCAR DE USUÁRIO" no seletor: desloga e abre o login.
func _trocar_usuario() -> void:
	_perfil_atual = {}
	_salvar_sessao("")
	input_nome.text = ""
	_atualizar_botao_barra()
	_abrir_login()

func _reconstruir_lista_narrativas() -> void:
	for child in lista_narrativas.get_children():
		child.queue_free()
	var narrativas := NarrativaManager.lista()
	for n: Dictionary in narrativas:
		lista_narrativas.add_child(_criar_botao_narrativa(n))
	if narrativas.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhuma narrativa encontrada em Data/narrativas."
		vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vazio.add_theme_font_size_override("font_size", 14)
		lista_narrativas.add_child(vazio)

## Cartão da narrativa no seletor: capa (64x64) + título + subtítulo, tudo alinhado.
## Narrativa já concluída pelo perfil aparece desabilitada (não dá pra jogar de novo).
func _criar_botao_narrativa(n: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 88)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(_escolher_narrativa.bind(str(n.get("id", ""))))

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 14)
	margem.add_theme_constant_override("margin_right", 14)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_bottom", 12)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margem)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(hbox)

	var caminho_img := str(n.get("imagem", ""))
	if not caminho_img.is_empty() and ResourceLoader.exists(caminho_img):
		var capa := TextureRect.new()
		capa.texture = load(caminho_img)
		capa.custom_minimum_size = Vector2(64, 64)
		capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		capa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(capa)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coluna.add_theme_constant_override("separation", 2)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(coluna)

	var titulo := Label.new()
	titulo.text = str(n.get("titulo", n.get("id", "Narrativa")))
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.clip_text = true
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(titulo)

	var id := str(n.get("id", ""))
	var nota := PontosStore.nota_de(_perfil_atual, id)
	var concluida := nota >= 0
	var sub_texto := ""
	var sub_cor := Color(0.62, 0.7, 0.82)
	if concluida:
		sub_texto = "CONCLUÍDA ✓"
		var total := NarrativaManager.total_perguntas(id)
		if total > 0:
			sub_texto += "   %d/%d acertos" % [nota, total]
		sub_cor = Color(0.56, 0.88, 0.65)
	else:
		var intro: Variant = n.get("intro")
		if intro is Dictionary:
			sub_texto = str((intro as Dictionary).get("titulo", "")).strip_edges()

	var subtitulo: Label = null
	if not sub_texto.is_empty():
		subtitulo = Label.new()
		subtitulo.text = sub_texto
		subtitulo.add_theme_font_size_override("font_size", 12)
		subtitulo.add_theme_color_override("font_color", sub_cor)
		subtitulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subtitulo.clip_text = true
		subtitulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_child(subtitulo)

	if concluida:
		btn.disabled = true
		titulo.add_theme_color_override("font_disabled_color", Color(0.78, 0.82, 0.9, 0.75))
		if subtitulo != null:
			subtitulo.add_theme_color_override("font_disabled_color", sub_cor)
	return btn

func _escolher_narrativa(id: String) -> void:
	if _foi_rolagem():
		return
	AudioManager.play("click")
	if PontosStore.concluida(_perfil_atual, id):
		AudioManager.play("error")
		return
	NarrativaManager.carregar(id)
	_iniciar_jogo()

func _iniciar_jogo() -> void:
	if not _perfil_atual.is_empty():
		_perfil_atual["ultima"] = int(Time.get_unix_time_from_system())
		_salvar_perfis()
	var intro := NarrativaManager.get_intro()
	SceneTransition.titulo_narrativa = str(intro.get("titulo", ""))
	SceneTransition.texto_narrativa = str(intro.get("texto", ""))
	SceneTransition.proxima_cena = CITY_SCENE
	SceneTransition.change_scene(NARRATIVA_SCENE)

func _alternar_detalhe() -> void:
	_trocar_painel(tela_detalhe)
	if tela_detalhe.visible:
		txt_detalhe.scroll_to_line(0)

func _alternar_placar() -> void:
	_trocar_painel(tela_placar)
	if tela_placar.visible:
		_preencher_placar()
		txt_placa.scroll_to_line(0)

func _preencher_placar() -> void:
	if _perfis.is_empty():
		txt_placa.text = "[center]Nenhum perfil registrado ainda.\nCrie um perfil para aparecer no placar![/center]"
		return
	var ordem := _perfis.duplicate()
	ordem.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("pontos", 0)) > int(b.get("pontos", 0)))
	var narrativas := NarrativaManager.lista()
	var linhas := ["[center][font_size=22][color=#ffc83d]PLACAR LOCAL[/color][/font_size][/center]\n"]
	for i in range(ordem.size()):
		var p: Dictionary = ordem[i]
		var medalha: String = ["[color=#ffd75e]1º[/color]", "[color=#c0c8d8]2º[/color]", "[color=#d4a06a]3º[/color]"][i] if i < 3 else "%dº" % (i + 1)
		var nome := str(p.get("nome", "Perfil"))
		linhas.append("[b]%s  %s[/b]  —  [color=#ffc83d]%d[/color] pontos" % [medalha, nome, int(p.get("pontos", 0))])
		var feitas: Dictionary = {}
		if p.get("feitas") is Dictionary:
			feitas = p["feitas"] as Dictionary
		var vistos: Dictionary = {}
		for n: Dictionary in narrativas:
			var nid := str(n.get("id", ""))
			vistos[nid] = true
			linhas.append("     [color=#9fb4d4]%s[/color]   %s" % [str(n.get("titulo", nid)), _nota_placar(feitas.get(nid, -1), NarrativaManager.total_perguntas(nid))])
		for k: Variant in feitas:
			if not vistos.has(k):
				linhas.append("     [color=#9fb4d4]%s[/color]   %s" % [str(k), _nota_placar(feitas[k], 0)])
		linhas.append("")
	txt_placa.text = "\n".join(linhas)

## Nota de uma narrativa no placar: "8/10" ou "não jogada".
func _nota_placar(nota_v: Variant, total: int) -> String:
	var nota := int(nota_v)
	if nota < 0:
		return "[color=#7f8ba0]não jogada[/color]"
	if total > 0:
		return "[color=#8fe0a0][b]%d/%d[/b][/color]" % [nota, total]
	return "[color=#8fe0a0][b]%d[/b][/color]" % nota

func _mostrar_erro(msg: String) -> void:
	erro_label.text = msg

func _carregar_perfis() -> void:
	_perfis = []
	if not FileAccess.file_exists(PERFIS_PATH):
		return
	var f := FileAccess.open(PERFIS_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for item in data:
			if item is Dictionary:
				var d := item as Dictionary
				d.erase("avatar")
				_perfis.append(d)

func _salvar_perfis() -> void:
	var f := FileAccess.open(PERFIS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível salvar os perfis: " + PERFIS_PATH)
		return
	f.store_string(JSON.stringify(_perfis))
	SupabaseSync.subir_perfis(_perfis)

## Baixa perfis da nuvem e mescla com os locais (offline-safe: falha silenciosa).
func _sync_remoto() -> void:
	SupabaseSync.buscar_perfis(func(remotos: Array) -> void:
		if remotos.is_empty():
			return
		if _mesclar_perfis(remotos):
			_salvar_perfis()
			_preencher_placar()
	)

## Merge local <-> remoto. Pontos/último acesso: fica o maior. Novos nomes entram.
func _mesclar_perfis(remotos: Array) -> bool:
	var mudou := false
	for item: Variant in remotos:
		if not (item is Dictionary):
			continue
		var r := item as Dictionary
		var nome := str(r.get("nome", "")).strip_edges()
		if nome.is_empty():
			continue
		var local: Dictionary = {}
		for p: Dictionary in _perfis:
			if str(p.get("nome", "")).to_lower() == nome.to_lower():
				local = p
				break
		if local.is_empty():
			_perfis.append({
				"nome": nome,
				"pontos": int(r.get("pontos", 0)),
				"ultima": int(r.get("ultima", 0)),
			})
			mudou = true
			continue
		var pr := int(r.get("pontos", 0))
		var ult := int(r.get("ultima", 0))
		if pr > int(local.get("pontos", 0)):
			local["pontos"] = pr
			mudou = true
		if ult > int(local.get("ultima", 0)):
			local["ultima"] = ult
			mudou = true
	return mudou

## Sessão persistente (user://sessao.json): logado até "SAIR DA CONTA".
func _restaurar_sessao() -> void:
	var nome := _ler_sessao()
	if nome.is_empty():
		return
	_perfil_atual = _perfil_para(nome)
	_salvar_perfis()

func _ler_sessao() -> String:
	if not FileAccess.file_exists(SESSAO_PATH):
		return ""
	var f := FileAccess.open(SESSAO_PATH, FileAccess.READ)
	if f == null:
		return ""
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return str((data as Dictionary).get("nome", ""))
	return ""

func _salvar_sessao(nome: String) -> void:
	var f := FileAccess.open(SESSAO_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível salvar a sessão: " + SESSAO_PATH)
		return
	f.store_string(JSON.stringify({"nome": nome}))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var aberto: Control = null
		for p: Control in _paineis:
			if p.visible:
				aberto = p
				break
		if aberto != null:
			aberto.hide()
			if aberto == tela_save:
				tela_login.show()
		get_viewport().set_input_as_handled()
