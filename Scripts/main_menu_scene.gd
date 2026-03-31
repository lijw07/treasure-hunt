extends Node2D
## Animated main-menu backdrop. Systems:
##   - Y-based depth sorting + per-pixel occlusion shader on trees
##   - Uniform wind sway on every OakTree with periodic gusts
##   - Wind_Anim sprite-sheet particles showing wind direction
##   - Leaf particles tumbling with the wind
##   - Animated flower patches placed via obstacle-aware spawning
##   - NPCs that follow the scene's Path2D and loop


# ── NPC ─────────────────────────────────────────────────────────────

const NPC_TEXTURES := [
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Bartender_Bruno.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Bartender_Katy.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Chef_Chloe.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Farmer_Bob.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Farmer_Buba.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Lumberjack_Jack.png",
	"res://Assets/Cute_Fantasy/NPCs (Premade)/Miner_Mike.png",
]
const NPC_CELL_SIZE    := 64
const NPC_HFRAMES      := 6
const NPC_WALK_DOWN_S  := 18          # row 3, frames 18-23
const NPC_WALK_SIDE_S  := 24          # row 4, frames 24-29
const NPC_WALK_UP_S    := 30          # row 5, frames 30-35
const NPC_WALK_FRAMES  := 6
const NPC_ANIM_FPS     := 10.0
const NPC_SPEED_MIN    := 18.0        # px/s along the path
const NPC_SPEED_MAX    := 30.0
const NPC_COUNT        := 4


# ── Wind particles ──────────────────────────────────────────────────

const WIND_HFRAMES   := 14            # 224 / 16
const WIND_ANIM_FPS  := 12.0
const WIND_COUNT     := 14
const WIND_SPEED_MIN := 30.0
const WIND_SPEED_MAX := 55.0


# ── Leaf particles ──────────────────────────────────────────────────

const LEAF_TEXTURES := [
	"res://Assets/Cute_Fantasy/Trees/Oak_Leaf_Particle.png",
	"res://Assets/Cute_Fantasy/Trees/Birch_Leaf_Particle.png",
]
const LEAF_COUNT     := 12
const LEAF_SPEED_MIN := 20.0
const LEAF_SPEED_MAX := 40.0
const LEAF_FALL_MIN  := 8.0           # downward drift px/s
const LEAF_FALL_MAX  := 18.0
const LEAF_SPIN_MIN  := 1.5           # rad/s rotation
const LEAF_SPIN_MAX  := 4.0


# ── Flowers ─────────────────────────────────────────────────────────

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
const FLOWER_GRASS_COUNT  := 30
const FLOWER_ANIM_COUNT   := 15
const FLOWER_GRASS_FPS    := 6.0
const FLOWER_ANIM_FPS     := 6.0
const FLOWER_TREE_DIST    := 18.0     # min px from a tree trunk
const FLOWER_ROCK_DIST    := 14.0     # min px from a rock / grass deco
const FLOWER_ROAD_DIST    := 12.0     # min px from the road path
const FLOWER_MAX_ATTEMPTS := 40


# ── Tree sway (uniform wind direction) ──────────────────────────────

const SWAY_DEG      := 0.8           # baseline lean (degrees)
const SWAY_PERIOD   := 3.0           # seconds per cycle
const GUST_DEG      := 2.0           # gust lean
const GUST_INTERVAL := 5.0           # avg seconds between gusts


# ── Occlusion / depth ──────────────────────────────────────────────

const OCCLUDE_NEAR_X  := 28.0        # horizontal check range
const OCCLUDE_Y_RANGE := 28.0        # vertical check range above tree
const FADE_RADIUS     := 20.0        # shader fade circle radius (px)
const FADE_ALPHA      := 0.25        # min alpha at fade centre
const Z_BASE          := 1000        # offset for Y-based z_index


# ── Shared world bounds ────────────────────────────────────────────

const WORLD_X_LEFT  := -220.0
const WORLD_X_RIGHT := 280.0
const WORLD_Y_MIN   := -120.0
const WORLD_Y_MAX   := 85.0


