extends Node2D
## Drives the animated main-menu backdrop:
##   • uniform wind sway on every OakTree (all lean the same direction)
##   • drifting Wind_Anim sprite-sheet particles
##   • leaf particles blowing with the wind
##   • scattered animated flower patches
##   • NPCs that follow the scene's Path2D and loop

# ─── NPC config ─────────────────────────────────────────────────────
const NPC_TEXTURES := [
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Bartender_Bruno.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Bartender_Katy.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Chef_Chloe.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Farmer_Bob.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Farmer_Buba.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Lumberjack_Jack.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Miner_Mike.png",
]
const NPC_HFRAMES      := 6
const NPC_WALK_DOWN_S  := 18       # walk_down: row 3, frames 18-23
const NPC_WALK_SIDE_S  := 24       # walk_side: row 4, frames 24-29
const NPC_WALK_UP_S    := 30       # walk_up:   row 5, frames 30-35
const NPC_WALK_FRAMES  := 6        # frames per walk animation
const NPC_ANIM_FPS    := 10.0
const NPC_SPEED_MIN   := 18.0      # pixels/sec along the path
const NPC_SPEED_MAX   := 30.0
const NPC_COUNT       := 4

# ─── Wind particle config ──────────────────────────────────────────
const WIND_HFRAMES    := 14        # 224 / 16
const WIND_ANIM_FPS   := 12.0
const WIND_COUNT      := 14
const WIND_SPEED_MIN  := 30.0
const WIND_SPEED_MAX  := 55.0
const WIND_X_LEFT     := -220.0
const WIND_X_RIGHT    := 280.0
const WIND_Y_MIN      := -120.0
const WIND_Y_MAX      := 70.0

# ─── Leaf particle config ──────────────────────────────────────────
const LEAF_COUNT      := 12
const LEAF_SPEED_MIN  := 20.0
const LEAF_SPEED_MAX  := 40.0
const LEAF_FALL_MIN   := 8.0       # downward drift
const LEAF_FALL_MAX   := 18.0
const LEAF_SPIN_MIN   := 1.5       # radians/sec rotation
const LEAF_SPIN_MAX   := 4.0
const LEAF_TEXTURES   := [
	"res://Assets/Cute_Fantasy/Trees/Oak_Leaf_Particle.png",
	"res://Assets/Cute_Fantasy/Trees/Birch_Leaf_Particle.png",
]

# ─── Flower config ──────────────────────────────────────────────────
const FLOWER_GRASS_TEXTURES := [
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Grass_Animations/Flower_Grass_1_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Grass_Animations/Flower_Grass_4_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Grass_Animations/Flower_Grass_5_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Grass_Animations/Flower_Grass_6_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Grass_Animations/Flower_Grass_7_Anim.png",
]
const FLOWER_ANIM_TEXTURES := [
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/Flowers_1_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/Flowers_2_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/Flowers_3_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/Flowers_4_Anim.png",
	"res://Assets/Cute_Fantasy/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/Flowers_5_Anim.png",
]
const FLOWER_GRASS_COUNT  := 30      # small 16×16 animated patches
const FLOWER_ANIM_COUNT   := 15      # larger animated flowers
const FLOWER_GRASS_FPS    := 6.0
const FLOWER_ANIM_FPS     := 6.0
const FLOWER_X_MIN        := -180.0
const FLOWER_X_MAX        := 260.0
const FLOWER_Y_MIN        := -120.0
const FLOWER_Y_MAX        := 85.0
const FLOWER_TREE_DIST    := 18.0    # min distance from a tree trunk
const FLOWER_ROCK_DIST    := 14.0    # min distance from a rock
const FLOWER_ROAD_DIST    := 12.0    # min distance from the road path
const FLOWER_MAX_ATTEMPTS := 40      # random attempts before giving up on one flower

# ─── Tree sway config (uniform wind direction) ─────────────────────
const SWAY_DEG        := 0.8       # subtle lean amount (degrees)
const SWAY_PERIOD     := 3.0       # seconds per sway cycle
const GUST_DEG        := 2.0       # stronger gust lean
const GUST_INTERVAL   := 5.0       # average seconds between gusts

# ─── Occlusion / depth config ──────────────────────────────────────
const OCCLUDE_NEAR_X  := 28.0      # horizontal range to count as "behind"
const OCCLUDE_Y_RANGE := 28.0      # how far above the tree an NPC can be and still occlude
const FADE_RADIUS     := 20.0      # world-pixel radius of the soft fade circle
const FADE_ALPHA      := 0.25      # minimum alpha at the centre
const Z_BASE          := 1000      # baseline for Y-based z_index

