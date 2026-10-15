extends Node
## Autoload que descarrega e gerencia as narrativas data-driven (JSON).
## Cada narrativa é um arquivo único em res://Data/narrativas/*.json.

const DIR := "res://Data/narrativas"
const UI_PATH := "res://Data/ui.json"

var _narrativas: Array[Dictionary] = []
var _atual: Dictionary = {}
var _ui: Dictionary = {}

func _ready() -> void:
	_escanear()
	_carregar_ui()
	if not _narrativas.is_empty() and _atual.is_empty():
		carregar(str(_narrativas[0].get("id", "")))

func _escanear() -> void:
	_narrativas = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("NarrativaManager: pasta nao encontrada: " + DIR)
		return
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		if not dir.current_is_dir() and nome.ends_with(".json"):
			var caminho := DIR.path_join(nome)
			var dados: Variant = _ler_json(caminho)
			if dados is Dictionary and not (dados as Dictionary).is_empty():
				var d := dados as Dictionary
				if not d.has("id"):
					d["id"] = nome.get_basename()
				d["_caminho"] = caminho
				_narrativas.append(d)
		nome = dir.get_next()
	dir.list_dir_end()
	_narrativas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))

func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		push_warning("NarrativaManager: arquivo nao encontrado: " + caminho)
		return null
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		push_warning("NarrativaManager: falha ao abrir: " + caminho)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed

func _carregar_ui() -> void:
	var dados: Variant = _ler_json(UI_PATH)
	_ui = dados if dados is Dictionary else {}

func lista() -> Array[Dictionary]:
	return _narrativas

func carregar(id: String) -> void:
	for n: Dictionary in _narrativas:
		if str(n.get("id", "")) == id:
			_atual = n
			return
	push_warning("NarrativaManager: narrativa nao encontrada: " + id)

func atual() -> Dictionary:
	if _atual.is_empty() and not _narrativas.is_empty():
		_atual = _narrativas[0]
	return _atual

func atual_id() -> String:
	return str(atual().get("id", ""))

## Nº de perguntas do quiz de uma narrativa (0 se não tiver).
func total_perguntas(id: String) -> int:
	for n: Dictionary in _narrativas:
		if str(n.get("id", "")) != id:
			continue
		var quiz: Variant = n.get("quiz")
		if quiz is Dictionary and (quiz as Dictionary).get("perguntas") is Array:
			return ((quiz as Dictionary).get("perguntas") as Array).size()
	return 0

func get_intro() -> Dictionary:
	return _secao("intro")

func get_outro() -> Dictionary:
	return _secao("outro")

## Cartão narrativo mostrado ao clicar em NOTEBOOK (antes da cena do notebook).
func get_transicao_notebook() -> Dictionary:
	return _secao("transicao_notebook")

func get_objetivo() -> Dictionary:
	return _secao("objetivo")

func get_quiz() -> Dictionary:
	return _secao("quiz")

func get_dialogos() -> Dictionary:
	return _secao("dialogos")

func get_ui(chave: String, padrao: String = "") -> String:
	var v: Variant = _ui.get(chave, padrao)
	return str(v)

func _secao(chave: String) -> Dictionary:
	var d: Variant = atual().get(chave)
	return d if d is Dictionary else {}
