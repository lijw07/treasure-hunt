extends Node2D

@export var arrow_scene: PackedScene
@export var cooldown: float = 0.5

var cooldown_timer: float = 0.0
var _sprite: Sprite2D

# Frame offsets in the bow sprite sheet (6 cols x 3 rows)
# Row 0 (frames 0-5): down, Row 1 (frames 6-11): side, Row 2 (frames 12-17): up
const FRAME_OFFSET: Dictionary = {"down": 0, "left": 6, "right": 6, "up": 12}


func _ready() -> void:
	if arrow_scene == null:
		var path = "res://Prefabs/Weapons/arrow.tscn"
		if ResourceLoader.exists(path):
			arrow_scene = load(path)

	# Create bow sprite child so it renders when visible
	_sprite = Sprite2D.new()
	var tex_path = "res://Assets/Cute_Fantasy/Player/Tools/Bow/Wooden_Bow.png"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	_sprite.hframes = 6
	_sprite.vframes = 3
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Sync bow sprite frame with the animation
	if visible and _sprite != null:
		_sync_sprite()


func _sync_sprite() -> void:
	var player = _get_player()
	if player == null:
		return

	var dir: String = player.facing if "facing" in player else "down"
	var base_frame: int = FRAME_OFFSET.get(dir, 0)

	_sprite.flip_h = (dir == "left")

	# Check if bow is in charge state (hold the draw frame)
	var is_charging: bool = false
	if "_bow_charging" in player:
		is_charging = player._bow_charging

	if is_charging:
		# Show the fully-drawn bow (frame 2) without the arrow released
		_sprite.frame = base_frame + 2
		return

	# Get animation progress from AnimationPlayer to sync bow frame
	var anim_player: AnimationPlayer = player.get_node_or_null("Character/AnimationPlayer")
	if anim_player and anim_player.is_playing():
		var pos: float = anim_player.current_animation_position
		var frame_index: int = int(pos / 0.1)
		frame_index = clampi(frame_index, 0, 5)
		_sprite.frame = base_frame + frame_index
	else:
		# Default to first frame of the direction
		_sprite.frame = base_frame


func shoot() -> void:
	if arrow_scene == null:
		return
	if cooldown_timer > 0.0:
		return

	cooldown_timer = cooldown

	var player = _get_player()
	var dir: String = "down"
	if player and "facing" in player:
		dir = player.facing

	var arrow = arrow_scene.instantiate()
	arrow.global_position = global_position
	arrow.setup(dir)
	get_tree().current_scene.add_child(arrow)


func _get_player() -> Node:
	var node = get_parent()
	while node != null:
		if node is CharacterBody2D:
			return node
		node = node.get_parent()
	return null