# ─── Runtime state ──────────────────────────────────────────────────
var _npc_walkers : Array[Dictionary] = []
var _wind_sprites : Array[Dictionary] = []
var _leaf_sprites : Array[Dictionary] = []
var _flower_sprites : Array[Dictionary] = []
var _tree_nodes : Array[Dictionary] = []  # { "root": Node2D, "sprite": Sprite2D, "original_mat": Material }
var _tree_sprites : Array[Node] = []      # kept for sway tweens (Sprite2D refs)
var _obstacle_trees : Array[Vector2] = [] # tree positions for flower exclusion
var _obstacle_rocks : Array[Vector2] = [] # rock positions for flower exclusion
var _road_points : Array[Vector2] = []    # sampled path points for flower exclusion
var _path : Path2D = null
var _wind_tex : Texture2D
var _leaf_textures : Array[Texture2D] = []
var _occlusion_shader : Shader
var _gust_timer := 0.0
var _next_gust := 0.0
var _anim_clock := 0.0


func _ready() -> void:
	_wind_tex = load("res://Assets/Cute_Fantasy/Weather effects/Wind_Anim.png")
	_occlusion_shader = load("res://Shaders/occlusion_fade.gdshader")
	for path in LEAF_TEXTURES:
		_leaf_textures.append(load(path))

	# Find the Path2D already placed in the scene
	for child in get_children():
		if child is Path2D:
			_path = child
			break

	_collect_trees()
	_collect_obstacles()
	_start_tree_sway()
	_spawn_wind_particles()
	_spawn_leaf_particles()
	_spawn_flowers()
	_spawn_npc_walkers()
	_next_gust = randf_range(GUST_INTERVAL * 0.5, GUST_INTERVAL * 1.5)


func _process(delta: float) -> void:
	_anim_clock += delta
	_update_npc_walkers(delta)
	_update_depth_sorting()
	_update_occlusion()
	_update_wind_particles(delta)
	_update_leaf_particles(delta)
	_update_flowers(delta)
	_update_gusts(delta)


# ═════════════════════════════════════════════════════════════════════
#  TREE WIND SWAY — all trees lean the same direction
# ═════════════════════════════════════════════════════════════════════

func _collect_trees() -> void:
	for child in get_children():
		if child is Node2D and child.scene_file_path == "res://Prefabs/Tree/OakTree.tscn":
			var sprite := child.get_node_or_null("Sprite2D")
			if sprite:
				_tree_sprites.append(sprite)
				_tree_nodes.append({
					"root": child,
					"sprite": sprite,
					"original_mat": sprite.material,
				})


## Gather obstacle positions from scene children and sample the road path.
func _collect_obstacles() -> void:
	# Trees (OakTree instances)
	for t in _tree_nodes:
		var root : Node2D = t["root"]
		if is_instance_valid(root):
			_obstacle_trees.append(root.position)

	# Rocks and grass decorations — anything that isn't a tree, path, camera, or UI
	for child in get_children():
		if child is Node2D and child != _path:
			var scene_path := child.scene_file_path
			# Rocks (RockAnimation)
			if scene_path == "res://Prefabs/RockAnimation/animated_sprite_2d.tscn":
				_obstacle_rocks.append(child.position)
			# Grass animations also count as obstacles
			elif (scene_path == "res://Prefabs/GrassAnimation/GrassAnimation2.tscn"
				or scene_path == "res://Prefabs/GrassAnimation/GrassAnimation3.tscn"):
				_obstacle_rocks.append(child.position)

	# Sample the road (Path2D curve) at regular intervals
	if _path and _path.curve:
		var curve := _path.curve
		var length := curve.get_baked_length()
		var step := 6.0  # sample every 6 pixels
		var dist := 0.0
		while dist <= length:
			_road_points.append(curve.sample_baked(dist))
			dist += step


## Check if a candidate position is clear of all obstacles.
func _is_flower_position_valid(pos: Vector2) -> bool:
	for t in _obstacle_trees:
		if pos.distance_to(t) < FLOWER_TREE_DIST:
			return false
	for r in _obstacle_rocks:
		if pos.distance_to(r) < FLOWER_ROCK_DIST:
			return false
	for rp in _road_points:
		if pos.distance_to(rp) < FLOWER_ROAD_DIST:
			return false
	return true


