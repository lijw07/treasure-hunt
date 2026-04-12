extends CharacterBody2D

@export var move_speed: float = 120.0
@export var dodge_speed: float = 140.0
@export var dodge_duration: float = 0.5
@export var dodge_cooldown: float = 0.4
@export var jump_duration: float = 0.35
@export var jump_move_factor: float = 0.25

enum State { IDLE, MOVE, DODGE, JUMP }
var state: State = State.IDLE
var facing: String = "down"
var dodge_facing: String = "down"
var invincible: bool = false

var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _jump_timer: float = 0.0
var _jump_direction: Vector2 = Vector2.ZERO
var _jump_start_speed: float = 0.0
var _input_mgr: Node
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _player_hitbox: CollisionShape2D


func _ready() -> void:
	_input_mgr = get_node_or_null("/root/InputManager")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	_player_hitbox = get_node_or_null("PlayerHitbox")


func _physics_process(delta: float) -> void:
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta

	_update_facing()

	match state:
		State.IDLE:
			_state_idle()
		State.MOVE:
			_state_move()
		State.DODGE:
			_state_dodge(delta)
		State.JUMP:
			_state_jump(delta)


func _update_facing() -> void:
	var diff := get_global_mouse_position() - global_position

	if _input_mgr:
		diff *= _input_mgr.mouse_sensitivity
		if _input_mgr.mouse_inverted:
			diff.y = -diff.y

	if abs(diff.x) > abs(diff.y):
		facing = "right" if diff.x > 0 else "left"
	else:
		facing = "up" if diff.y < 0 else "down"


func _state_idle() -> void:
	velocity = Vector2.ZERO

	if _try_dodge():
		return
	if _try_jump():
		return
	if _get_input_direction() != Vector2.ZERO:
		state = State.MOVE
		return

	move_and_slide()


func _state_move() -> void:
	if _try_dodge():
		return
	if _try_jump():
		return

	var input_dir = _get_input_direction()

	if input_dir == Vector2.ZERO:
		state = State.IDLE
		return

	velocity = input_dir * move_speed
	move_and_slide()


func _state_dodge(delta: float) -> void:
	_dodge_timer -= delta

	if _dodge_timer <= 0.0:
		invincible = false
		_set_hit_collision(true)
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	velocity = _dodge_direction * dodge_speed
	move_and_slide()


func _state_jump(delta: float) -> void:
	_jump_timer -= delta

	if _jump_timer <= 0.0:
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	var progress: float = 1.0 - (_jump_timer / jump_duration)
	var curve: float = 1.0 - sin(progress * PI)
	var current_speed: float = lerpf(_jump_start_speed * jump_move_factor, _jump_start_speed, curve)
	velocity = _jump_direction * current_speed
	move_and_slide()


func _try_dodge() -> bool:
	if not Input.is_action_just_pressed("dodge"):
		return false
	if _dodge_cooldown_timer > 0.0:
		return false

	state = State.DODGE
	invincible = true
	_set_hit_collision(false)
	_dodge_timer = dodge_duration
	_dodge_cooldown_timer = dodge_cooldown

	var input_dir = _get_input_direction()
	if input_dir != Vector2.ZERO:
		_dodge_direction = input_dir
	else:
		_dodge_direction = _facing_to_vector()

	if abs(_dodge_direction.x) > abs(_dodge_direction.y):
		dodge_facing = "right" if _dodge_direction.x > 0 else "left"
	else:
		dodge_facing = "up" if _dodge_direction.y < 0 else "down"

	return true


func _try_jump() -> bool:
	if not Input.is_action_just_pressed("jump"):
		return false

	state = State.JUMP
	_jump_timer = jump_duration
	_jump_direction = _get_input_direction()
	_jump_start_speed = velocity.length() if velocity.length() > 0.0 else move_speed
	return true


func _facing_to_vector() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _set_hit_collision(enabled: bool) -> void:
	if enabled:
		collision_layer = _base_collision_layer
		collision_mask = _base_collision_mask
	else:
		collision_layer = 0
		collision_mask = 0
	if _player_hitbox:
		_player_hitbox.disabled = not enabled