# ── Scene paths for child identification ────────────────────────────

const _SCENE_OAK   := "res://Prefabs/Tree/OakTree.tscn"
const _SCENE_ROCK  := "res://Prefabs/RockAnimation/animated_sprite_2d.tscn"
const _SCENE_GRASS2 := "res://Prefabs/GrassAnimation/GrassAnimation2.tscn"
const _SCENE_GRASS3 := "res://Prefabs/GrassAnimation/GrassAnimation3.tscn"


# ── Runtime state ───────────────────────────────────────────────────

var _npc_walkers    : Array[Dictionary] = []
var _wind_sprites   : Array[Dictionary] = []
var _leaf_sprites   : Array[Dictionary] = []
var _flower_sprites : Array[Dictionary] = []

## Each entry: { "root": Node2D, "sprite": Sprite2D, "original_mat": Material }
var _tree_nodes     : Array[Dictionary] = []

var _obstacle_trees : Array[Vector2] = []
var _obstacle_rocks : Array[Vector2] = []
var _road_points    : Array[Vector2] = []

var _path             : Path2D   = null
var _wind_tex         : Texture2D
var _leaf_textures    : Array[Texture2D] = []
var _occlusion_shader : Shader

var _gust_timer  := 0.0
var _next_gust   := 0.0
var _anim_clock  := 0.0


# ═════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_wind_tex         = load("res://Assets/Cute_Fantasy/Weather effects/Wind_Anim.png")
	_occlusion_shader = load("res://Shaders/occlusion_fade.gdshader")
	for tex_path in LEAF_TEXTURES:
		_leaf_textures.append(load(tex_path))

	_path = _find_first_child_of_type(Path2D)

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
#  SCENE QUERIES
# ═════════════════════════════════════════════════════════════════════

## Return the first direct child that is an instance of the given type.
func _find_first_child_of_type(type) -> Node:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null


## Gather every OakTree instance for sway + occlusion.
func _collect_trees() -> void:
	for child in get_children():
		if not (child is Node2D) or child.scene_file_path != _SCENE_OAK:
			continue
		var sprite := child.get_node_or_null("Sprite2D") as Sprite2D
		if not sprite:
			continue
		_tree_nodes.append({
			"root":         child,
			"sprite":       sprite,
			"original_mat": sprite.material,
		})


## Build exclusion lists (trees, rocks, road) for flower placement.
func _collect_obstacles() -> void:
	for t in _tree_nodes:
		_obstacle_trees.append((t["root"] as Node2D).position)

	for child in get_children():
		if not (child is Node2D) or child == _path:
			continue
		var sp := child.scene_file_path
		if sp == _SCENE_ROCK or sp == _SCENE_GRASS2 or sp == _SCENE_GRASS3:
			_obstacle_rocks.append(child.position)

	if _path and _path.curve:
		var curve  := _path.curve
		var length := curve.get_baked_length()
		var step   := 6.0
		var dist   := 0.0
		while dist <= length:
			_road_points.append(curve.sample_baked(dist))
			dist += step


# ═════════════════════════════════════════════════════════════════════
#  DEPTH SORTING  (z_index = Z_BASE + Y)
# ═════════════════════════════════════════════════════════════════════

func _update_depth_sorting() -> void:
	for t in _tree_nodes:
		var root : Node2D = t["root"]
		if is_instance_valid(root):
			root.z_index = Z_BASE + int(root.global_position.y)

	for npc in _npc_walkers:
		var follow : PathFollow2D = npc["follow"]
		if is_instance_valid(follow):
			follow.z_index = Z_BASE + int(follow.global_position.y)


# ═════════════════════════════════════════════════════════════════════
#  OCCLUSION  (shader fades trees where NPCs walk behind them)
# ═════════════════════════════════════════════════════════════════════