## Try to find a valid position for a flower (returns null Vector2 if failed).
func _find_flower_position() -> Vector2:
	for _attempt in range(FLOWER_MAX_ATTEMPTS):
		var candidate := Vector2(
			randf_range(FLOWER_X_MIN, FLOWER_X_MAX),
			randf_range(FLOWER_Y_MIN, FLOWER_Y_MAX))
		if _is_flower_position_valid(candidate):
			return candidate
	return Vector2(INF, INF)  # sentinel: no valid spot found


func _start_tree_sway() -> void:
	for sprite in _tree_sprites:
		# All trees sway together in the same direction (wind blowing right).
		# Small random offset so they aren't perfectly synchronised.
		var delay := randf_range(0.0, 0.4)
		_sway_loop(sprite, delay)


func _sway_loop(sprite: Node, delay: float) -> void:
	if not is_instance_valid(sprite):
		return
	var half := SWAY_PERIOD * 0.5
	var angle := deg_to_rad(SWAY_DEG)
	# Start at a slight lean to the right (wind direction)
	var tw := create_tween().set_loops()
	tw.tween_interval(delay)
	# Lean right (wind direction)
	tw.tween_property(sprite, "rotation", angle, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Return to near-center, but still slightly right
	tw.tween_property(sprite, "rotation", angle * 0.2, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _update_gusts(delta: float) -> void:
	_gust_timer += delta
	if _gust_timer < _next_gust:
		return
	_gust_timer = 0.0
	_next_gust = randf_range(GUST_INTERVAL * 0.5, GUST_INTERVAL * 1.5)

	var gust_angle := deg_to_rad(GUST_DEG)
	for sprite in _tree_sprites:
		if not is_instance_valid(sprite):
			continue
		var tw := create_tween()
		# All trees gust to the right together
		tw.tween_property(sprite, "rotation", gust_angle, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sprite, "rotation", deg_to_rad(SWAY_DEG * 0.5), 0.8) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ═════════════════════════════════════════════════════════════════════
#  DEPTH SORTING (Y-based z_index)
# ═════════════════════════════════════════════════════════════════════

func _update_depth_sorting() -> void:
	# Trees: sort by their root node's Y
	for t in _tree_nodes:
		var root : Node2D = t["root"]
		if is_instance_valid(root):
			root.z_index = Z_BASE + int(root.global_position.y)

	# NPCs: sort by their PathFollow2D's Y
	for npc in _npc_walkers:
		var follow : PathFollow2D = npc["follow"]
		if is_instance_valid(follow):
			follow.z_index = Z_BASE + int(follow.global_position.y)


# ═════════════════════════════════════════════════════════════════════
#  OCCLUSION — fade trees where NPCs walk behind them
# ═════════════════════════════════════════════════════════════════════

func _update_occlusion() -> void:
	for t in _tree_nodes:
		var tree_root : Node2D = t["root"]
		var tree_sprite : Sprite2D = t["sprite"]
		if not is_instance_valid(tree_root) or not is_instance_valid(tree_sprite):
			continue

		var tree_y := tree_root.global_position.y
		var tree_x := tree_root.global_position.x

		# Gather NPC positions that are "behind" this tree (lower Y = higher on screen)
		var occluders : Array[Vector2] = []
		for npc in _npc_walkers:
			var follow : PathFollow2D = npc["follow"]
			if not is_instance_valid(follow):
				continue
			var npc_pos := follow.global_position
			# NPC is behind if its Y is less than the tree's Y (higher on screen)
			# and within horizontal/vertical range
			if npc_pos.y < tree_y \
				and npc_pos.y > tree_y - OCCLUDE_Y_RANGE \
				and abs(npc_pos.x - tree_x) < OCCLUDE_NEAR_X:
				occluders.append(npc_pos)
				if occluders.size() >= 8:
					break

		if occluders.is_empty():
			# No occluders — restore original material
			if tree_sprite.material is ShaderMaterial:
				tree_sprite.material = t["original_mat"]
		else:
			# Apply or update the shader
			var mat : ShaderMaterial
			if tree_sprite.material is ShaderMaterial:
				mat = tree_sprite.material as ShaderMaterial
			else:
				mat = ShaderMaterial.new()
				mat.shader = _occlusion_shader
				mat.set_shader_parameter("fade_radius", FADE_RADIUS)
				mat.set_shader_parameter("fade_alpha", FADE_ALPHA)
				tree_sprite.material = mat

			mat.set_shader_parameter("occluder_count", occluders.size())
			for i in range(occluders.size()):
				mat.set_shader_parameter("occluder_%d" % i, occluders[i])
			# Zero out unused slots
			for i in range(occluders.size(), 8):
				mat.set_shader_parameter("occluder_%d" % i, Vector2.ZERO)


# ═════════════════════════════════════════════════════════════════════
#  WIND PARTICLES (Wind_Anim sprite-sheet drifters)
# ═════════════════════════════════════════════════════════════════════

func _spawn_wind_particles() -> void:
	for i in WIND_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = _wind_tex
		sprite.hframes = WIND_HFRAMES
		sprite.vframes = 1
		sprite.frame = randi() % WIND_HFRAMES
		sprite.modulate = Color(1, 1, 1, randf_range(0.35, 0.65))
		sprite.z_index = 2000  # above all Y-sorted entities
		sprite.position = Vector2(
			randf_range(WIND_X_LEFT, WIND_X_RIGHT),
			randf_range(WIND_Y_MIN, WIND_Y_MAX))
		add_child(sprite)
		_wind_sprites.append({
			"sprite": sprite,
			"speed": randf_range(WIND_SPEED_MIN, WIND_SPEED_MAX),
			"anim_accum": randf() * WIND_HFRAMES,
		})


func _update_wind_particles(delta: float) -> void:
	for w in _wind_sprites:
		var sprite : Sprite2D = w["sprite"]
		if not is_instance_valid(sprite):
			continue
		sprite.position.x += w["speed"] * delta
		sprite.position.y += sin(_anim_clock * 2.0 + sprite.position.x * 0.05) * 0.3
		if sprite.position.x > WIND_X_RIGHT + 30:
			sprite.position.x = WIND_X_LEFT - 20
			sprite.position.y = randf_range(WIND_Y_MIN, WIND_Y_MAX)
		w["anim_accum"] += delta * WIND_ANIM_FPS
		sprite.frame = int(w["anim_accum"]) % WIND_HFRAMES


# ═════════════════════════════════════════════════════════════════════
#  LEAF PARTICLES — small leaves tumbling with the wind
# ═════════════════════════════════════════════════════════════════════

func _spawn_leaf_particles() -> void:
	for i in LEAF_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = _leaf_textures[randi() % _leaf_textures.size()]
		sprite.modulate = Color(1, 1, 1, randf_range(0.5, 0.85))
		sprite.z_index = 2001  # above wind, above all Y-sorted entities
		sprite.scale = Vector2.ONE * randf_range(0.5, 1.0)
		sprite.position = Vector2(
			randf_range(WIND_X_LEFT, WIND_X_RIGHT),
			randf_range(WIND_Y_MIN, WIND_Y_MAX))
		add_child(sprite)
		_leaf_sprites.append({
			"sprite": sprite,
			"speed_x": randf_range(LEAF_SPEED_MIN, LEAF_SPEED_MAX),
			"speed_y": randf_range(LEAF_FALL_MIN, LEAF_FALL_MAX),
			"spin": randf_range(LEAF_SPIN_MIN, LEAF_SPIN_MAX) * (1.0 if randi() % 2 == 0 else -1.0),
			"wobble_phase": randf() * TAU,
		})


func _update_leaf_particles(delta: float) -> void:
	for leaf in _leaf_sprites:
		var sprite : Sprite2D = leaf["sprite"]
		if not is_instance_valid(sprite):
			continue
		# Blow rightward with the wind
		sprite.position.x += leaf["speed_x"] * delta
		# Gentle falling + sine wobble for a tumbling look
		var wobble := sin(_anim_clock * 3.0 + leaf["wobble_phase"]) * 12.0
		sprite.position.y += leaf["speed_y"] * delta + wobble * delta
		# Spin
		sprite.rotation += leaf["spin"] * delta
		# Loop when off-screen
		if sprite.position.x > WIND_X_RIGHT + 30 or sprite.position.y > WIND_Y_MAX + 40:
			sprite.position.x = WIND_X_LEFT - randf_range(10, 40)
			sprite.position.y = randf_range(WIND_Y_MIN, WIND_Y_MIN + 60)


# ═════════════════════════════════════════════════════════════════════
#  FLOWERS — scattered animated patches
# ═════════════════════════════════════════════════════════════════════

func _spawn_flowers() -> void:
	# Small flower-grass patches (128×16 sprite sheets, 8 frames of 16×16)
	for i in FLOWER_GRASS_COUNT:
		var pos := _find_flower_position()
		if pos.x == INF:
			continue  # no valid spot — skip this flower
		var tex : Texture2D = load(FLOWER_GRASS_TEXTURES[randi() % FLOWER_GRASS_TEXTURES.size()])
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = 8
		sprite.vframes = 1
		sprite.frame = randi() % 8
		sprite.z_index = 1
		sprite.position = pos
		add_child(sprite)
		_flower_sprites.append({
			"sprite": sprite,
			"hframes": 8,
			"fps": FLOWER_GRASS_FPS,
			"anim_accum": randf() * 8.0,
		})

	# Larger animated flowers (96×160 sprite sheets, 6×10 = 16×16 cells)
	for i in FLOWER_ANIM_COUNT:
		var pos := _find_flower_position()
		if pos.x == INF:
			continue
		var tex : Texture2D = load(FLOWER_ANIM_TEXTURES[randi() % FLOWER_ANIM_TEXTURES.size()])
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = 6
		sprite.vframes = 10
		sprite.frame = randi() % 6   # stay in first row for a single variant
		sprite.z_index = 1
		sprite.position = pos
		add_child(sprite)
		_flower_sprites.append({
			"sprite": sprite,
			"hframes": 6,
			"fps": FLOWER_ANIM_FPS,
			"anim_accum": randf() * 6.0,
		})


func _update_flowers(delta: float) -> void:
	for f in _flower_sprites:
		var sprite : Sprite2D = f["sprite"]
		if not is_instance_valid(sprite):
			continue
		f["anim_accum"] += delta * f["fps"]
		sprite.frame = int(f["anim_accum"]) % f["hframes"]


# ═════════════════════════════════════════════════════════════════════
#  NPC WALKERS — follow the scene's Path2D
# ═════════════════════════════════════════════════════════════════════

func _spawn_npc_walkers() -> void:
	if not _path:
		push_warning("main_menu_scene: No Path2D found — skipping NPC spawning.")
		return

	var pool := NPC_TEXTURES.duplicate()
	pool.shuffle()
	var count := mini(NPC_COUNT, pool.size())
	var path_len := _path.curve.get_baked_length()

	for i in count:
		var tex : Texture2D = load(pool[i])
		@warning_ignore("integer_division")
		var vframes : int = tex.get_height() / 64

		# Create a PathFollow2D per NPC so they follow the curve
		var follow := PathFollow2D.new()
		follow.rotates = false
		follow.loop = true
		# Stagger starting positions along the path
		follow.progress = randf() * path_len
		_path.add_child(follow)

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = NPC_HFRAMES
		sprite.vframes = vframes
		sprite.frame = NPC_WALK_SIDE_S
		follow.add_child(sprite)

		_npc_walkers.append({
			"follow": follow,
			"sprite": sprite,
			"speed": randf_range(NPC_SPEED_MIN, NPC_SPEED_MAX),
			"anim_accum": randf() * 6.0,
			"prev_x": follow.global_position.x,
			"prev_y": follow.global_position.y,
		})


func _update_npc_walkers(delta: float) -> void:
	for npc in _npc_walkers:
		var follow : PathFollow2D = npc["follow"]
		var sprite : Sprite2D = npc["sprite"]
		if not is_instance_valid(follow) or not is_instance_valid(sprite):
			continue

		# Advance along the path
		follow.progress += npc["speed"] * delta

		# Determine movement direction
		var cur_pos := follow.global_position
		var prev_x : float = npc["prev_x"]
		var prev_y : float = npc["prev_y"]
		var dx := cur_pos.x - prev_x
		var dy := cur_pos.y - prev_y

		# Pick animation row based on dominant movement axis
		var walk_start := NPC_WALK_SIDE_S
		if abs(dx) > 0.01 or abs(dy) > 0.01:
			if abs(dx) >= abs(dy):
				# Horizontal movement — use side walk
				walk_start = NPC_WALK_SIDE_S
				# Raw side frames face right; flip for left
				sprite.flip_h = (dx < 0)
			elif dy > 0:
				# Moving down
				walk_start = NPC_WALK_DOWN_S
				sprite.flip_h = false
			else:
				# Moving up
				walk_start = NPC_WALK_UP_S
				sprite.flip_h = false

		npc["prev_x"] = cur_pos.x
		npc["prev_y"] = cur_pos.y

		# Animate walk frames
		npc["anim_accum"] += delta * NPC_ANIM_FPS
		var frame_offset := int(npc["anim_accum"]) % NPC_WALK_FRAMES
		sprite.frame = walk_start + frame_offset
