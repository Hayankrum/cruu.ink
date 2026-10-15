extends Node
## Autoload de sync local <-> Supabase (tabela perfis).
## Local-first: dados sempre salvos em user://; a nuvem é melhor-esforço —
## se internet cair, o jogo continua funcionando normalmente.

const CONFIG_PATH := "res://Data/sync_config.json"
const TABELA := "perfis"
const TIMEOUT := 6.0

var _url := ""
var _key := ""
var _pronto := false

func _ready() -> void:
	_carregar_config()

func _carregar_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("SupabaseSync: sem " + CONFIG_PATH + " — sync desativado.")
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_warning("SupabaseSync: sync_config.json inválido.")
		return
	var d := parsed as Dictionary
	_url = str(d.get("url", "")).strip_edges().trim_suffix("/")
	_key = str(d.get("key", "")).strip_edges()
	_pronto = not _url.is_empty() and not _key.is_empty()
	if not _pronto:
		push_warning("SupabaseSync: url/key ausentes no sync_config.json.")

func ativo() -> bool:
	return _pronto

func _headers_extra(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var base := PackedStringArray(["apikey: " + _key, "Authorization: Bearer " + _key])
	for h in extra:
		base.append(h)
	return base

## Baixa todos os perfis remotos. Chama callback(Array[Dictionary]) — sempre
## retorna algo (lista vazia se offline/erro), nunca bloqueia a UI.
func buscar_perfis(callback: Callable) -> void:
	if not _pronto:
		_chamar(callback, [])
		return
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		var lista: Array = []
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				lista = parsed
		req.queue_free()
		_chamar(callback, lista)
	)
	var err := req.request(_url + "/rest/v1/" + TABELA + "?select=*", _headers_extra())
	if err != OK:
		req.queue_free()
		_chamar(callback, [])

## Chama o callback só se o dono (self capturado pelo lambda) ainda existir.
func _chamar(callback: Callable, lista: Array) -> void:
	if callback.is_valid():
		callback.call(lista)

## Upsert de um perfil (merge por nome). Fire-and-forget.
func subir_perfil(p: Dictionary) -> void:
	var nome := str(p.get("nome", ""))
	if not _pronto or nome.is_empty():
		return
	_enviar(JSON.stringify({
		"nome": nome,
		"pontos": int(p.get("pontos", 0)),
		"ultima": int(p.get("ultima", 0)),
	}), HTTPClient.METHOD_POST)

## Upsert de vários perfis de uma vez.
func subir_perfis(lista: Array) -> void:
	if not _pronto or lista.is_empty():
		return
	var limpo: Array = []
	for item in lista:
		if item is Dictionary:
			var d := item as Dictionary
			var nome := str(d.get("nome", ""))
			if not nome.is_empty():
				limpo.append({
					"nome": nome,
					"pontos": int(d.get("pontos", 0)),
					"ultima": int(d.get("ultima", 0)),
				})
	if limpo.is_empty():
		return
	_enviar(JSON.stringify(limpo), HTTPClient.METHOD_POST)

func _enviar(payload: String, metodo: int) -> void:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	req.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
	)
	var err := req.request(
		_url + "/rest/v1/" + TABELA,
		_headers_extra(PackedStringArray([
			"Content-Type: application/json",
			"Prefer: resolution=merge-duplicates,return=minimal",
		])),
		metodo, payload)
	if err != OK:
		req.queue_free()
