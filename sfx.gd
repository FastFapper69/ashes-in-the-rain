extends Node
## The sound of the game: one-shot effects from a small pool of players, the rain underneath it all,
## and slowed time heard as well as seen: lower pitch and a muffled, under-water top end.

const DIR := "res://sfx/"
const NAMES := ["shot_player", "shot_enemy", "shot_tommy", "shot_shotgun", "hit_flesh", "hit_cover", "clink", "casing",
		"slow_in", "slow_out", "dive", "land", "body_fall", "step1", "step2", "whiz", "death_sting", "explosion", "glass",
		"pickup", "drink", "flutter", "dry_fire", "reload_revolver", "reload_mag", "reload_shells", "reload_done",
		"thunder", "coo", "wing", "knock", "foghorn", "cuffs", "drawer", "punch", "cup", "hammer", "toast", "creak", "resolve", "drip", "wood_break", "wood_hit", "zap", "type", "page", "skid", "phone_ring", "match", "sting", "car_arrive", "door", "power_down", "chain", "train_pass", "cyl_open", "shell_in", "cyl_spin"]
const LOOPS := ["train_loop", "fire", "neon_hum", "lamp_hum", "steam", "city", "heartbeat", "siren", "crowd", "water", "rain_in",
		"music_base", "music_lead", "music_tension", "music_fight"]
const STEMS := ["music_base", "music_lead", "music_tension", "music_fight"]   # all four run in step; only their levels move
## The jazz (Artlist: The Magnetic Buzz - Keep Your Head Down; Rotem Cinamon - Dusk). It takes the place of the
## base and lead stems whenever nothing is fighting; a fight hands over to the drawn stems again.
const MELODIES := {"jazz": "music_jazz", "dusk": "music_dusk", "gnossienne": "music_gnossienne", "melancholia": "music_melancholia", "broken_trust": "music_broken_trust"}
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
var melody := "jazz"   # which jazz plays when calm: "jazz" in the streets, "dusk" on the title and in the story
var _melody := {}       # name -> AudioStreamPlayer
var story := false      # a cutscene: its piano plays under the panels whatever the stems are doing
var music_want := [-80.0, -80.0, -80.0, -80.0]   # dB per stem (STEMS), set by main.gd and the cutscenes; eased to
var rain_want := 1.0    # how hard it rains where we are: 0 none (the subway, the fire dream) .. 1.5 a storm
var indoor := 0.0       # 1 = under a roof: the rain is heard through the walls, the city drops away
var _rain_in: AudioStreamPlayer
var _city: AudioStreamPlayer
var _beds := {}         # cutscene ambience: sound name -> {player, db}
var _story := false
var _city_bed := -80.0
var _loops: Array = []   # {player, x, db, on}: hums and hisses fixed in the street, heard as you pass
var _ambient_t := {"drip": 2.0}   # thunder comes from main.gd, after its lightning


func _ready() -> void:
	for b in ["Music", "SFX"]:   # the two buses are in default_bus_layout.tres (on the web they must exist from the start); this only covers a missing file
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	load("res://menu.gd").apply_settings()
	for n in NAMES:
		_streams[n] = load(DIR + n + ".wav")
	for n in LOOPS + ["rain_loop", MELODIES["jazz"], MELODIES["dusk"]]:
		_streams[n] = _looped(n)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_rain = AudioStreamPlayer.new()
	_rain.stream = _streams["rain_loop"]
	_rain.volume_db = -80.0
	_rain.bus = "SFX"
	add_child(_rain)
	_rain.play()
	_rain_in = AudioStreamPlayer.new()   # the same rain heard from inside, through glass and brick
	_rain_in.stream = _streams["rain_in"]
	_rain_in.volume_db = -80.0
	_rain_in.bus = "SFX"
	add_child(_rain_in)
	_rain_in.play()
	_city = AudioStreamPlayer.new()   # the city behind it all, there wherever there is a street
	_city.stream = _streams["city"]
	_city.volume_db = -19.0
	_city.bus = "SFX"
	add_child(_city)
	_city.play()
	for n in STEMS:
		var mp := AudioStreamPlayer.new()
		mp.stream = _streams[n]
		mp.volume_db = -80.0
		mp.bus = "Music"
		add_child(mp)
		mp.play()
		_music.append(mp)
	for k in ["jazz", "dusk"]:   # the story's pianos are loaded only when a story page asks for one:
		# on the web every stream is decoded whole into memory, and a phone has little to spare
		var jp := AudioStreamPlayer.new()
		jp.stream = _streams[MELODIES[k]]
		jp.volume_db = -80.0
		jp.bus = "Music"
		add_child(jp)
		_melody[k] = jp
	_heart = AudioStreamPlayer.new()   # slowed time: the heart, heard from inside
	_heart.stream = _streams["heartbeat"]
	_heart.volume_db = -60.0
	_heart.bus = "SFX"
	add_child(_heart)
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _muffle)


