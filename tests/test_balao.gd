extends SceneTree
## Smoke test do balão de diálogo ancorado na cabeça de quem fala.
##   godot --headless --path . -s res://tests/test_balao.gd

var _cena: Node
var _peds: Node
var _fase := 0
var _t := 0.0
var _falhas: Array[String] = []
var _pos_original := Vector2.ZERO
var _tam_original := Vector2.ZERO

func _check(cond: bool, label: String) -> void:
	if not cond:
		_falhas.append(label)
		print("FAIL: " + label)
	else:
		print("ok  : " + label)

## Simula a projeção da cabeça numa janela 1080x720 (a vertical não
## depende do aspecto: FOV vertical é fixa).
func _y_em_720(head_y: float, centro_y: float) -> float:
	return 360.0 + (head_y - centro_y) * (720.0 / 1080.0)

## A entrevista abre com o jogador falando; clica em "Avançar" até a
## fala do NPC, que é quem o balão representa.
func _avancar_ate_npc() -> void:
	if _peds == null:
		return
	var b1: Button = _peds._dialog_buttons[0]
	var n := 0
	while _peds.is_dialog_open() and _peds._falando_jogador and n < 12:
		b1.pressed.emit()
		_peds._atualizar_balao()
		n += 1
	_peds._atualizar_balao()

func _initialize() -> void:
	var s: PackedScene = load("res://Scenes/City.tscn")
	_cena = s.instantiate()
	root.add_child(_cena)