func _update_occlusion() -> void:
	for t in _tree_nodes:
		var tree_root   : Node2D   = t["root"]
		var tree_sprite : Sprite2D = t["sprite"]
		if not is_instance_valid(tree_root) or not is_instance_valid(tree_sprite):
			continue

		var tree_pos := tree_root.global_position
		var occluders := _gather_occluders(tree_pos)

		if occluders.is_empty():
			_restore_material(tree_sprite, t["original_mat"])
		else:
			_apply_occlusion_shader(tree_sprite, occluders)


## Collect NPC positions that are behind the tree (lower Y / higher on screen).
func _gather_occluders(tree_pos: Vector2) -> Array[Vector2]:
	var result : Array[Vector2] = []
	for npc in _npc_walkers:
		var follow : PathFollow2D = npc["follow"]
		if not is_instance_valid(follow):
			continue
		var npc_pos := follow.global_position
		var behind  : bool = npc_pos.y < tree_pos.y
		var close_y : bool = npc_pos.y > tree_pos.y - OCCLUDE_Y_RANGE
		var close_x : bool = abs(npc_pos.x - tree_pos.x) < OCCLUDE_NEAR_X
		if behind and close_y and close_x:
			result.append(npc_pos)
			if result.size() >= 8:
				break
	return result


func _restore_material(sprite: Sprite2D, original: Material) -> void:
	if sprite.material is ShaderMaterial:
		sprite.material = original


func _apply_occlusion_shader(sprite: Sprite2D, occluders: Array[Vector2]) -> void:
	var mat : ShaderMaterial
	if sprite.material is ShaderMaterial:
		mat = sprite.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _occlusion_shader
		mat.set_shader_parameter("fade_radius", FADE_RADIUS)
		mat.set_shader_parameter("fade_alpha", FADE_ALPHA)
		sprite.material = mat

	mat.set_shader_parameter("occluder_count", occluders.size())
	for i in range(8):
		var pos := occluders[i] if i < occluders.size() else Vector2.ZERO
		mat.set_shader_parameter("occluder_%d" % i, pos)


# ═════════════════════════════════════════════════════════════════════
#  TREE WIND SWAY
# ═════════════════════════════════════════════════════════════════════

func _start_tree_sway() -> void:
	for t in _tree_nodes:
		var sprite : Sprite2D = t["sprite"]
		var delay := randf_range(0.0, 0.4)
		_sway_loop(sprite, delay)


