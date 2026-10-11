extends Node
## Fully procedural audio (no asset files). Autoload "Audio".

const RATE := 22050
const MUSIC_RATE := 11025

var sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _engine: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _thread: Thread

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	sfx["engine"] = _engine_loop()
	sfx["coin"] = _coin()
	sfx["crash"] = _crash()
	sfx["horn"] = _horn()
	sfx["boost"] = _sweep(180.0, 900.0, 0.55, 0.35)
	sfx["click"] = _tone(660.0, 0.07, 0.35)
	sfx["levelup"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.11, 0.4)
	sfx["pickup"] = _arp([440.0, 554.37, 659.25], 0.09, 0.35)
	sfx["fail"] = _sweep(400.0, 120.0, 0.5, 0.35)
	sfx["rain"] = _rain_loop()

	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	_engine = AudioStreamPlayer.new()
	_engine.stream = sfx["engine"]
	_engine.bus = "SFX"
	_engine.volume_db = -80.0
	add_child(_engine)

	_rain = AudioStreamPlayer.new()
	_rain.stream = sfx["rain"]
	_rain.bus = "SFX"
	_rain.volume_db = -80.0
	add_child(_rain)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)

	apply_volumes()
	# Music synthesis is the slowest part in GDScript: do it off the main thread.
	_thread = Thread.new()
	_thread.start(_build_music)

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()

func _process(_d: float) -> void:
	if _thread != null and _thread.is_started() and not _thread.is_alive():
		_thread.wait_to_finish()
		if _music_stream != null:
			_music.stream = _music_stream
			_music.play()

# ------------------------------------------------------------------ buses

func _make_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, "Master")

func apply_volumes() -> void:
	_set_bus("Music", float(Save.setting("music")))
	_set_bus("SFX", float(Save.setting("sfx")))

func _set_bus(n: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(n)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))

# ------------------------------------------------------------------ playback

func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not sfx.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = sfx[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return

func engine_on(on: bool) -> void:
	if on and not _engine.playing:
		_engine.play()
	elif not on:
		_engine.stop()

## ratio: 0..1+ of top speed; throttle 0..1
func set_engine(ratio: float, throttle: float) -> void:
	if not _engine.playing:
		return
	_engine.pitch_scale = lerpf(0.7, 2.6, clampf(ratio, 0.0, 1.2))
	_engine.volume_db = lerpf(-20.0, -8.0, clampf(throttle, 0.0, 1.0)) - (1.0 - clampf(ratio * 4.0, 0.0, 1.0)) * 4.0

func rain_on(on: bool) -> void:
	if on and not _rain.playing:
		_rain.play()
	elif not on and _rain.playing:
		_rain.stop()
	_rain.volume_db = -16.0

# ------------------------------------------------------------------ synthesis

func _wav(s: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

func _engine_loop() -> AudioStreamWAV:
	# 55 Hz fundamental, exactly 55 cycles in 1 s -> seamless loop.
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for h in range(1, 7):
			v += sin(TAU * 55.0 * h * t) / float(h)
		v *= 0.35 * (0.85 + 0.15 * sin(TAU * 11.0 * t))
		v += rng.randf_range(-0.04, 0.04)
		s[i] = v
	return _wav(s, RATE, true)

func _rain_loop() -> AudioStreamWAV:
	var n := RATE * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
		s[i] = lp * 0.5
	return _wav(s, RATE, true)

func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := 1.0 - float(i) / n
		s[i] = sin(TAU * freq * t) * env * vol
	return _wav(s)

func _arp(freqs: Array, note: float, vol: float) -> AudioStreamWAV:
	var per := int(RATE * note)
	var s := PackedFloat32Array()
	s.resize(per * freqs.size())
	for k in freqs.size():
		for i in per:
			var t := float(i) / RATE
			var env := 1.0 - float(i) / per
			s[k * per + i] = (sin(TAU * freqs[k] * t) + 0.3 * sin(TAU * freqs[k] * 2.0 * t)) * env * vol * 0.8
	return _wav(s)

func _coin() -> AudioStreamWAV:
	return _arp([988.0, 1319.0], 0.09, 0.4)

func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		phase += TAU * lerpf(f0, f1, u) / RATE
		s[i] = sin(phase) * vol * (1.0 - u * 0.6)
	return _wav(s)

func _crash() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		var u := float(i) / n
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.5)
		s[i] = (lp * 0.8 + sin(TAU * 70.0 * u) * 0.5) * pow(1.0 - u, 2.0) * 0.8
	return _wav(s)

func _horn() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, float(i) / 400.0) * minf(1.0, float(n - i) / 1500.0)
		var a := signf(sin(TAU * 392.0 * t)) * 0.5 + signf(sin(TAU * 494.0 * t)) * 0.5
		s[i] = a * 0.25 * env
	return _wav(s)

## Runs on a worker thread. Simple synthwave loop: bass + pad + arpeggio, Am-F-C-G.
func _build_music() -> void:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 4
	var beats := bars * 4
	var total := int(MUSIC_RATE * beat * beats)
	var s := PackedFloat32Array()
	s.resize(total)
	var roots := [55.0, 43.65, 65.41, 49.0]
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	for i in total:
		var t := float(i) / MUSIC_RATE
		var b := t / beat
		var bar := int(b / 4.0) % 4
		var root: float = roots[bar]
		var ch: Array = chords[bar]
		# Bass (saw-ish) with per-beat pump
		var bph := fposmod(t * root, 1.0)
		var bass := (bph * 2.0 - 1.0) * 0.28 * (0.6 + 0.4 * (1.0 - fposmod(b, 1.0)))
		# Pad
		var pad := 0.0
		for f in ch:
			pad += sin(TAU * f * t)
		pad *= 0.045
		# Arpeggio, eighth notes
		var step := int(b * 2.0)
		var an := fposmod(b * 2.0, 1.0)
		var af: float = ch[step % 3] * 2.0
		var arp := signf(sin(TAU * af * t)) * 0.07 * (1.0 - an) * (1.0 - an)
		s[i] = bass + pad + arp
	_music_stream = _wav(s, MUSIC_RATE, true)
