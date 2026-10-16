extends SceneTree
## Luz de preenchimento que ilumina quem fala em cena escura (City_noite) e não existe no dia.
##   godot --headless --path . -s res://tests/test_luz.gd

var _falhas: Array[String] = []
var _cena: Node
var _peds: Node
var _fase := 0
var _t := 0.0

func _check(cond: bool, label: String) -> void:
	if not cond:
		_falhas.append(label)
		print("FAIL: " + label)
	else:
		print("ok  : " + label)

func _carregar(caminho: String) -> Node:
	var cena: Node = (load(caminho) as PackedScene).instantiate()
	root.add_child(cena)
	_peds = cena.get_node_or_null("Pedestrians")
	return cena

## A entrevista abre com o jogador falando (balão escondido); clica em
## "Avançar" até a fala do NPC, quando o balão volta a aparecer.
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

func _process(delta: float) -> bool:
	_t += delta
	match _fase:
		0:
			if _t < 0.2:
				return false
			_cena = _carregar("res://Scenes/City_noite.tscn")
			_check(_peds != null, "noturno: Pedestrians existe")
			_fase = 1
			_t = 0.0
		1:
			if _t < 1.0:
				return false
			_check(_peds._luz_key_escuro, "noturno: ambiente detectado como escuro")
			_check(_peds._luz_key != null, "noturno: luz criada")
			if _peds._luz_key != null:
				_check(not _peds._luz_key.visible, "noturno: luz apagada sem diálogo")
				print("   luz energia=", _peds._luz_key.light_energy, " faixa=", _peds._luz_key.omni_range)
			if _peds._peds.size() > 0:
				_peds._peds[0]["disponivel"] = true
				_peds.open_dialog(_peds._peds[0])
			_check(_peds.is_dialog_open(), "noturno: diálogo aberto")
			_fase = 2
			_t = 0.0
		2:
			if _t < 1.5:
				return false
			var luz: OmniLight3D = _peds._luz_key
			var head: Vector3 = _peds._balao_alvo
			if luz == null:
				_check(false, "noturno: luz existe durante o diálogo")
			else:
				var d := luz.global_position.distance_to(head)
				print("   head=", head, " luz=", luz.global_position, " dist=", d)
				_check(luz.visible, "noturno: luz acesa com diálogo aberto")
				_check(d > 0.05 and d < 0.9, "noturno: luz fica perto da cabeça")
				_check(luz.global_position.y > head.y - 0.01, "noturno: luz acima da cabeça")
			_avancar_ate_npc()
			_check(_peds._dialog.visible, "noturno: balão visível")
			_peds.close_dialog()
			_fase = 3
			_t = 0.0
		3:
			if _t < 0.3:
				return false
			if _peds._luz_key != null:
				_check(not _peds._luz_key.visible, "noturno: luz apaga quando o balão fecha")
			_check(_peds.get("_icon") == null, "noturno: ícone ! removido")
			var trafico: Node = _cena.get_node_or_null("Traffic")
			_check(trafico != null and trafico._cars.size() > 0, "noturno: há carros")
			if trafico != null and trafico._cars.size() > 0:
				_peds.open_car_dialog(trafico._cars[0]["holder"], "carro")
			_check(_peds.is_dialog_open(), "noturno: diálogo do carro aberto")
			_fase = 4
			_t = 0.0
		4:
			if _t < 1.2:
				return false
			var lc: OmniLight3D = _peds._luz_key
			if lc == null or not _peds.is_dialog_open():
				_check(false, "noturno: diálogo do carro ativo")
			else:
				var dc := lc.global_position.distance_to(_peds._balao_alvo)
				print("   carro alvo=", _peds._balao_alvo, " luz=", lc.global_position, " dist=", dc)
				_check(lc.visible, "noturno: luz acesa no diálogo do carro")
				_check(dc < 0.9, "noturno: luz perto do carro")
			_peds.close_dialog()
			root.remove_child(_cena)
			_cena.free()
			_cena = null
			_peds = null
			_fase = 5
			_t = 0.0
		5:
			if _t < 0.3:
				return false
			_cena = _carregar("res://Scenes/City.tscn")
			_check(_peds != null, "dia: Pedestrians existe")
			_fase = 6
			_t = 0.0
		6:
			if _t < 1.0:
				return false
			_check(not _peds._luz_key_escuro, "dia: ambiente detectado como claro")
			_check(_peds._luz_key == null, "dia: nenhuma luz criada")
			root.remove_child(_cena)
			_cena.free()
			_cena = null
			_peds = null
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
