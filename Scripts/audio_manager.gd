extends Node
## Áudio global: música de fundo em loop + pool de SFX.

const SFX := {
	"click": preload("res://Assets/audio/sfx/click.wav"),
	"blip": preload("res://Assets/audio/sfx/blip.wav"),
	"whoosh_in": preload("res://Assets/audio/sfx/whoosh_in.wav"),
	"whoosh_out": preload("res://Assets/audio/sfx/whoosh_out.wav"),
	"correct": preload("res://Assets/audio/sfx/correct.wav"),
	"wrong": preload("res://Assets/audio/sfx/wrong.wav"),
	"chime": preload("res://Assets/audio/sfx/chime.wav"),
	"open": preload("res://Assets/audio/sfx/open.wav"),
	"close": preload("res://Assets/audio/sfx/close.wav"),
	"error": preload("res://Assets/audio/sfx/error.wav"),
}

const POOL_SIZE := 8
const BGM_DB := -14.0
const SFX_DB := -4.0

var _bgm: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _proximo := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	_bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm.volume_db = BGM_DB
	_bgm.stream = _loop_stream(load("res://Assets/audio/bgm.wav"))
	add_child(_bgm)
	_bgm.play()

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)

func _loop_stream(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# bgm.wav tem exatamente 8s; data pode vir comprimida (QOA) após import
		w.loop_end = int(w.mix_rate * 8.0)
	return stream

func play(nome: String, volume_db: float = SFX_DB) -> void:
	if not SFX.has(nome):
		return
	var p := _pool[_proximo]
	_proximo = (_proximo + 1) % POOL_SIZE
	p.stream = SFX[nome]
	p.volume_db = volume_db
	p.play()

func set_bgm_volume_db(db: float) -> void:
	if _bgm != null:
		_bgm.volume_db = db
