class_name PontosStore
extends Node
## Regra de pontuação: "maior nota vence" POR NARRATIVA.
## feitas = {id_da_narrativa: maior nº de acertos}; narrativa com nota registrada
## é CONCLUÍDA e fica bloqueada pra novo jogo no seletor.
## pontos = total do perfil (soma das maiores notas, nunca diminui).
## Arquivos locais: user://perfis.json (lista) e user://sessao.json ({"nome": ...}).

const PERFIS_PATH := "user://perfis.json"
const SESSAO_PATH := "user://sessao.json"

## Nome do perfil logado na sessão ("" se não houver).
static func sessao_nome() -> String:
	if not FileAccess.file_exists(SESSAO_PATH):
		return ""
	var f := FileAccess.open(SESSAO_PATH, FileAccess.READ)
	if f == null:
		return ""
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return str((data as Dictionary).get("nome", ""))
	return ""

## Registra a nota de uma narrativa no perfil (case-insensitive) e salva.
## Devolve o perfil atualizado (pra subir à nuvem) ou {} se não achou/salvou.
static func registrar_pontos(nome: String, narrativa_id: String, score: int) -> Dictionary:
	nome = nome.strip_edges()
	narrativa_id = narrativa_id.strip_edges()
	if nome.is_empty() or narrativa_id.is_empty() or not FileAccess.file_exists(PERFIS_PATH):
		return {}
	var fr := FileAccess.open(PERFIS_PATH, FileAccess.READ)
	if fr == null:
		return {}
	var data: Variant = JSON.parse_string(fr.get_as_text())
	if not (data is Array):
		return {}
	var lista := data as Array
	var alvo: Dictionary = {}
	for item: Variant in lista:
		if item is Dictionary and str((item as Dictionary).get("nome", "")).to_lower() == nome.to_lower():
			alvo = item as Dictionary
			break
	if alvo.is_empty():
		return {}
	var feitas: Dictionary = {}
	if alvo.get("feitas") is Dictionary:
		feitas = alvo["feitas"] as Dictionary
	feitas[narrativa_id] = maxi(int(feitas.get(narrativa_id, 0)), score)
	alvo["feitas"] = feitas
	var soma := 0
	for k: Variant in feitas:
		soma += int(feitas[k])
	alvo["pontos"] = maxi(soma, int(alvo.get("pontos", 0)))
	var fw := FileAccess.open(PERFIS_PATH, FileAccess.WRITE)
	if fw == null:
		return {}
	fw.store_string(JSON.stringify(lista))
	return alvo

## Nota maior já obtida numa narrativa (-1 se nunca jogou).
static func nota_de(perfil: Dictionary, narrativa_id: String) -> int:
	var fv: Variant = perfil.get("feitas")
	if fv is Dictionary and (fv as Dictionary).has(narrativa_id):
		return int((fv as Dictionary).get(narrativa_id, -1))
	return -1

## true se a narrativa já foi concluída pelo perfil.
static func concluida(perfil: Dictionary, narrativa_id: String) -> bool:
	return nota_de(perfil, narrativa_id) >= 0
