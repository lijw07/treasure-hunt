extends CanvasLayer
## Draws Zelda-style heart containers in the top-left corner using
## sprites from the Cute Fantasy UI icon sheet.
##
## Listens for health_changed signals from the player's HealthSystem node.

const HEART_SIZE: int = 16  # Pixel size of each heart icon on the atlas
const DISPLAY_SIZE: int = 32  # Rendered size on screen
const PADDING: int = 8
const GAP: int = 2
const TOP_MARGIN: int = 12
const LEFT_MARGIN: int = 12
const HEARTS_PER_ROW: int = 10

# Atlas regions on UI_Icons.png  (16x16 grid, row 0)
# Full heart: red at (0, 0)
# Empty heart: outlined at (16, 0) — dimmed red heart silhouette
const FULL_HEART_RECT: Rect2 = Rect2(0, 0, 16, 16)
const EMPTY_HEART_RECT: Rect2 = Rect2(16, 0, 16, 16)

var _icons_texture: Texture2D
var _full_heart_tex: AtlasTexture
var _empty_heart_tex: AtlasTexture

var _container: HBoxContainer
var _heart_icons: Array[TextureRect] = []
var _root: Control

var _max_hearts: int = 5
var _current_half_hearts: int = 10

# Damage feedback
var _shake_timer: float = 0.0
var _shake_intensity: float = 3.0
var _original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_load_textures()
	_build_ui()
	# Defer connection so the player scene is ready
	call_deferred("_connect_health_system")


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_container.position = _original_position + shake_offset
		if _shake_timer <= 0.0:
			_container.position = _original_position


func _load_textures() -> void:
	_icons_texture = load("res://Assets/Cute_Fantasy_UI/UI/UI_Icons.png")

	_full_heart_tex = AtlasTexture.new()
	_full_heart_tex.atlas = _icons_texture
	_full_heart_tex.region = FULL_HEART_RECT

	_empty_heart_tex = AtlasTexture.new()
	_empty_heart_tex.atlas = _icons_texture
	_empty_heart_tex.region = EMPTY_HEART_RECT


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
	# Remove old icons
	for icon in _heart_icons:
		icon.queue_free()
	_heart_icons.clear()

	for i in range(_max_hearts):
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.add_child(tex_rect)
		_heart_icons.append(tex_rect)

	_refresh_display()


func _refresh_display() -> void:
	for i in range(_heart_icons.size()):
		var icon = _heart_icons[i]
		var heart_hp = clampi(_current_half_hearts - i * 2, 0, 2)

		if heart_hp >= 2:
			# Full heart
			icon.texture = _full_heart_tex
			icon.modulate = Color.WHITE
		elif heart_hp == 1:
			# Half heart — show full heart icon tinted to indicate partial
			icon.texture = _full_heart_tex
			icon.modulate = Color(1.0, 0.6, 0.6, 1.0)
		else:
			# Empty heart
			icon.texture = _empty_heart_tex
			icon.modulate = Color(0.4, 0.4, 0.4, 0.8)


func _connect_health_system() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var player = players[0]
	var health = player.get_node_or_null("HealthSystem")
	if health == null:
		return

	health.health_changed.connect(_on_health_changed)
	health.damage_taken.connect(_on_damage_taken)
	# Initialise display from current health
	_max_hearts = health.max_hearts
	_current_half_hearts = health.get_current_hp()
	_rebuild_hearts()


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	@warning_ignore("integer_division")
	_max_hearts = max_hp / 2
	_current_half_hearts = current_hp
	if _heart_icons.size() != _max_hearts:
		_rebuild_hearts()
	else:
		_refresh_display()


func _on_damage_taken(_amount: int) -> void:
	# Shake the hearts briefly
	_shake_timer = 0.25
	_shake_intensity = 3.0
