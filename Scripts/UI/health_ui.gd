extends CanvasLayer
## Polished heart-based health display with full / half / empty states.
##
## Each heart container represents 2 HP:
##   2 HP → full heart
##   1 HP → half heart (left half filled, right half empty)
##   0 HP → empty heart
##
## Features:
##   • Layered rendering: empty heart background + clipped full heart foreground
##   • Per-heart bounce on damage and healing
##   • Container shake on damage
##   • Smooth scale pop when gaining a new heart container
##   • Gentle idle bob so the HUD feels alive

const HP_PER_HEART: int = 2
const DISPLAY_SIZE: int = 32
const GAP: int = 4
const TOP_MARGIN: int = 14
const LEFT_MARGIN: int = 14

# Atlas regions on UI_Icons.png  (16×16 grid, row 0)
const FULL_HEART_RECT: Rect2 = Rect2(0, 0, 16, 16)
const EMPTY_HEART_RECT: Rect2 = Rect2(16, 0, 16, 16)

# --- Feedback tuning ---
const SHAKE_DURATION: float = 0.35
const SHAKE_INTENSITY: float = 5.0

const BOUNCE_DURATION: float = 0.30
const BOUNCE_SCALE_PEAK: float = 1.35
const BOUNCE_SCALE_DIP: float = 0.85

const HEAL_POP_DURATION: float = 0.35
const HEAL_POP_SCALE: float = 1.4

const IDLE_BOB_SPEED: float = 1.8
const IDLE_BOB_AMOUNT: float = 1.5

const EMPTY_TINT: Color = Color(0.25, 0.20, 0.22, 0.85)  # Dark, fully readable outline
const HALF_BG_TINT: Color = Color(0.55, 0.45, 0.45, 0.95) # Brighter so the right half reads as "lost"
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.2, 0.2, 1.0)

# ── Textures ──────────────────────────────────────────────────────────────
var _icons_texture: Texture2D
var _full_heart_tex: AtlasTexture
var _empty_heart_tex: AtlasTexture

# ── Scene tree refs ───────────────────────────────────────────────────────
var _root: Control
var _container: HBoxContainer

# Per-heart data  (parallel arrays, one entry per heart container)
var _heart_slots: Array[Control] = []        # outer fixed-size wrapper
var _bg_icons: Array[TextureRect] = []       # empty heart (always visible)
var _fg_clips: Array[Control] = []           # clip container for full heart
var _fg_icons: Array[TextureRect] = []       # full heart texture

# State
var _max_hearts: int = 5
var _current_hp: int = 10  # 5 hearts × 2 HP

# Shake
var _shake_timer: float = 0.0
var _original_position: Vector2 = Vector2.ZERO

# Per-heart animation timers
var _bounce_timers: Array[float] = []
var _bounce_directions: Array[int] = []  # -1 = damage bounce, +1 = heal pop
var _flash_timers: Array[float] = []

# Idle bob
var _time: float = 0.0


# ══════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_textures()
	_build_ui()
	call_deferred("_connect_health_system")


func _process(delta: float) -> void:
	_time += delta
	_process_shake(delta)
	_process_bounces(delta)
	_process_flashes(delta)
	_process_idle_bob()


# ══════════════════════════════════════════════════════════════════════════
#  TEXTURE SETUP
# ══════════════════════════════════════════════════════════════════════════

func _load_textures() -> void:
	_icons_texture = load("res://Assets/Cute_Fantasy_UI/UI/UI_Icons.png")

	_full_heart_tex = AtlasTexture.new()
	_full_heart_tex.atlas = _icons_texture
	_full_heart_tex.region = FULL_HEART_RECT

	_empty_heart_tex = AtlasTexture.new()
	_empty_heart_tex.atlas = _icons_texture
	_empty_heart_tex.region = EMPTY_HEART_RECT


# ══════════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_container = HBoxContainer.new()
	_container.position = Vector2(LEFT_MARGIN, TOP_MARGIN)
	_container.add_theme_constant_override("separation", GAP)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_container)
	_original_position = _container.position

	_rebuild_hearts()


