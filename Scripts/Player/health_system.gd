extends Node

signal health_changed(current_hp: int, max_hp: int)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died

## Each heart container holds 2 HP (full → half → empty).
const HP_PER_HEART: int = 2

@export var max_hearts: int = 5
@export var invincibility_duration: float = 1.0

var _current_hp: int
var _max_hp: int
var _invincible_timer: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	_max_hp = max_hearts * HP_PER_HEART
	_current_hp = _max_hp


func _physics_process(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta


func take_damage(amount: int = 1) -> bool:
	if _is_dead:
		return false
	if _invincible_timer > 0.0:
		return false

	var parent = get_parent()
	if parent and parent.get("invincible"):
		return false

	_current_hp = maxi(_current_hp - amount, 0)
	_invincible_timer = invincibility_duration
	damage_taken.emit(amount)
	health_changed.emit(_current_hp, _max_hp)

	if _current_hp <= 0:
		_is_dead = true
		died.emit()
	return true


func heal(amount: int = 1) -> void:
	if _is_dead:
		return
	var before = _current_hp
	_current_hp = mini(_current_hp + amount, _max_hp)
	var actual = _current_hp - before
	if actual > 0:
		healed.emit(actual)
		health_changed.emit(_current_hp, _max_hp)


func heal_full() -> void:
	heal(_max_hp - _current_hp)


func add_heart_container() -> void:
	max_hearts += 1
	_max_hp = max_hearts * HP_PER_HEART
	_current_hp = mini(_current_hp + HP_PER_HEART, _max_hp)
	health_changed.emit(_current_hp, _max_hp)


func reset() -> void:
	_is_dead = false
	_invincible_timer = 0.0
	_current_hp = _max_hp
	health_changed.emit(_current_hp, _max_hp)


func is_invincible() -> bool:
	return _invincible_timer > 0.0


func is_dead() -> bool:
	return _is_dead


func get_current_hp() -> int:
	return _current_hp


func get_max_hp() -> int:
	return _max_hp
