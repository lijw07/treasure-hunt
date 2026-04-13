class_name AnimalBase
extends CharacterBody2D
## Base script for all wandering animals.
## Attach to a CharacterBody2D that has:
##   - Node2D/Sprite  (Sprite2D with hframes/vframes)
##   - Node2D/AnimationPlayer
##   - CollisionShape2D
##   - AudioStreamPlayer2D  (optional, for ambient SFX)

@export_group("Movement")
@export var move_speed: float = 20.0
@export var wander_radius: float = 48.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 6.0
@export var walk_time_min: float = 1.0
@export var walk_time_max: float = 3.0

@export_group("Audio")
@export var ambient_sound: AudioStream
@export var ambient_interval_min: float = 15.0
@export var ambient_interval_max: float = 35.0
@export var footstep_sound: AudioStream
@export var footstep_interval: float = 0.35

enum State { IDLE, WALKING }

var _state: State = State.IDLE
var _timer: float = 0.0
var _walk_direction: Vector2 = Vector2.ZERO
var _spawn_position: Vector2 = Vector2.ZERO
var _audio_timer: float = 0.0
var _footstep_timer: float = 0.0

@onready var _anim_player: AnimationPlayer = $Node2D/AnimationPlayer
@onready var _sprite: Sprite2D = $Node2D/Sprite
@onready var _audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer if has_node("FootstepPlayer") else null


func _ready() -> void:
	_spawn_position = global_position
	_enter_idle()
	_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_enter_walk()
		State.WALKING:
			_timer -= delta
			velocity = _walk_direction * move_speed
			move_and_slide()
			# If we collided with something, pick a new direction
			if get_slide_collision_count() > 0:
				_walk_direction = -_walk_direction.rotated(randf_range(-PI / 2, PI / 2))
				_play_directional_anim("walk")
			# Stay within wander radius
			if global_position.distance_to(_spawn_position) > wander_radius:
				_walk_direction = (_spawn_position - global_position).normalized()
				_play_directional_anim("walk")
			if _timer <= 0.0:
				_enter_idle()

	# Footstep audio while walking
	if _footstep_player and footstep_sound and _state == State.WALKING:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_player.stream = footstep_sound
			_footstep_player.pitch_scale = randf_range(0.9, 1.1)
			_footstep_player.play()
			_footstep_timer = footstep_interval

	# Ambient audio
	if _audio_player and ambient_sound:
		_audio_timer -= delta
		if _audio_timer <= 0.0:
			_audio_player.stream = ambient_sound
			_audio_player.play()
			_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)


func _enter_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(idle_time_min, idle_time_max)
	velocity = Vector2.ZERO
	_play_directional_anim("idle")


func _enter_walk() -> void:
	_state = State.WALKING
	_timer = randf_range(walk_time_min, walk_time_max)
	var angle = randf() * TAU
	_walk_direction = Vector2(cos(angle), sin(angle)).normalized()
	# Bias back toward spawn if far away
	if global_position.distance_to(_spawn_position) > wander_radius * 0.6:
		_walk_direction = (_spawn_position - global_position).normalized().rotated(randf_range(-0.5, 0.5))
	_play_directional_anim("walk")


func _play_directional_anim(base_name: String) -> void:
	var dir := _walk_direction if _state == State.WALKING else _walk_direction
	var suffix := _direction_suffix(dir)
	var anim_name := base_name + "_" + suffix

	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
	elif _anim_player.has_animation(base_name + "_down"):
		_anim_player.play(base_name + "_down")
	elif _anim_player.has_animation(base_name):
		_anim_player.play(base_name)
	elif _anim_player.has_animation("idle_down"):
		_anim_player.play("idle_down")


func _direction_suffix(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "down"
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"