func _sway_loop(sprite: Sprite2D, delay: float) -> void:
	if not is_instance_valid(sprite):
		return
	var half  := SWAY_PERIOD * 0.5
	var angle := deg_to_rad(SWAY_DEG)
	var tw := create_tween().set_loops()
	tw.tween_interval(delay)
	tw.tween_property(sprite, "rotation", angle, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "rotation", angle * 0.2, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _update_gusts(delta: float) -> void:
	_gust_timer += delta
	if _gust_timer < _next_gust:
		return
	_gust_timer = 0.0
	_next_gust = randf_range(GUST_INTERVAL * 0.5, GUST_INTERVAL * 1.5)

	var gust_angle := deg_to_rad(GUST_DEG)
	var rest_angle := deg_to_rad(SWAY_DEG * 0.5)
	for t in _tree_nodes:
		var sprite : Sprite2D = t["sprite"]
		if not is_instance_valid(sprite):
			continue
		var tw := create_tween()
		tw.tween_property(sprite, "rotation", gust_angle, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sprite, "rotation", rest_angle, 0.8) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ═════════════════════════════════════════════════════════════════════
#  WIND PARTICLES
# ═════════════════════════════════════════════════════════════════════

func _spawn_wind_particles() -> void:
	for i in WIND_COUNT:
		var sprite := _make_sprite(_wind_tex, 2000)
		sprite.hframes = WIND_HFRAMES
		sprite.frame   = randi() % WIND_HFRAMES
		sprite.modulate = Color(1, 1, 1, randf_range(0.35, 0.65))
		sprite.position = _random_world_pos()
		add_child(sprite)
		_wind_sprites.append({
			"sprite":     sprite,
			"speed":      randf_range(WIND_SPEED_MIN, WIND_SPEED_MAX),
			"anim_accum": randf() * float(WIND_HFRAMES),
		})


func _update_wind_particles(delta: float) -> void:
	for w in _wind_sprites:
		var sprite : Sprite2D = w["sprite"]
		if not is_instance_valid(sprite):
			continue
		sprite.position.x += w["speed"] * delta
		sprite.position.y += sin(_anim_clock * 2.0 + sprite.position.x * 0.05) * 0.3
		if sprite.position.x > WORLD_X_RIGHT + 30:
			sprite.position.x = WORLD_X_LEFT - 20
			sprite.position.y = randf_range(WORLD_Y_MIN, WORLD_Y_MAX)
		w["anim_accum"] += delta * WIND_ANIM_FPS
		sprite.frame = int(w["anim_accum"]) % WIND_HFRAMES


# ═════════════════════════════════════════════════════════════════════
#  LEAF PARTICLES
# ═════════════════════════════════════════════════════════════════════

func _spawn_leaf_particles() -> void:
	for i in LEAF_COUNT:
		var sprite := _make_sprite(
			_leaf_textures[randi() % _leaf_textures.size()], 2001)
		sprite.modulate = Color(1, 1, 1, randf_range(0.5, 0.85))
		sprite.scale    = Vector2.ONE * randf_range(0.5, 1.0)
		sprite.position = _random_world_pos()
		add_child(sprite)
		_leaf_sprites.append({
			"sprite":      sprite,
			"speed_x":     randf_range(LEAF_SPEED_MIN, LEAF_SPEED_MAX),
			"speed_y":     randf_range(LEAF_FALL_MIN, LEAF_FALL_MAX),
			"spin":        randf_range(LEAF_SPIN_MIN, LEAF_SPIN_MAX) * _rand_sign(),
			"wobble_phase": randf() * TAU,
		})


func _update_leaf_particles(delta: float) -> void:
	for leaf in _leaf_sprites:
		var sprite : Sprite2D = leaf["sprite"]
		if not is_instance_valid(sprite):
			continue
		sprite.position.x += leaf["speed_x"] * delta
		var wobble := sin(_anim_clock * 3.0 + leaf["wobble_phase"]) * 12.0
		sprite.position.y += leaf["speed_y"] * delta + wobble * delta
		sprite.rotation    += leaf["spin"] * delta
		if sprite.position.x > WORLD_X_RIGHT + 30 or sprite.position.y > WORLD_Y_MAX + 40:
			sprite.position.x = WORLD_X_LEFT - randf_range(10, 40)
			sprite.position.y = randf_range(WORLD_Y_MIN, WORLD_Y_MIN + 60)


# ═════════════════════════════════════════════════════════════════════
#  FLOWERS
# ═════════════════════════════════════════════════════════════════════

func _spawn_flowers() -> void:
	_spawn_flower_batch(FLOWER_GRASS_TEXTURES, FLOWER_GRASS_COUNT, 8, 1, FLOWER_GRASS_FPS)
	_spawn_flower_batch(FLOWER_ANIM_TEXTURES,  FLOWER_ANIM_COUNT,  6, 10, FLOWER_ANIM_FPS)


## Spawn a batch of animated flower sprites from a texture pool.
func _spawn_flower_batch(
		textures: Array, count: int, hframes: int, vframes: int, fps: float
) -> void:
	for i in count:
		var pos := _find_flower_position()
		if pos.x == INF:
			continue
		var tex : Texture2D = load(textures[randi() % textures.size()])
		var sprite := Sprite2D.new()
		sprite.texture  = tex
		sprite.hframes  = hframes
		sprite.vframes  = vframes
		sprite.frame    = randi() % hframes
		sprite.z_index  = 1
		sprite.position = pos
		add_child(sprite)
		_flower_sprites.append({
			"sprite":     sprite,
			"hframes":    hframes,
			"fps":        fps,
			"anim_accum": randf() * float(hframes),
		})


func _update_flowers(delta: float) -> void:
	for f in _flower_sprites:
		var sprite : Sprite2D = f["sprite"]
		if not is_instance_valid(sprite):
			continue
		f["anim_accum"] += delta * f["fps"]
		sprite.frame = int(f["anim_accum"]) % f["hframes"]


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


## Try random positions until a valid one is found (or give up).
func _find_flower_position() -> Vector2:
	for _attempt in range(FLOWER_MAX_ATTEMPTS):
		var candidate := Vector2(
			randf_range(WORLD_X_LEFT, WORLD_X_RIGHT),
			randf_range(WORLD_Y_MIN, WORLD_Y_MAX))
		if _is_flower_position_valid(candidate):
			return candidate
	return Vector2(INF, INF)


# ═════════════════════════════════════════════════════════════════════
#  NPC WALKERS
# ═════════════════════════════════════════════════════════════════════

func _spawn_npc_walkers() -> void:
	if not _path:
		push_warning("main_menu_scene: No Path2D found — skipping NPC spawning.")
		return

	var pool := NPC_TEXTURES.duplicate()
	pool.shuffle()
	var count    := mini(NPC_COUNT, pool.size())
	var path_len := _path.curve.get_baked_length()

	for i in count:
		var tex : Texture2D = load(pool[i])
		@warning_ignore("integer_division")
		var vframes : int = tex.get_height() / NPC_CELL_SIZE

		var follow := PathFollow2D.new()
		follow.rotates  = false
		follow.loop     = true
		follow.progress = randf() * path_len
		_path.add_child(follow)

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = NPC_HFRAMES
		sprite.vframes = vframes
		sprite.frame   = NPC_WALK_SIDE_S
		follow.add_child(sprite)

		_npc_walkers.append({
			"follow":     follow,
			"sprite":     sprite,
			"speed":      randf_range(NPC_SPEED_MIN, NPC_SPEED_MAX),
			"anim_accum": randf() * float(NPC_WALK_FRAMES),
			"prev_x":     follow.global_position.x,
			"prev_y":     follow.global_position.y,
		})


func _update_npc_walkers(delta: float) -> void:
	for npc in _npc_walkers:
		var follow : PathFollow2D = npc["follow"]
		var sprite : Sprite2D     = npc["sprite"]
		if not is_instance_valid(follow) or not is_instance_valid(sprite):
			continue

		follow.progress += npc["speed"] * delta

		var cur_pos := follow.global_position
		var dx := cur_pos.x - (npc["prev_x"] as float)
		var dy := cur_pos.y - (npc["prev_y"] as float)

		# Pick animation row based on dominant movement axis
		var walk_start := NPC_WALK_SIDE_S
		if abs(dx) > 0.01 or abs(dy) > 0.01:
			if abs(dx) >= abs(dy):
				walk_start   = NPC_WALK_SIDE_S
				sprite.flip_h = (dx < 0)
			elif dy > 0:
				walk_start   = NPC_WALK_DOWN_S
				sprite.flip_h = false
			else:
				walk_start   = NPC_WALK_UP_S
				sprite.flip_h = false

		npc["prev_x"] = cur_pos.x
		npc["prev_y"] = cur_pos.y

		npc["anim_accum"] += delta * NPC_ANIM_FPS
		sprite.frame = walk_start + int(npc["anim_accum"]) % NPC_WALK_FRAMES


# ═════════════════════════════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════════════════════════════

## Create a Sprite2D with a texture and z_index already set.
func _make_sprite(tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.z_index = z
	return s


## Random position within the visible world bounds.
func _random_world_pos() -> Vector2:
	return Vector2(
		randf_range(WORLD_X_LEFT, WORLD_X_RIGHT),
		randf_range(WORLD_Y_MIN, WORLD_Y_MAX))


## Return +1.0 or -1.0 at random.
func _rand_sign() -> float:
	return 1.0 if randi() % 2 == 0 else -1.0
