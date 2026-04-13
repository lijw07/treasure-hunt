extends Node

var _sfx_footstep: AudioStreamPlayer2D
var _sfx_sword: AudioStreamPlayer2D
var _sfx_jump: AudioStreamPlayer2D
var _sfx_land: AudioStreamPlayer2D
var _sfx_roll: AudioStreamPlayer2D
var _sfx_tool: AudioStreamPlayer2D
var _sfx_fishing: AudioStreamPlayer2D
var _sfx_water: AudioStreamPlayer2D
var _sfx_bow: AudioStreamPlayer2D

var _footstep_sounds: Array[AudioStream] = []
var _sword_sounds: Array[AudioStream] = []
var _jump_sounds: Array[AudioStream] = []
var _roll_sounds: Array[AudioStream] = []
var _axe_chop_sounds: Array[AudioStream] = []
var _axe_swing_sounds: Array[AudioStream] = []
var _pickaxe_hit_sounds: Array[AudioStream] = []
var _pickaxe_swing_sounds: Array[AudioStream] = []
var _tool_swing_sounds: Array[AudioStream] = []

var _land_sound: AudioStream
var _fish_cast_sound: AudioStream
var _fish_splash_sound: AudioStream
var _fish_reel_sound: AudioStream
var _water_pour_sound: AudioStream
var _bow_shoot_sound: AudioStream
var _bow_draw_sound: AudioStream


func _ready() -> void:
	var player = get_parent()
	_create_players(player)
	_load_sounds()


func play_footstep() -> void:
	_play_random(_sfx_footstep, _footstep_sounds, -12.0)


func play_sword_swing(combo_step: int) -> void:
	if _sword_sounds.is_empty():
		return
	var idx := clampi(combo_step - 1, 0, _sword_sounds.size() - 1)
	_sfx_sword.stream = _sword_sounds[idx]
	_sfx_sword.pitch_scale = randf_range(0.95, 1.05)
	_sfx_sword.play()


func play_jump() -> void:
	_play_random(_sfx_jump, _jump_sounds, -4.0)


func play_land() -> void:
	_play_single(_sfx_land, _land_sound, -2.0)


func play_roll() -> void:
	_play_random(_sfx_roll, _roll_sounds, -4.0)


func play_axe_swing() -> void:
	_play_random(_sfx_tool, _axe_swing_sounds, 0.0, 0.85, 1.0)


func play_axe_chop() -> void:
	_play_random(_sfx_tool, _axe_chop_sounds)


func play_pickaxe_swing() -> void:
	_play_random(_sfx_tool, _pickaxe_swing_sounds, 0.0, 1.0, 1.2)


func play_pickaxe_hit() -> void:
	_play_random(_sfx_tool, _pickaxe_hit_sounds)


func play_tool_swing() -> void:
	_play_random(_sfx_tool, _tool_swing_sounds)


func play_fish_cast() -> void:
	_play_single(_sfx_fishing, _fish_cast_sound)


func play_fish_splash() -> void:
	_play_single(_sfx_fishing, _fish_splash_sound)


func play_fish_reel() -> void:
	_play_single(_sfx_fishing, _fish_reel_sound)


func play_water_pour() -> void:
	_play_single(_sfx_water, _water_pour_sound)


func play_bow_draw() -> void:
	_play_single(_sfx_bow, _bow_draw_sound)


func play_bow_shoot() -> void:
	_play_single(_sfx_bow, _bow_shoot_sound)


func stop_bow() -> void:
	if _sfx_bow and _sfx_bow.playing:
		_sfx_bow.stop()


func stop_fishing() -> void:
	if _sfx_fishing and _sfx_fishing.playing:
		_sfx_fishing.stop()


func _create_players(parent: Node) -> void:
	_sfx_footstep = _make_player(parent, -12.0)
	_sfx_sword    = _make_player(parent)
	_sfx_jump     = _make_player(parent, -4.0)
	_sfx_land     = _make_player(parent, -2.0)
	_sfx_roll     = _make_player(parent, -4.0)
	_sfx_tool     = _make_player(parent)
	_sfx_fishing  = _make_player(parent)
	_sfx_water    = _make_player(parent)
	_sfx_bow      = _make_player(parent)


func _make_player(parent: Node, volume_db: float = 0.0) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.bus = "Master"
	p.volume_db = volume_db
	p.max_distance = 500
	parent.add_child(p)
	return p


func _load_sounds() -> void:
	_footstep_sounds = _load_bank("res://Assets/Audio/SFX/Footsteps/step_%d.ogg", range(1, 5))
	_sword_sounds = _load_bank("res://Assets/Audio/SFX/Sword/sword_swing_%d.wav", range(1, 4))
	_roll_sounds = _load_bank("res://Assets/Audio/SFX/OGG/cloth%d.ogg", range(1, 5))
	_axe_chop_sounds = _load_bank("res://Assets/Audio/SFX/Tools/axe_chop_%d.ogg", range(1, 4))
	_pickaxe_hit_sounds = _load_bank("res://Assets/Audio/SFX/Tools/pickaxe_hit_%d.ogg", range(1, 4))
	_axe_swing_sounds = _load_bank("res://Assets/Audio/SFX/Weapons/swing_%d.wav", [5, 6, 7, 8, 9])
	_pickaxe_swing_sounds = _load_bank("res://Assets/Audio/SFX/Weapons/swing_light_%d.wav", range(1, 5))
	_tool_swing_sounds = _pickaxe_swing_sounds

	var js = load("res://Assets/Audio/SFX/Player/jump_grass.wav")
	if js:
		_jump_sounds.append(js)

	_land_sound = load("res://Assets/Audio/SFX/Player/jump_land.wav")
	_fish_cast_sound = load("res://Assets/Audio/SFX/Tools/fish_cast.wav")
	_fish_splash_sound = load("res://Assets/Audio/SFX/Tools/fish_splash.ogg")
	_fish_reel_sound = load("res://Assets/Audio/SFX/Tools/fish_reel.ogg")
	_water_pour_sound = load("res://Assets/Audio/SFX/Tools/water_pour.ogg")
	_bow_shoot_sound = load("res://Assets/Audio/SFX/Weapons/bow_shoot.ogg")
	_bow_draw_sound = load("res://Assets/Audio/SFX/Weapons/bow_draw.ogg")


func _load_bank(pattern: String, indices: Array) -> Array[AudioStream]:
	var bank: Array[AudioStream] = []
	for i in indices:
		var s = load(pattern % i)
		if s:
			bank.append(s)
	return bank


func _play_random(player: AudioStreamPlayer2D, bank: Array[AudioStream],
		volume_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	if bank.is_empty() or player == null:
		return
	player.stream = bank[randi() % bank.size()]
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	if volume_db != 0.0:
		player.volume_db = volume_db
	player.play()


func _play_single(player: AudioStreamPlayer2D, sound: AudioStream,
		volume_db: float = 0.0) -> void:
	if sound == null or player == null:
		return
	player.stream = sound
	player.pitch_scale = randf_range(0.95, 1.05)
	if volume_db != 0.0:
		player.volume_db = volume_db
	player.play()
