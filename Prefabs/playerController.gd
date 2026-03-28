extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
# Player Controller
# 8-directional movement, mouse-facing direction, dodge roll
# ─────────────────────────────────────────────────────────────────────────────

# ── Movement ──────────────────────────────────────────────────────────────────
@export var move_speed: float = 120.0

# ── Dodge ─────────────────────────────────────────────────────────────────────
@export var dodge_speed: float = 250.0
@export var dodge_duration: float = 0.4
@export var dodge_cooldown: float = 0.6

# ── Node references ───────────────────────────────────────────────────────────
@onready var anim_player: AnimationPlayer = $Character/AnimationPlayer

# ── State ─────────────────────────────────────────────────────────────────────
enum State { IDLE, MOVE, DODGE }
var state: State = State.IDLE

# The direction the character is facing — always follows the mouse
# Values: "down", "up", "left", "right"
var facing: String = "down"

# Dodge internals
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# Tick cooldown
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta

	# Update facing direction based on mouse position
	_update_facing()

	match state:
		State.IDLE:
			_state_idle(delta)
		State.MOVE:
			_state_move(delta)
		State.DODGE:
			_state_dodge(delta)


# ─────────────────────────────────────────────────────────────────────────────
# FACING — always tracks the mouse cursor
# ─────────────────────────────────────────────────────────────────────────────

func _update_facing() -> void:
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()

	# Pick the cardinal direction closest to the mouse angle
	# Compare absolute x vs y to decide horizontal vs vertical
	if abs(dir.x) > abs(dir.y):
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "down" if dir.y > 0 else "up"


# ─────────────────────────────────────────────────────────────────────────────
# STATES
# ─────────────────────────────────────────────────────────────────────────────

func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("idle_" + facing)

	# Transition: move
	var input_dir = _get_input_direction()
	if input_dir != Vector2.ZERO:
		state = State.MOVE
		return

	# Transition: dodge
	if _try_dodge():
		return

	move_and_slide()


func _state_move(_delta: float) -> void:
	var input_dir = _get_input_direction()

	if input_dir == Vector2.ZERO:
		state = State.IDLE
		return

	# Transition: dodge
	if _try_dodge():
		return

	velocity = input_dir * move_speed
	_play_anim("walk_" + facing)
	move_and_slide()


func _state_dodge(delta: float) -> void:
	dodge_timer -= delta

	if dodge_timer <= 0.0:
		# Dodge finished — return to idle or move
		var input_dir = _get_input_direction()
		if input_dir != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	velocity = dodge_direction * dodge_speed
	move_and_slide()


# ─────────────────────────────────────────────────────────────────────────────
# DODGE
# ─────────────────────────────────────────────────────────────────────────────

func _try_dodge() -> bool:
	if not Input.is_action_just_pressed("dodge"):
		return false
	if dodge_cooldown_timer > 0.0:
		return false

	state = State.DODGE
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown

	# Dodge in movement direction if moving, otherwise dodge in facing direction
	var input_dir = _get_input_direction()
	if input_dir != Vector2.ZERO:
		dodge_direction = input_dir
	else:
		dodge_direction = _facing_to_vector()

	# Roll animation matches the movement direction, not the mouse
	var roll_facing = _vector_to_direction(dodge_direction)
	_play_anim("roll_" + roll_facing, true)
	return true


func _vector_to_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"


func _facing_to_vector() -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.DOWN


# ─────────────────────────────────────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────────────────────────────────────

func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	# Normalize so diagonal movement isn't faster
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION
# ─────────────────────────────────────────────────────────────────────────────

func _play_anim(anim_name: String, force: bool = false) -> void:
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	if force or anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