## A sound that runs on and on: the long ones are Ogg (music, rain, the city), the short ones WAV.
func _looped(n: String) -> AudioStream:
	if ResourceLoader.exists(DIR + n + ".ogg"):
		var o: AudioStreamOggVorbis = load(DIR + n + ".ogg")
		o.loop = true
		return o
	var w: AudioStreamWAV = load(DIR + n + ".wav")
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.get_length() * w.mix_rate)
	return w


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
	_rain_in.pitch_scale = _rain.pitch_scale
	# rain only where it rains: outside full, inside through the walls, nothing in the dry
	var r := clampf(rain_want, 0.0, 1.5)
	var out_db := -80.0 if r < 0.02 else -17.0 + linear_to_db(r) + linear_to_db(maxf(0.001, 1.0 - indoor))
	var in_db := -80.0 if r < 0.02 else -15.0 + linear_to_db(r) + linear_to_db(maxf(0.001, indoor))
	_rain.volume_db = move_toward(_rain.volume_db, out_db, 30.0 * _delta_real)
	_rain_in.volume_db = move_toward(_rain_in.volume_db, in_db, 30.0 * _delta_real)
	var city_db := -19.0 - 14.0 * indoor
	if _story:   # a story panel brings its own sounds, the city among them or not
		city_db = _city_bed
	_city.volume_db = move_toward(_city.volume_db, city_db, 30.0 * _delta_real)
	for n in _beds.keys():
		var b: Dictionary = _beds[n]
		var bp: AudioStreamPlayer = b["player"]
		bp.volume_db = move_toward(bp.volume_db, float(b["db"]), 24.0 * _delta_real)
		if float(b["db"]) <= -79.0 and bp.volume_db <= -79.0:
			bp.queue_free()
			_beds.erase(n)
	if slow > 0.05 and not _heart.playing:
		_heart.play()
	elif slow <= 0.05 and _heart.playing:
		_heart.stop()
	_heart.volume_db = linear_to_db(maxf(0.001, slow)) - 4.0
	var duck := 7.0 if voice_on() else 0.0   # under Frank's voice
	# calm (no fight stem) with a lead wanted: the jazz plays instead of the base and lead stems
	var calm: bool = music_want[3] <= -60.0 and music_want[1] > -60.0
	for k in _melody:
		var jp: AudioStreamPlayer = _melody[k]
		var jw: float = (maxf(music_want[0], music_want[1]) + 1.0 - duck) if calm and k == melody else -80.0
		if story:   # the story's piano: always there under the panels, softer under Frank's voice
			jw = (-7.0 - duck * 0.8) if k == melody else -80.0
		if jw > -79.0 and not jp.playing:
			jp.play()
		elif jw > -79.0 and jp.stream_paused:
			jp.stream_paused = false   # picks the tune up where the fight interrupted it
		jp.volume_db = move_toward(jp.volume_db, jw, (10.0 if jw < jp.volume_db else 5.0) * _delta_real)
		jp.pitch_scale = lerpf(1.0, 0.8, slow)
		if jw <= -79.0 and jp.volume_db <= -79.0 and jp.playing and not jp.stream_paused:
			jp.stream_paused = true
	for i in STEMS.size():
		var want: float = (-80.0 if (calm or story) and i < 2 else music_want[i]) - duck
		var mp := _music[i]
		mp.volume_db = move_toward(mp.volume_db, want, (8.0 if want < mp.volume_db else 4.0) * _delta_real)
		mp.pitch_scale = lerpf(1.0, 0.8, slow)
	for l in _loops:   # only the ones in earshot actually play
		var k := absf(float(l["x"]) - listener_x) / float(l["reach"])
		if view.size.x > 0.0 and float(l["y"]) != INF:   # a thing with a place: loud while it is in the picture, fading once it leaves it
			var at := Vector2(float(l["x"]), float(l["y"]))
			var d := at.distance_to(Vector2(clampf(at.x, view.position.x, view.end.x), clampf(at.y, view.position.y, view.end.y)))
			k = d / float(l["reach"])
		var p: AudioStreamPlayer = l["player"]
		if k >= 1.0 or not l["on"] or _story:   # under a story panel the street falls silent
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(randf() * p.stream.get_length())
		p.volume_db = float(l["db"]) + linear_to_db(maxf(0.001, 1.0 - k * k))
		p.pitch_scale = lerpf(1.0, 0.75, slow)
	# now and then: thunder far off, water dripping somewhere near
	for n in _ambient_t:
		if _story:
			continue
		_ambient_t[n] -= delta
		if _ambient_t[n] <= 0.0:
			if n == "thunder":
				play("thunder", -9.0, INF, 0.15)
				_ambient_t[n] = randf_range(45.0, 110.0)
			else:
				play("drip", -13.0, listener_x + randf_range(-900.0, 900.0), 0.25)
				_ambient_t[n] = randf_range(1.5, 5.0)


