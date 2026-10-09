extends CanvasLayer

## Transição de cenas: quadradinhos deslizam em onda diagonal (esq. → dir.).
## Uso: SceneTransition.change_scene("res://Scene.tscn")

const CELL := 56.0
const SLIDE := 0.22
const SWEEP := 0.5
const C_AZUL := Color(0.05, 0.1, 0.26)
const C_AZUL_CLARO := Color(0.12, 0.24, 0.5)

## Dados da próxima tela de narrativa (preencher antes de change_scene).
var titulo_narrativa := ""
var texto_narrativa := ""
var proxima_cena := ""

var _grid: Control
var _blocker: ColorRect
var _squares: Array[ColorRect] = []
var _bases: Array[Vector2] = []
var _delays: Array[float] = []
var _em_transicao := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_grid = Control.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.clip_contents = true
	_grid.visible = false
	add_child(_grid)

	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	add_child(_blocker)

	get_viewport().size_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_squares.clear()
	_bases.clear()
	_delays.clear()
	var vs := get_viewport().get_visible_rect().size
	var cols := maxi(ceili(vs.x / CELL), 1)
	var rows := maxi(ceili(vs.y / CELL), 1)
	for y in rows:
		for x in cols:
			var base := Vector2(x * CELL, y * CELL)
			var tx := float(x) / maxf(float(cols - 1), 1.0)
			var ty := float(y) / maxf(float(rows - 1), 1.0)
			var t := tx * 0.75 + ty * 0.25
			var c := C_AZUL.lerp(C_AZUL_CLARO, t)
			var sq := ColorRect.new()
			sq.color = c
			sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sq.position = base
			sq.size = Vector2(CELL + 1.0, CELL + 1.0)
			sq.modulate.a = 0.0
			_grid.add_child(sq)
			_squares.append(sq)
			_bases.append(base)
			_delays.append(t * SWEEP)

func change_scene(caminho: String) -> void:
	if _em_transicao:
		return
	_em_transicao = true
	_grid.visible = true
	_blocker.visible = true
	AudioManager.play("whoosh_in")
	await _cobrir()
	get_tree().change_scene_to_file(caminho)
	await get_tree().process_frame
	AudioManager.play("whoosh_out")
	await _revelar()
	_blocker.visible = false
	_grid.visible = false
	_em_transicao = false

func _cobrir() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	for i in _squares.size():
		var sq := _squares[i]
		var delay := _delays[i]
		sq.position = _bases[i] + Vector2(-CELL, 0.0)
		sq.modulate.a = 0.0
		tw.tween_property(sq, "position", _bases[i], SLIDE).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sq, "modulate:a", 1.0, SLIDE * 0.6).set_delay(delay)
	await tw.finished

func _revelar() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	for i in _squares.size():
		var sq := _squares[i]
		var delay := _delays[i]
		tw.tween_property(sq, "position", _bases[i] + Vector2(CELL * 1.2, 0.0), SLIDE).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sq, "modulate:a", 0.0, SLIDE).set_delay(delay + SLIDE * 0.4)
	await tw.finished
