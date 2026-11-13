extends Node
## The sound of the game: one-shot effects from a small pool of players, the rain underneath it all,
## and slowed time heard as well as seen: lower pitch and a muffled, under-water top end.

const DIR := "res://sfx/"
const NAMES := ["flutter", "shot_player", "shot_enemy", "hit_flesh", "hit_cover", "clink", "casing", "slow_in", "slow_out",
		"dive", "land", "body_fall", "step1", "step2", "whiz", "death_sting"]
const VOICES := 20
const HEAR := 2600.0   # world pixels from the listener at which a sound has faded out

var listener_x := 0.0   # set by main.gd each frame: the camera's x
var slow := 0.0         # 0..1, set by main.gd

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _muffle: AudioEffectLowPassFilter


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load(DIR + n + ".wav")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	var rain: AudioStreamWAV = load(DIR + "rain_loop.wav")
	rain.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rain.loop_begin = 0
	rain.loop_end = int(rain.get_length() * rain.mix_rate)
	_rain = AudioStreamPlayer.new()
	_rain.stream = rain
	_rain.volume_db = -17.0
	add_child(_rain)
	_rain.play()
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _muffle)


func _exit_tree() -> void:
	# the scene reloads after a death: take the filter off the bus so it is not stacked again
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, i) == _muffle:
			AudioServer.remove_bus_effect(0, i)


func _process(_delta: float) -> void:
	_muffle.cutoff_hz = lerpf(20000.0, 1300.0, slow)
	_rain.pitch_scale = lerpf(1.0, 0.7, slow)


## Play one sound. `at_x` (world x) makes it quieter the further it is from the camera; INF = right here.
## `vary` spreads the pitch a little so repeats do not sound mechanical.
func play(sound: String, volume_db := 0.0, at_x := INF, vary := 0.06) -> void:
	if not _streams.has(sound):
		return
	var vol := volume_db
	if at_x != INF:
		var k := clampf(absf(at_x - listener_x) / HEAR, 0.0, 1.0)
		if k >= 1.0:
			return
		vol += linear_to_db(1.0 - k * k)
	var p := _pool[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.volume_db = vol
	p.pitch_scale = randf_range(1.0 - vary, 1.0 + vary) * lerpf(1.0, 0.62, slow)
	p.play()