func _rebuild_hearts() -> void:
	# Clear old hearts
	for slot in _heart_slots:
		slot.queue_free()
	_heart_slots.clear()
	_bg_icons.clear()
	_fg_clips.clear()
	_fg_icons.clear()
	_bounce_timers.clear()
	_bounce_directions.clear()
	_flash_timers.clear()

	for i in range(_max_hearts):
		# Outer slot — fixed size, used for scale/position animation
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.pivot_offset = Vector2(DISPLAY_SIZE * 0.5, DISPLAY_SIZE * 0.5)
		_container.add_child(slot)
		_heart_slots.append(slot)

		# Background: empty heart (always visible)
		var bg := _make_heart_rect(_empty_heart_tex)
		bg.modulate = EMPTY_TINT
		slot.add_child(bg)
		_bg_icons.append(bg)

		# Foreground clip container — its width controls how much of the
		# full heart is visible (full width = full heart, half = half heart)
		var clip := Control.new()
		clip.clip_contents = true
		clip.size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(clip)
		_fg_clips.append(clip)

		# Foreground: full heart inside the clip
		var fg := _make_heart_rect(_full_heart_tex)
		fg.modulate = Color.WHITE
		clip.add_child(fg)
		_fg_icons.append(fg)

		_bounce_timers.append(0.0)
		_bounce_directions.append(0)
		_flash_timers.append(0.0)

	_refresh_display()


func _make_heart_rect(tex: AtlasTexture) -> TextureRect:
	var heart_rect := TextureRect.new()
	heart_rect.texture = tex
	heart_rect.custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	heart_rect.size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	heart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heart_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return heart_rect


# ══════════════════════════════════════════════════════════════════════════
#  DISPLAY REFRESH
# ══════════════════════════════════════════════════════════════════════════

func _refresh_display() -> void:
	for i in range(_heart_slots.size()):
		_refresh_heart(i)


func _refresh_heart(index: int) -> void:
	var hp_in_this_heart := clampi(_current_hp - index * HP_PER_HEART, 0, HP_PER_HEART)
	var fg_icon := _fg_icons[index]
	var fg_clip := _fg_clips[index]
	var bg_icon := _bg_icons[index]

	# Always reset modulate so a stale damage flash can never linger.
	fg_icon.modulate = Color.WHITE

	if hp_in_this_heart == HP_PER_HEART:
		# Full heart — show the whole foreground
		fg_clip.size.x = DISPLAY_SIZE
		fg_icon.visible = true
		bg_icon.modulate = EMPTY_TINT
	elif hp_in_this_heart == 1:
		# Half heart — show left half of the full heart over the empty bg
		fg_clip.size.x = DISPLAY_SIZE * 0.5
		fg_icon.visible = true
		bg_icon.modulate = HALF_BG_TINT
	else:
		# Empty heart — completely hide the foreground and clear any flash.
		fg_clip.size.x = 0
		fg_icon.visible = false
		_flash_timers[index] = 0.0
		bg_icon.modulate = EMPTY_TINT


# ══════════════════════════════════════════════════════════════════════════
#  ANIMATIONS
# ══════════════════════════════════════════════════════════════════════════

func _process_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		return
	_shake_timer -= delta
	var t := _shake_timer / SHAKE_DURATION
	# Ease out: intensity fades over time
	var intensity := SHAKE_INTENSITY * t * t
	_container.position = _original_position + Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
	if _shake_timer <= 0.0:
		_container.position = _original_position


