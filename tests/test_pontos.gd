extends SceneTree
## Teste da regra "maior nota vence" (PontosStore).
##   godot --headless --path . -s res://tests/test_pontos.gd
## Faz backup de user://perfis.json e sessao.json e restaura ao final.

const PERFIS_PATH := "user://perfis.json"
const SESSAO_PATH := "user://sessao.json"

var _fails := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)

func _ler(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()

func _gravar(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(txt)

func _initialize() -> void:
	_run()

func _run() -> void:
	await create_timer(0.1).timeout
	print("=== TESTE PONTOS (maior nota vence) ===")

	# Backup
	var bak_perfis := _ler(PERFIS_PATH)
	var bak_sessao := _ler(SESSAO_PATH)

	# Cenário: 2 perfis, sessão logada na "ana"
	_gravar(PERFIS_PATH, JSON.stringify([
		{"nome": "ana", "pontos": 5, "ultima": 100},
		{"nome": "bruno", "pontos": 0, "ultima": 200},
	]))
	_gravar(SESSAO_PATH, JSON.stringify({"nome": "ana"}))

	_check(PontosStore.sessao_nome() == "ana", "sessao_nome lê o JSON")

	# 1) score maior → sobe
	var r := PontosStore.registrar_pontos("ana", "narrativa_a", 8)
	_check(int(r.get("pontos", 0)) == 8, "score 8 > 5 vira 8")
	_check(int((r.get("feitas") as Dictionary).get("narrativa_a", -1)) == 8, "feitas[narrativa_a] == 8")
	_check(_ler(PERFIS_PATH).contains('"pontos":8'), "arquivo salvo com 8")

	# 2) score menor → não diminui
	r = PontosStore.registrar_pontos("ana", "narrativa_a", 3)
	_check(int(r.get("pontos", 0)) == 8, "score 3 < 8 mantém 8")
	_check(int((r.get("feitas") as Dictionary).get("narrativa_a", -1)) == 8, "feitas[narrativa_a] mantém 8")

	# 3) igual → não muda (e não quebra)
	r = PontosStore.registrar_pontos("ana", "narrativa_a", 8)
	_check(int(r.get("pontos", 0)) == 8, "score igual mantém 8")

	# 4) case-insensitive
	r = PontosStore.registrar_pontos("ANA", "narrativa_a", 9)
	_check(int(r.get("pontos", 0)) == 9, "nome com maiúsculas acha o perfil")

	# 5) segunda narrativa soma no total
	r = PontosStore.registrar_pontos("ana", "narrativa_b", 5)
	_check(int(r.get("pontos", 0)) == 14, "total vira 9 + 5 = 14")
	_check(int((r.get("feitas") as Dictionary).get("narrativa_b", -1)) == 5, "feitas[narrativa_b] == 5")

	# 6) perfil legado (sem feitas) nunca perde os pontos antigos
	_gravar(PERFIS_PATH, JSON.stringify([
		{"nome": "legado", "pontos": 20, "ultima": 1},
		{"nome": "bruno", "pontos": 0, "ultima": 200},
	]))
	r = PontosStore.registrar_pontos("legado", "narrativa_a", 5)
	_check(int(r.get("pontos", 0)) == 20, "legado mantém 20 (soma 5 não apaga)")
	_check(int((r.get("feitas") as Dictionary).get("narrativa_a", -1)) == 5, "legado ganha feitas[narrativa_a]")

	# 7) conclusão bloqueia novo jogo
	_check(PontosStore.concluida(r, "narrativa_a"), "concluida() true após registrar")
	_check(PontosStore.nota_de(r, "narrativa_a") == 5, "nota_de() devolve a nota")
	_check(PontosStore.nota_de(r, "narrativa_x") == -1, "narrativa não jogada devolve -1")
	_check(not PontosStore.concluida(r, "narrativa_x"), "concluida() false pra não jogada")

	# 8) perfil inexistente → nada muda
	r = PontosStore.registrar_pontos("fulano", "narrativa_a", 50)
	_check(r.is_empty(), "perfil inexistente devolve vazio")
	_check(not _ler(PERFIS_PATH).contains("fulano"), "perfil inexistente não é criado")

	# 9) outro perfil intacto
	var dados: Variant = JSON.parse_string(_ler(PERFIS_PATH))
	var bruno: Dictionary = {}
	for item: Variant in dados:
		if item is Dictionary and str((item as Dictionary).get("nome", "")) == "bruno":
			bruno = item as Dictionary
	_check(int(bruno.get("pontos", -1)) == 0, "perfil bruno intacto (0)")
	_check(not PontosStore.concluida(bruno, "narrativa_a"), "bruno não concluiu nada")

	# 10) sem sessão → ""
	_gravar(SESSAO_PATH, JSON.stringify({"nome": ""}))
	_check(PontosStore.sessao_nome() == "", "sessão vazia devolve ''")
	_gravar(SESSAO_PATH, "")
	_check(PontosStore.sessao_nome() == "", "sessão inexistente devolve ''")

	# 11) perfis.json inexistente → não quebra
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERFIS_PATH))
	r = PontosStore.registrar_pontos("ana", "narrativa_a", 9)
	_check(r.is_empty(), "sem perfis.json devolve vazio")
	_gravar(PERFIS_PATH, bak_perfis)

	# Restaura estado original
	if bak_perfis.is_empty():
		if FileAccess.file_exists(PERFIS_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PERFIS_PATH))
	else:
		_gravar(PERFIS_PATH, bak_perfis)
	if bak_sessao.is_empty():
		if FileAccess.file_exists(SESSAO_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSAO_PATH))
	else:
		_gravar(SESSAO_PATH, bak_sessao)

	var resumo := "TUDO OK" if _fails == 0 else str(_fails) + " FALHA(S)"
	print("=== RESULTADO: ", resumo, " ===")
	quit(0 if _fails == 0 else 1)
