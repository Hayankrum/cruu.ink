extends SceneTree
## Fluxo de "!": quem está disponível tem "!", quem foi entrevistado ou
## nasceu ocupado recusa a conversa (sem valer entrevista).
##   godot --headless --path . -s res://tests/test_fluxo.gd

var _falhas: Array[String] = []
var _cena: Node
var _peds: Node
var _fase := 0
var _t := 0.0
var _emits: Array[String] = []
var _alvo_ok: Dictionary = {}
var _alvo_ocupado: Dictionary = {}
var _disponiveis_antes := 0
var _alguem_icon := false
var _ocupado_visivel := false

func _check(cond: bool, label: String) -> void:
	if not cond:
		_falhas.append(label)
		print("FAIL: " + label)
	else:
		print("ok  : " + label)

func _disponiveis() -> int:
	var n := 0
	for ped: Dictionary in _peds._peds:
		if bool(ped.get("disponivel", false)):
			n += 1
	return n

func _process(delta: float) -> bool:
	_t += delta
	match _fase:
		0:
			if _t < 0.2:
				return false
			_cena = (load("res://Scenes/City.tscn") as PackedScene).instantiate()
			root.add_child(_cena)
			_peds = _cena.get_node_or_null("Pedestrians")
			_check(_peds != null, "Pedestrians existe")
			_peds.dialogo_concluido.connect(func(nome: String, _carro: bool) -> void: _emits.append(nome))
			_fase = 1
			_t = 0.0
		1:
			if _t < 1.0:
				return false
			_check(_peds._ui_entrevistas != null, "camada dos ! criada")
			_disponiveis_antes = _disponiveis()
			print("   disponíveis=", _disponiveis_antes, " de ", _peds._peds.size())
			_check(_disponiveis_antes > 0, "há NPCs disponíveis")
			_check(_disponiveis_antes < _peds._peds.size(), "há NPCs ocupados")
			_alguem_icon = false
			_ocupado_visivel = false
			for ped: Dictionary in _peds._peds:
				var lb: Label = ped.get("icon")
				if lb == null:
					continue
				_alguem_icon = true
				if not bool(ped.get("disponivel", false)) and lb.visible:
					_ocupado_visivel = true
				if bool(ped.get("disponivel", false)):
					if _alvo_ok.is_empty():
						_alvo_ok = ped
				elif _alvo_ocupado.is_empty():
					_alvo_ocupado = ped
			_check(_alguem_icon, "ícones criados sob demanda")
			_check(not _ocupado_visivel, "NPC ocupado nunca mostra !")
			_check(not _alvo_ok.is_empty() and not _alvo_ocupado.is_empty(), "achei um disponível e um ocupado")
			_fase = 2
			_t = 0.0
		2:
			if _t < 0.2:
				return false
			_peds.open_dialog(_alvo_ok)
			_check(_peds.is_dialog_open(), "disponível abre diálogo")
			_check(not _peds._dialog_ocupado, "disponível não é recusa")
			_check(_peds._dialog_phase == "apresentacao", "disponível começa a entrevista")
			_peds.close_dialog()
			_check(not bool(_alvo_ok.get("disponivel", true)), "entrevistado vira ocupado")
			_check(_emits.size() == 1, "entrevista contou no objetivo")
			_fase = 3
			_t = 0.0
		3:
			if _t < 0.2:
				return false
			_peds._update_icons()
			var lb: Label = _alvo_ok.get("icon")
			_check(lb == null or not lb.visible, "entrevistado perdeu o !")
			_check(_disponiveis() == _disponiveis_antes - 1, "sobrou um disponível a menos")
			_fase = 4
			_t = 0.0
		4:
			if _t < 0.2:
				return false
			_peds.open_dialog(_alvo_ocupado)
			_check(_peds.is_dialog_open(), "ocupado abre diálogo")
			_check(_peds._dialog_ocupado, "ocupado é recusa")
			_check(_peds._dialog_phase == "ocupado", "ocupado entra na fase de recusa")
			var b1: Button = _peds._dialog_buttons[0]
			_check(b1.visible and b1.text == "Avançar ▶", "recusa usa o Avançar")
			var toques := 0
			while _peds.is_dialog_open() and toques < 8:
				b1.pressed.emit()
				toques += 1
			_check(not _peds.is_dialog_open(), "recusa fecha sozinha")
			_check(_emits.size() == 1, "recusa NÃO contou como entrevista")
			_check(not bool(_alvo_ocupado.get("disponivel", true)), "ocupado continua ocupado")
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
