extends Node2D

@export var arrow_scene: PackedScene
@export var cooldown: float = 0.5

var cooldown_timer: float = 0.0


func _ready() -> void:
	if arrow_scene == null:
		var path = "res://Prefabs/Weapons/arrow.tscn"
		if ResourceLoader.exists(path):
			arrow_scene = load(path)


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta


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
