class_name FlyingAnimal
extends CharacterBody2D
## Script for flying/hovering creatures like Bees and Butterflies.
## Uses CharacterBody2D for proper collision with the world.
## Applies sinusoidal hover to the sprite for a floating feel.

@export_group("Movement")
@export var move_speed: float = 15.0
@export var wander_radius: float = 40.0
@export var hover_amplitude: float = 3.0
@export var hover_frequency: float = 2.0
@export var direction_change_min: float = 1.5
@export var direction_change_max: float = 4.0

@export_group("Audio")
@export var ambient_sound: AudioStream
@export var ambient_interval_min: float = 18.0
@export var ambient_interval_max: float = 40.0
@export var flying_sound: AudioStream
@export var flying_sound_interval: float = 1.2

var _direction: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _time: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO
var _audio_timer: float = 0.0
var _flying_sound_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite if has_node("Sprite") else null
@onready var _audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null
@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var _flying_player: AudioStreamPlayer2D = $FlyingSoundPlayer if has_node("FlyingSoundPlayer") else null


func _ready() -> void:
	_spawn_position = global_position
	_pick_new_direction()
	_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)
	# Pick a random fly animation variant if multiple exist (e.g. fly_blue, fly_green...)
	if _anim_player:
		var fly_anims: Array[String] = []
		for anim_name in _anim_player.get_animation_list():
			if anim_name.begins_with("fly"):
				fly_anims.append(anim_name)
		if fly_anims.size() > 0:
			_anim_player.play(fly_anims[randi() % fly_anims.size()])
		elif _anim_player.has_animation("fly"):
			_anim_player.play("fly")


func _physics_process(delta: float) -> void:
	_time += delta
	_timer -= delta

	# Move using CharacterBody2D physics
	velocity = _direction * move_speed
	move_and_slide()

	# If we hit something, bounce off
	if get_slide_collision_count() > 0:
		_direction = -_direction.rotated(randf_range(-PI / 2, PI / 2))

	# Hover offset on sprite only (visual, not physics)
	var hover_offset := sin(_time * hover_frequency * TAU) * hover_amplitude
	if _sprite:
		_sprite.position.y = hover_offset

	# Stay in wander radius
	if global_position.distance_to(_spawn_position) > wander_radius:
		_direction = (_spawn_position - global_position).normalized()

	if _timer <= 0.0:
		_pick_new_direction()

	# Flip sprite based on direction
	if _sprite and _direction.x != 0:
		_sprite.flip_h = _direction.x < 0

	# Flying sound (continuous buzz/flutter)
	if _flying_player and flying_sound:
		_flying_sound_timer -= delta
		if _flying_sound_timer <= 0.0:
			_flying_player.stream = flying_sound
			_flying_player.pitch_scale = randf_range(0.95, 1.05)
			_flying_player.play()
			_flying_sound_timer = flying_sound_interval

	# Audio
	if _audio_player and ambient_sound:
		_audio_timer -= delta
		if _audio_timer <= 0.0:
			_audio_player.stream = ambient_sound
			_audio_player.play()
			_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)


func _pick_new_direction() -> void:
	var angle = randf() * TAU
	_direction = Vector2(cos(angle), sin(angle)).normalized()
	if global_position.distance_to(_spawn_position) > wander_radius * 0.5:
		_direction = (_spawn_position - global_position).normalized().rotated(randf_range(-0.8, 0.8))
	_timer = randf_range(direction_change_min, direction_change_max)
