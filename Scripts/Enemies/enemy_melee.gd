class_name EnemyMelee
extends EnemyBase
## Melee humanoid enemy — walks toward the player and swings a weapon.
## Used by: Skeleton Swordman, Mummy, Desert Warrior Atgier.

@export_group("Melee")
@export var lunge_on_attack: bool = true
@export var lunge_distance: float = 60.0
@export var weapon_offset: float = 14.0

var _attack_lunge_dir: Vector2 = Vector2.ZERO


func _on_attack_start() -> void:
	# Position weapon hitbox BEFORE enabling monitoring (super enables it)
	# to prevent a frame where the weapon sits at (0,0) overlapping our own hurtbox
	_position_weapon()

	super._on_attack_start()

	# Short lunge toward player
	if lunge_on_attack and _player and is_instance_valid(_player):
		_attack_lunge_dir = (_player.global_position - global_position).normalized()
		_knockback_velocity = _attack_lunge_dir * lunge_distance


func _end_attack() -> void:
	super._end_attack()
	_attack_lunge_dir = Vector2.ZERO


func _position_weapon() -> void:
	if _weapon == null:
		return
	# Use _visual_facing (true direction) not _facing (animation key).
	# When facing left via sprite flip, _facing is "right" but the weapon
	# must be placed to the LEFT of the enemy.
	match _visual_facing:
		"down":
			_weapon.position = Vector2(0, weapon_offset)
		"up":
			_weapon.position = Vector2(0, -weapon_offset)
		"right":
			_weapon.position = Vector2(weapon_offset, 0)
		"left":
			_weapon.position = Vector2(-weapon_offset, 0)