func _process_bounces(delta: float) -> void:
	for i in range(_bounce_timers.size()):
		if _bounce_timers[i] <= 0.0:
			continue
		_bounce_timers[i] -= delta

		var duration := BOUNCE_DURATION if _bounce_directions[i] < 0 else HEAL_POP_DURATION
		var t := 1.0 - (_bounce_timers[i] / duration)  # 0 → 1
		var s: float

		if _bounce_directions[i] < 0:
			# Damage: quick squish then bounce back
			if t < 0.3:
				s = lerpf(1.0, BOUNCE_SCALE_DIP, t / 0.3)
			elif t < 0.6:
				s = lerpf(BOUNCE_SCALE_DIP, BOUNCE_SCALE_PEAK, (t - 0.3) / 0.3)
			else:
				s = lerpf(BOUNCE_SCALE_PEAK, 1.0, (t - 0.6) / 0.4)
		else:
			# Heal: pop up then settle
			if t < 0.4:
				s = lerpf(1.0, HEAL_POP_SCALE, t / 0.4)
			else:
				s = lerpf(HEAL_POP_SCALE, 1.0, (t - 0.4) / 0.6)

		_heart_slots[i].scale = Vector2(s, s)

		if _bounce_timers[i] <= 0.0:
			_heart_slots[i].scale = Vector2.ONE


func _process_flashes(delta: float) -> void:
	for i in range(_flash_timers.size()):
		if _flash_timers[i] <= 0.0:
			continue
		_flash_timers[i] -= delta
		# Don't tint a hidden foreground — that's how a "ghost" half-heart
		# can appear after a heart is supposed to be empty.
		if _fg_icons[i].visible:
			var t := _flash_timers[i] / BOUNCE_DURATION
			_fg_icons[i].modulate = Color.WHITE.lerp(DAMAGE_FLASH_COLOR, t)
		if _flash_timers[i] <= 0.0:
			_refresh_heart(i)


func _process_idle_bob() -> void:
	for i in range(_heart_slots.size()):
		if _bounce_timers[i] > 0.0:
			continue  # Don't bob while bouncing
		# Stagger each heart's bob phase so they wave
		var phase := _time * IDLE_BOB_SPEED + i * 0.6
		var offset_y := sin(phase) * IDLE_BOB_AMOUNT
		_heart_slots[i].position.y = offset_y


# ══════════════════════════════════════════════════════════════════════════
#  SIGNAL CALLBACKS
# ══════════════════════════════════════════════════════════════════════════

func _connect_health_system() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var player := players[0]
	var health := player.get_node_or_null("HealthSystem")
	if health == null:
		return

	health.health_changed.connect(_on_health_changed)
	health.damage_taken.connect(_on_damage_taken)
	_max_hearts = health.max_hearts
	_current_hp = health.get_current_hp()
	_rebuild_hearts()


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	var old_hp := _current_hp
	var old_max_hearts := _max_hearts
	@warning_ignore("integer_division")
	_max_hearts = max_hp / HP_PER_HEART
	_current_hp = current_hp

	if _heart_slots.size() != _max_hearts:
		_rebuild_hearts()
		# Pop in newly added hearts
		for i in range(old_max_hearts, _max_hearts):
			if i < _heart_slots.size():
				_bounce_timers[i] = HEAL_POP_DURATION
				_bounce_directions[i] = 1
				_heart_slots[i].scale = Vector2(0.3, 0.3)
		return

	if current_hp < old_hp:
		# Damage — figure out which hearts were affected
		var old_heart := _hp_to_last_heart(old_hp)
		var new_heart := _hp_to_last_heart(current_hp)
		for i in range(maxi(new_heart, 0), mini(old_heart + 1, _max_hearts)):
			_bounce_timers[i] = BOUNCE_DURATION
			_bounce_directions[i] = -1
			_flash_timers[i] = BOUNCE_DURATION
	elif current_hp > old_hp:
		# Healing — pop hearts that gained HP
		var old_heart := _hp_to_last_heart(old_hp)
		var new_heart := _hp_to_last_heart(current_hp)
		for i in range(maxi(old_heart, 0), mini(new_heart + 1, _max_hearts)):
			_bounce_timers[i] = HEAL_POP_DURATION
			_bounce_directions[i] = 1

	_refresh_display()


func _on_damage_taken(_amount: int) -> void:
	_shake_timer = SHAKE_DURATION


## Returns the index of the heart that contains the given HP value.
func _hp_to_last_heart(hp: int) -> int:
	if hp <= 0:
		return -1
	@warning_ignore("integer_division")
	return (hp - 1) / HP_PER_HEART
