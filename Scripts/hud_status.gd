extends Label

const PERFIS_PATH := "user://perfis.json"
const SESSAO_PATH := "user://sessao.json"

func _ready() -> void:
	var nome := _sessao_atual()
	if nome.is_empty():
		nome = _ultimo_perfil()
	if not nome.is_empty():
		text = "◆  " + nome

## Usuário logado na sessão persistente (user://sessao.json).
func _sessao_atual() -> String:
	if not FileAccess.file_exists(SESSAO_PATH):
		return ""
	var file := FileAccess.open(SESSAO_PATH, FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		var nome := str((data as Dictionary).get("nome", ""))
		if not nome.is_empty():
			return nome
	return ""

## Fallback: perfil com o último acesso mais recente.
func _ultimo_perfil() -> String:
	if not FileAccess.file_exists(PERFIS_PATH):
		return ""
	var file := FileAccess.open(PERFIS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Array):
		return ""
	var melhor: Dictionary = {}
	var melhor_t := -1
	for item: Variant in data:
		if not (item is Dictionary):
			continue
		var t := int((item as Dictionary).get("ultima", 0))
		if t > melhor_t:
			melhor_t = t
			melhor = item as Dictionary
	return str(melhor.get("nome", ""))
