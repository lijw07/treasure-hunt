extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# Bow Controller
# Attach to the Bow node. Spawns arrow projectiles when the player shoots.
# ─────────────────────────────────────────────────────────────────────────────

@export var arrow_scene: PackedScene
@export var cooldown: float = 0.5

var cooldown_timer: float = 0.0


func _ready() -> void:
	# If no arrow scene is set in the inspector, try to load from path
	if arrow_scene == null:
		var path = "res://Prefabs/arrow.tscn"
		if ResourceLoader.exists(path):
			arrow_scene = load(path)


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta


# Called from AnimationPlayer method call tracks (no arguments needed).
# Reads facing from the PlayerController automatically.
func shoot() -> void:
	if arrow_scene == null:
		printerr("[Bow] No arrow scene assigned.")
		return
	if cooldown_timer > 0.0:
		return

	cooldown_timer = cooldown

	# Get facing from the player controller
	var player = _get_player()
	var dir: String = "down"
	if player and "facing" in player:
		dir = player.facing

	# Instance the arrow and add it to the scene tree (not as child of player,
	# so it stays in world space and doesn't move with the player)
	var arrow = arrow_scene.instantiate()
	arrow.global_position = global_position
	arrow.setup(dir)

	# Add to the same parent as the player so it exists in the game world
	get_tree().current_scene.add_child(arrow)


func _get_player() -> Node:
	# Walk up the tree to find the CharacterBody2D (player root)
	var node = get_parent()
	while node != null:
		if node is CharacterBody2D:
			return node
		node = node.get_parent()
	return null
