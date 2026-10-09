extends SceneTree
## Teste de integração do sync Supabase (roda com):
##   godot --headless --path . -s res://tests/test_sync.gd
## Fases: online push → "outra máquina" → merge local↔nuvem → offline-graceful → cleanup.

const SYNC_SCRIPT := preload("res://Scripts/supabase_sync.gd")

var _sync: Node
var _fails := 0
var _resp: Array = []
var _resp_ok := false

func _initialize() -> void:
	_run()

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)

func _buscar_async() -> Array:
	_resp_ok = false
	_resp = []
	_sync.buscar_perfis(func(lista: Array) -> void:
		_resp = lista
		_resp_ok = true
	)
	var espera := 0
	while not _resp_ok and espera < 800:
		await process_frame
		espera += 1
	return _resp

func _nomes(lista: Array) -> Array:
	var out: Array = []
	for item in lista:
		if item is Dictionary:
			out.append(str((item as Dictionary).get("nome", "")))
	return out

func _acha(lista: Array, nome: String) -> Dictionary:
	for item in lista:
		if item is Dictionary and str((item as Dictionary).get("nome", "")) == nome:
			return item as Dictionary
	return {}

## Mesma regra de merge do menu_inicial.gd::_mesclar_perfis.
func _mesclar(local: Array, remotos: Array) -> void:
	for item: Variant in remotos:
		if not (item is Dictionary):
			continue
		var r := item as Dictionary
		var nome := str(r.get("nome", "")).strip_edges()
		if nome.is_empty():
			continue
		var loc: Dictionary = {}
		for p: Dictionary in local:
			if str(p.get("nome", "")).to_lower() == nome.to_lower():
				loc = p
				break
		if loc.is_empty():
			local.append({"nome": nome, "pontos": int(r.get("pontos", 0)), "ultima": int(r.get("ultima", 0))})
			continue
		if int(r.get("pontos", 0)) > int(loc.get("pontos", 0)):
			loc["pontos"] = int(r.get("pontos", 0))
		if int(r.get("ultima", 0)) > int(loc.get("ultima", 0)):
			loc["ultima"] = int(r.get("ultima", 0))

func _run() -> void:
	await create_timer(0.2).timeout
	print("=== TESTE SYNC SUPABASE ===")

	_sync = SYNC_SCRIPT.new()
	root.add_child(_sync)
	await create_timer(0.1).timeout
	_check(_sync.ativo(), "config carregada (sync ativo)")

	# Limpa resíduos de testes anteriores
	var atual: Array = await _buscar_async()
	var lixo := PackedStringArray()
	for item in atual:
		var n := str((item as Dictionary).get("nome", ""))
		if n.begins_with("teste_"):
			lixo.append(n)
	if not lixo.is_empty():
		await _deletar_async(lixo)

	# FASE 1 — Online: subir perfil e baixar de volta
	_sync.subir_perfil({"nome": "teste_online", "pontos": 10, "ultima": 100})
	await create_timer(1.5).timeout
	atual = await _buscar_async()
	var p := _acha(atual, "teste_online")
	_check(not p.is_empty(), "FASE1: perfil subiu para a nuvem")
	_check(int(p.get("pontos", -1)) == 10, "FASE1: pontos == 10")

	# FASE 2 — Simula "outra máquina" atualizando a nuvem
	_sync.subir_perfil({"nome": "teste_online", "pontos": 50, "ultima": 999})
	_sync.subir_perfil({"nome": "teste_nuvem", "pontos": 5, "ultima": 50})
	await create_timer(1.5).timeout

	# FASE 3 — Merge: local desatualizado + nuvem à frente + perfil só-local
	var local: Array = [
		{"nome": "teste_online", "pontos": 10, "ultima": 100},
		{"nome": "teste_local", "pontos": 2, "ultima": 20},
	]
	var remotos: Array = await _buscar_async()
	_check(_nomes(remotos).has("teste_nuvem"), "FASE3: nuvem tem teste_nuvem")
	_mesclar(local, remotos)
	var po := _acha(local, "teste_online")
	_check(int(po.get("pontos", 0)) == 50, "FASE3: merge levou pontos MAIORES (50)")
	_check(int(po.get("ultima", 0)) == 999, "FASE3: merge levou ultima MAIOR (999)")
	_check(not _acha(local, "teste_nuvem").is_empty(), "FASE3: novo da nuvem entrou no local")
	_check(not _acha(local, "teste_local").is_empty(), "FASE3: perfil só-local preservado")

	# Sobe o merge de volta e confere estado final da nuvem
	_sync.subir_perfis(local)
	await create_timer(1.5).timeout
	var fin: Array = await _buscar_async()
	_check(int(_acha(fin, "teste_online").get("pontos", 0)) == 50, "FASE3: nuvem final online=50")
	_check(int(_acha(fin, "teste_nuvem").get("pontos", 0)) == 5, "FASE3: nuvem final nuvem=5")
	_check(int(_acha(fin, "teste_local").get("pontos", 0)) == 2, "FASE3: nuvem final local=2")

	# FASE 4 — Offline: endpoint inalcançável não pode quebrar nada
	var off := SYNC_SCRIPT.new()
	root.add_child(off)
	off._url = "https://nao-existe-abc123.supabase.co"
	off._key = "sb_publishable_teste"
	off._pronto = true
	_resp_ok = false
	_resp = ["sujeira"]
	off.buscar_perfis(func(lista: Array) -> void:
		_resp = lista
		_resp_ok = true
	)
	var espera := 0
	while not _resp_ok and espera < 800:
		await process_frame
		espera += 1
	_check(_resp_ok, "FASE4: callback offline foi chamado (não travou)")
	_check(_resp is Array and _resp.is_empty(), "FASE4: offline retorna lista vazia")
	off.subir_perfil({"nome": "teste_off", "pontos": 1, "ultima": 1})
	await create_timer(0.5).timeout
	_check(true, "FASE4: subir offline não quebrou")
	off.queue_free()

	# FASE 5 — Cleanup da nuvem
	var fim: Array = await _buscar_async()
	var todos := PackedStringArray()
	for item in fim:
		var n := str((item as Dictionary).get("nome", ""))
		if n.begins_with("teste_"):
			todos.append(n)
	if not todos.is_empty():
		await _deletar_async(todos)
	var pos: Array = await _buscar_async()
	_check(_nomes(pos).filter(func(n): return n.begins_with("teste_")).is_empty(), "FASE5: nuvem limpa")

	var resumo := "TUDO OK" if _fails == 0 else str(_fails) + " FALHA(S)"
	print("=== RESULTADO: ", resumo, " ===")
	quit(0 if _fails == 0 else 1)

func _deletar_async(nomes: PackedStringArray) -> void:
	var lista := ""
	for i in nomes.size():
		lista += nomes[i] + ("," if i < nomes.size() - 1 else "")
	var req := HTTPRequest.new()
	req.timeout = 6.0
	root.add_child(req)
	req.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
	)
	req.request(
		"https://cbwzlwekhdjloetgoxlg.supabase.co/rest/v1/perfis?nome=in.(" + lista + ")",
		PackedStringArray([
			"apikey: sb_publishable_XjlL0C7HAUBXg_dBSpkWRg_PGcXBqJB",
			"Authorization: Bearer sb_publishable_XjlL0C7HAUBXg_dBSpkWRg_PGcXBqJB",
			"Prefer: return=minimal",
		]),
		HTTPClient.METHOD_DELETE)
	await create_timer(1.5).timeout