## Frank's voice for a line of narration (gen/voice_lines.py: voice/<md5 of the line, 10 chars>.mp3), if
## it has been recorded. Returns how long it runs, or 0. The music ducks under him while he talks.
var _voice: AudioStreamPlayer
func voice(text: String) -> float:
	var path := "res://voice/%s.mp3" % text.md5_text().substr(0, 10)
	if not ResourceLoader.exists(path):
		return 0.0
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		_voice.bus = "SFX"
		add_child(_voice)
	_voice.stream = load(path)
	_voice.volume_db = 1.0
	_voice.play()
	return (_voice.stream as AudioStream).get_length()


func voice_on() -> bool:
	return _voice != null and _voice.playing


## The ambience under a story panel: these loops at these levels (dB), everything else faded out.
## {} lets the street come back.
func bed(want: Dictionary) -> void:
	if _log:
		print("BED ", want, " rain ", rain_want)
	_story = not want.is_empty()
	_city_bed = float(want.get("city", -80.0))
	for n in _beds:
		_beds[n]["db"] = -80.0
	for n in want:
		if n == "city":
			continue
		if not _streams.has(n):
			continue
		if not _beds.has(n) or not is_instance_valid(_beds[n]["player"]):
			var p := AudioStreamPlayer.new()
			p.stream = _streams[n]
			p.bus = "SFX"
			p.volume_db = -60.0
			add_child(p)
			p.play(randf() * p.stream.get_length())
			_beds[n] = {"player": p, "db": float(want[n])}
		else:
			_beds[n]["db"] = float(want[n])


## A sound that hums or hisses on its own at one place in the street (a neon sign, a lamp,
## steam). Returns its record, so the caller can switch it off and on.
var view := Rect2()   # the part of the world on screen (main.gd keeps it up to date)


func add_loop(sound: String, at_x: float, volume_db: float, reach := 1400.0, at_y := INF) -> Dictionary:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.bus = "SFX"
	add_child(p)
	var rec := {"player": p, "x": at_x, "y": at_y, "db": volume_db, "on": true, "reach": reach}
	_loops.append(rec)
	return rec


## Play one sound. `at_x` (world x) makes it quieter the further it is from the camera; INF = right here.
## `vary` spreads the pitch a little so repeats do not sound mechanical.
static var _log := "--log-sound" in OS.get_cmdline_user_args()   # tests: print every sound played

func play(sound: String, volume_db := 0.0, at_x := INF, vary := 0.06) -> void:
	if not _streams.has(sound) or (_story and at_x != INF):   # under a story panel the street is not heard
		if _log and not _streams.has(sound):
			print("SOUND MISSING ", sound)
		return
	if _log:
		print("SOUND ", sound, " ", volume_db)
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


## A cutscene starts its piece from the top, so its opening bars are heard.
func melody_from_start(k: String) -> void:
	melody = k
	if not _melody.has(k) and MELODIES.has(k):
		var jp := AudioStreamPlayer.new()
		jp.stream = _looped(MELODIES[k])
		jp.volume_db = -80.0
		jp.bus = "Music"
		add_child(jp)
		_melody[k] = jp
	if _melody.has(k):
		var jp: AudioStreamPlayer = _melody[k]
		jp.stop()
		jp.volume_db = -30.0
		jp.play()
