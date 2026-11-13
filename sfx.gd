extends Node
## The sound of the game: one-shot effects from a small pool of players, the rain underneath it all,
## and slowed time heard as well as seen: lower pitch and a muffled, under-water top end.

const DIR := "res://sfx/"
const NAMES := ["shot_player", "shot_enemy", "shot_tommy", "shot_shotgun", "hit_flesh", "hit_cover", "clink", "casing",
		"slow_in", "slow_out", "dive", "land", "body_fall", "step1", "step2", "whiz", "death_sting", "explosion", "glass",
		"pickup", "drink", "flutter", "dry_fire", "reload_revolver", "reload_mag", "reload_shells", "reload_done",
		"thunder", "coo", "wing", "drip", "wood_break", "wood_hit", "zap", "type", "page", "skid"]
const LOOPS := ["neon_hum", "lamp_hum", "steam", "city", "heartbeat", "music_base", "music_lead"]
const VOICES := 20
const HEAR := 2600.0   # world pixels from the listener at which a sound has faded out

var listener_x := 0.0   # set by main.gd each frame: the camera's x
var slow := 0.0         # 0..1, set by main.gd

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _muffle: AudioEffectLowPassFilter
var _heart: AudioStreamPlayer
var _music: Array[AudioStreamPlayer] = []
var music_want := Vector2(-80.0, -80.0)   # dB for the base and the lead, set by main.gd; eased to
var _loops: Array = []   # {player, x, db, on}: hums and hisses fixed in the street, heard as you pass
var _ambient_t := {"drip": 2.0}   # thunder comes from main.gd, after its lightning


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load(DIR + n + ".wav")
	for n in LOOPS:
		var w: AudioStreamWAV = load(DIR + n + ".wav")
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		_streams[n] = w
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
	var city := AudioStreamPlayer.new()   # the city behind it all, always there under the rain
	city.stream = _streams["city"]
	city.volume_db = -19.0
	add_child(city)
	city.play()
	for n in ["music_base", "music_lead"]:   # the two stems run in step, always; only their levels move
		var mp := AudioStreamPlayer.new()
		mp.stream = _streams[n]
		mp.volume_db = -80.0
		add_child(mp)
		mp.play()
		_music.append(mp)
	_heart = AudioStreamPlayer.new()   # slowed time: the heart, heard from inside
	_heart.stream = _streams["heartbeat"]
	_heart.volume_db = -60.0
	add_child(_heart)
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _muffle)


func _exit_tree() -> void:
	# the scene reloads after a death: take the filter off the bus so it is not stacked again
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, i) == _muffle:
			AudioServer.remove_bus_effect(0, i)


var _delta_real := 0.016
func _process(delta: float) -> void:
	_delta_real = delta / maxf(Engine.time_scale, 0.05)
	_muffle.cutoff_hz = lerpf(20000.0, 1300.0, slow)
	_rain.pitch_scale = lerpf(1.0, 0.7, slow)
	if slow > 0.05 and not _heart.playing:
		_heart.play()
	elif slow <= 0.05 and _heart.playing:
		_heart.stop()
	_heart.volume_db = linear_to_db(maxf(0.001, slow)) - 4.0
	for i in 2:
		var want: float = music_want[i]
		var mp := _music[i]
		mp.volume_db = move_toward(mp.volume_db, want, (8.0 if want < mp.volume_db else 4.0) * _delta_real)
		mp.pitch_scale = lerpf(1.0, 0.8, slow)
	for l in _loops:   # only the ones in earshot actually play
		var k := absf(float(l["x"]) - listener_x) / float(l["reach"])
		var p: AudioStreamPlayer = l["player"]
		if k >= 1.0 or not l["on"]:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(randf() * p.stream.get_length())
		p.volume_db = float(l["db"]) + linear_to_db(maxf(0.001, 1.0 - k * k))
		p.pitch_scale = lerpf(1.0, 0.75, slow)
	# now and then: thunder far off, water dripping somewhere near
	for n in _ambient_t:
		_ambient_t[n] -= delta
		if _ambient_t[n] <= 0.0:
			if n == "thunder":
				play("thunder", -9.0, INF, 0.15)
				_ambient_t[n] = randf_range(45.0, 110.0)
			else:
				play("drip", -13.0, listener_x + randf_range(-900.0, 900.0), 0.25)
				_ambient_t[n] = randf_range(1.5, 5.0)


## A sound that hums or hisses on its own at one place in the street (a neon sign, a lamp,
## steam). Returns its record, so the caller can switch it off and on.
func add_loop(sound: String, at_x: float, volume_db: float, reach := 1400.0) -> Dictionary:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	add_child(p)
	var rec := {"player": p, "x": at_x, "db": volume_db, "on": true, "reach": reach}
	_loops.append(rec)
	return rec


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