func _process(delta: float) -> bool:
	_t += delta
	match _fase:
		0:
			if _t < 0.6:
				return false
			_peds = _cena.get_node_or_null("Pedestrians")
			_check(_peds != null, "nó Pedestrians existe")
			if _peds == null:
				return true
			_check(_peds._dialog != null, "painel Panel_dialgo vinculado")
			_check(_peds._balao_rabo != null, "rabo do balão criado")
			_check(_peds._peds.size() > 0, "há pedestres spawnados")
			if _peds._dialog != null:
				_pos_original = _peds._dialog.position
				_tam_original = _peds._dialog.size
			if _peds._peds.size() > 0:
				_peds._peds[0]["disponivel"] = true
				_peds.open_dialog(_peds._peds[0])
			_fase = 1
			_t = 0.0
		1:
			if _t < 2.0:
				return false
			# A entrevista agora abre com o jogador (caixa do canto); o balão
			# só aparece quando chega a vez do NPC.
			_check(_peds._falando_jogador, "abertura é do jogador (caixa do canto)")
			_check(_peds._fala_panel != null and _peds._fala_panel.visible, "caixa do jogador visível na abertura")
			_avancar_ate_npc()
			_check(not _peds._falando_jogador, "avancou até a fala do NPC")
			var dlg: Control = _peds._dialog
			var cam: Camera3D = _peds._camera_rig.camera
			_check(dlg.visible, "balão visível com diálogo aberto")
			_check(cam != null, "câmera existe")
			if cam == null or not dlg.visible:
				_fase = 9
				return false
			var head: Vector3 = _peds._balao_alvo
			var sp := cam.unproject_position(head)
			var vp := cam.get_viewport().get_visible_rect().size
			var sz: Vector2 = dlg.size
			print("   head=", sp, " balão=", dlg.position, " size=", sz, " vp=", vp)
			var altura_esperada := clampf(26.0 + 24.0 + 6.0 + _peds._dialog_text.get_content_height(), 100.0, 320.0)
			_check(absf(sz.y - altura_esperada) < 1.0, "balão com altura do conteúdo (%.0f)" % sz.y)
			_check(sz.y < 320.0, "balão encolheu (menos que o teto de 320)")
			_check(sp.y > 0.0 and sp.y < vp.y, "cabeça projetada dentro da tela")
			_check(dlg.position.x >= 11.0, "balão colado na borda esquerda")
			_check(dlg.position.y >= 11.0, "balão colado na borda superior")
			_check(dlg.position.x + sz.x <= vp.x - 11.0, "balão não estoura a direita")
			_check(dlg.position.y + sz.y <= vp.y - 11.0, "balão não estoura a baixo")
			var x_livre := sp.x - sz.x * 0.5 >= 12.0 and sp.x + sz.x * 0.5 <= vp.x - 12.0
			if x_livre:
				_check(absf((dlg.position.x + sz.x * 0.5) - sp.x) < 3.0, "balão centralizado na cabeça (X)")
			_check(sp.y - sz.y - 14.0 >= 12.0, "cabeça em 1080x1080: balão cabe acima")
			_check(absf((dlg.position.y + sz.y) - (sp.y - 14.0)) < 3.0, "balão termina 14px acima da cabeça")
			_check(_peds._balao_rabo.visible, "rabo visível quando acima")
			_check(sp.y > vp.y * 0.5, "cabeça abaixo do centro (espaço em cima)")
			# caso real de janela 1080x720
			var y720 := _y_em_720(sp.y, vp.y * 0.5)
			print("   cabeça em 1080x720 =", y720, " -> topo do balão =", y720 - 14.0 - sz.y)
			_check(y720 - 14.0 - sz.y >= 12.0, "balão cabe acima da cabeça em 1080x720")
			# botão de avançar mora no btn1 do bloco de escolhas
			var b1: Button = _peds._dialog_buttons[0]
			_check(_peds._dialog_vbox.visible, "bloco de botões visível durante a fala")
			_check(_peds._dialog_vbox.get_parent() == dlg.get_parent(), "bloco de botões fora da caixa (irmã dela)")
			var vb: Control = _peds._dialog_vbox
			_check(vb.position.x + vb.size.x > vp.x * 0.5 and vb.position.y + vb.size.y > vp.y * 0.5, "bloco de botões no canto inferior direito da tela")
			_check(b1.visible and b1.text == "Avançar ▶", "btn1 vira Avançar")
			_check(not _peds._dialog_buttons[1].visible, "btn2 escondido durante a fala")
			_check(_peds._btn_avancar == null or not _peds._btn_avancar.visible, "▼ solto escondido")
			_check(_peds._dialog_vbox.alignment == VBoxContainer.ALIGNMENT_END, "Avançar colado no canto inferior direito")
			if _peds._dialog_typing:
				b1.pressed.emit()
				_check(not _peds._dialog_typing and _peds._dialog_text.visible_ratio >= 1.0, "Avançar conclui a digitação")
			var toques := 0
			while _peds._dialog_phase != "perguntas" and toques < 8:
				b1.pressed.emit()
				toques += 1
			_check(_peds._dialog_phase == "perguntas", "btn1 Avançar leva até as perguntas")
			_check(b1.text != "Avançar ▶" and b1.visible, "btn1 virou pergunta de verdade")
			_check(_peds._dialog_vbox.alignment == VBoxContainer.ALIGNMENT_END, "perguntas continuam no canto inferior direito")
			_fase = 2
			_t = 0.0
		2:
			if _t < 0.3:
				return false
			_peds.close_dialog()
			_check(not _peds._dialog.visible, "balão escondeu ao fechar")
			_check(_peds._dialog.position.distance_to(_pos_original) < 1.0, "posição original restaurada")
			_check(_peds._dialog.size.distance_to(_tam_original) < 1.0, "tamanho original restaurado")
			_check(not _peds._balao_rabo.visible, "rabo escondeu ao fechar")
			_fase = 3
			_t = 0.0
		3:
			if _t < 0.4:
				return false
			var trafico: Node = _cena.get_node_or_null("Traffic")
			_check(trafico != null and trafico._cars.size() > 0, "há carros no trânsito")
			if trafico != null and trafico._cars.size() > 0:
				var holder: Node3D = trafico._cars[0]["holder"]
				_peds.open_car_dialog(holder, "carro")
				_check(_peds.is_dialog_open(), "diálogo do carro abriu")
			_fase = 4
			_t = 0.0
		4:
			if _t < 2.0:
				return false
			var dlgc: Control = _peds._dialog
			var camc: Camera3D = _peds._camera_rig.camera
			if camc != null and dlgc.visible:
				var spc := camc.unproject_position(_peds._balao_alvo)
				var vpc := camc.get_viewport().get_visible_rect().size
				var szc: Vector2 = dlgc.size
				print("   carro head=", spc, " balão=", dlgc.position, " size=", szc)
				var altura_esperada_c := clampf(26.0 + 24.0 + 6.0 + _peds._dialog_text.get_content_height(), 100.0, 320.0)
				_check(absf(szc.y - altura_esperada_c) < 1.0, "balão do carro com altura do conteúdo (%.0f)" % szc.y)
				_check(_peds._dialog_vbox.visible and _peds._dialog_buttons[0].text == "Avançar ▶", "btn1 Avançar no diálogo do carro")
				_check(dlgc.position.y + szc.y <= spc.y + 1.0 or spc.y - szc.y - 14.0 < 12.0, "balão do carro não cobre o carro")
				_check(dlgc.position.y >= 11.0 and dlgc.position.y + szc.y <= vpc.y - 11.0, "balão do carro dentro da tela")
				var y720c := _y_em_720(spc.y, vpc.y * 0.5)
				_check(y720c - 14.0 - szc.y >= 12.0, "balão do carro cabe em 1080x720")
			else:
				_check(false, "balão do carro visível")
			_peds.close_dialog()
			_check(not _peds._dialog.visible, "balão do carro escondeu")
			_check(_peds._dialog.size.distance_to(_tam_original) < 1.0, "tamanho restaurado (carro)")
			_fase = 9
			_t = 0.0
		9:
			if _t < 0.2:
				return false
			if _falhas.is_empty():
				print("RESULTADO: TUDO OK")
			else:
				print("RESULTADO: %d falha(s)" % _falhas.size())
			return true
	return false
