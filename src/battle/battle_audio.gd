extends Node
class_name BattleAudio
## 合成木块与纸张音色：预先缓存短音效；随机数与战斗规则完全独立。
const RATE := 22050
const VOICES := 8
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice := 0
var _variant := 0
var _last_select_ms := -1000


func _ready() -> void:
	for cue in ["select", "play", "hit", "block", "heal", "gravity"]:
		var variants: Array[AudioStreamWAV] = []
		for variant in 3:
			variants.append(_synthesize(cue, variant))
		_streams[cue] = variants
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.SFX_BUS
		add_child(player)
		_voices.append(player)
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()


func _on_settings_changed() -> void:
	if Settings.sfx_volume <= 0.0:
		for voice in _voices:
			voice.stop()


func play_cue(cue: String) -> void:
	if Settings.sfx_volume <= 0.0 or not _streams.has(cue):
		return
	var now := Time.get_ticks_msec()
	if cue == "select":
		if now - _last_select_ms < 45:
			return
		_last_select_ms = now
	var player := _voices[_voice]
	_voice = (_voice + 1) % VOICES
	player.stream = _streams[cue][_variant % 3]
	_variant += 1
	player.volume_db = -9.0 if cue == "select" else -3.0
	player.play()


func _synthesize(cue: String, variant: int) -> AudioStreamWAV:
	var duration := 0.12 if cue == "select" else (0.42 if cue == "gravity" else 0.26)
	var samples := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 7713 + variant * 61 + cue.hash()
	var filtered := 0.0
	for index in samples:
		var t := float(index) / RATE
		var fade := smoothstep(0.0, 0.0015, t) * smoothstep(0.0, 0.018, duration - t)
		var noise := random.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.16)
		var sample := 0.0
		var pitch := 1.0 + variant * 0.045
		match cue:
			"select", "play":
				var base := 410.0 if cue == "select" else 240.0
				sample = (sin(TAU * base * pitch * t) * 0.43 + sin(TAU * base * 2.73 * pitch * t) * 0.18) * exp(-t * 35.0)
				sample += filtered * 0.23 * exp(-t * 50.0)
				if cue == "play":
					sample += noise * 0.11 * exp(-t * 17.0)
			"hit", "gravity":
				var base := 110.0 if cue == "hit" else 67.0
				sample = sin(TAU * (base * pitch * t + 0.20 * (1.0 - exp(-t * 28.0)))) * 0.58 * exp(-t * 13.0)
				sample += sin(TAU * 340.0 * pitch * t) * 0.15 * exp(-t * 36.0) + filtered * 0.27 * exp(-t * 18.0)
			"block":
				sample = (sin(TAU * 610.0 * pitch * t) + sin(TAU * 967.0 * pitch * t) * 0.37) * 0.24 * exp(-t * 21.0)
				sample += filtered * 0.15 * exp(-t * 35.0)
			"heal":
				sample = (sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) * 0.5) * 0.20 * sin(PI * t / duration) * exp(-t * 8.0)
		var integer := int(clampf(sample * fade, -0.95, 0.95) * 32767)
		bytes.encode_s16(index * 2, integer)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
