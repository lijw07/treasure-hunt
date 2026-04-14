class_name EnemyRanged
extends EnemyBase
## Ranged humanoid enemy — keeps distance and fires projectiles.
## Used by: Skeleton Bowman, Skeleton Mage, Desert Warrior Bow.

@export_group("Ranged")
@export var projectile_scene: PackedScene
@export var preferred_distance: float = 60.0
@export var retreat_speed: float = 35.0
@export var projectile_speed: float = 200.0
@export var projectile_damage: int = 1
@export var projectile_type: String = "arrow"  ## "arrow" or "magic"

var _arrow_scene: PackedScene
var _magic_scene: PackedScene


func _ready() -> void:
	super._ready()
	# Auto-load projectile scenes as fallbacks
	if projectile_scene == null:
		_arrow_scene = load("res://Prefabs/Enemies/Enemy_Arrow.tscn")
		_magic_scene = load("res://Prefabs/Enemies/Mage_Projectile.tscn")


func _process_chase(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = null
		_damage_aggro = false
		_enter_idle()
		return

	var dist := global_position.distance_to(_player.global_position)

	# When aggro'd by damage, chase much further before giving up.
	# Once close enough for normal detection, clear the aggro flag.
	if _damage_aggro:
		if dist <= detection_radius:
			_damage_aggro = false
		elif dist > lose_interest_radius * 3.0:
			_damage_aggro = false
			_player = null
			_enter_idle()
			return
	elif dist > lose_interest_radius:
		_player = null
		_enter_idle()
		return

	var dir := (_player.global_position - global_position).normalized()
	_update_facing(dir)

	# In attack range — stop and shoot
	if dist <= attack_range and _attack_timer <= 0.0:
		_enter_attack()
		return

	# Too close — retreat
	if dist < preferred_distance:
		velocity = -dir * retreat_speed
		_play_directional_anim("walk")
		return

	# Move toward preferred distance
	velocity = dir * chase_speed
	_play_directional_anim("walk")


func _on_attack_start() -> void:
	_play_attack_sound()
	_spawn_attack_particles()
	velocity = Vector2.ZERO

	# Fire projectile
	if _player and is_instance_valid(_player):
		var dir := (_player.global_position - global_position).normalized()
		_update_facing(dir)
		_play_directional_anim("attack")
		_spawn_projectile(dir)


func _spawn_projectile(dir: Vector2) -> void:
	var scene := projectile_scene
	if scene == null:
		match projectile_type:
			"magic":
				scene = _magic_scene
			_:
				scene = _arrow_scene

	if scene == null:
		# Absolute fallback: use weapon area for burst damage
		if _weapon:
			_weapon.set("damage", projectile_damage)
			_weapon.set_deferred("monitoring", true)
		return

	var proj := scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + dir * 10.0

	if proj.has_method("setup"):
		proj.setup(dir, projectile_speed, projectile_damage)


func _end_attack() -> void:
	super._end_attack()
