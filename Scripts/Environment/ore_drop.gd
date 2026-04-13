extends Area2D

var _bob_tween: Tween
var _sprite: Sprite2D
var _picked_up: bool = false
var _lifetime_timer: float = 30.0


func _ready() -> void:
	_sprite = get_child(0) as Sprite2D
	body_entered.connect(_on_body_entered)
	_start_bob()
	_start_lifetime()


func _start_bob() -> void:
	if _sprite == null:
		return
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_sprite, "position:y", -2.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_sprite, "position:y", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _start_lifetime() -> void:
	await get_tree().create_timer(_lifetime_timer).timeout
	if not _picked_up:
		_fade_out()


func _on_body_entered(body: Node2D) -> void:
	if _picked_up:
		return
	if not body.is_in_group("player") and not body is CharacterBody2D:
		return
	_picked_up = true
	_collect(body)


func magnet_collect() -> void:
	if _picked_up:
		return
	_picked_up = true
	if _bob_tween:
		_bob_tween.kill()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.15).set_ease(Tween.EASE_IN)
	if _sprite:
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)


func _collect(_body: Node2D) -> void:
	if _bob_tween:
		_bob_tween.kill()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", _body.global_position + Vector2(0, -8), 0.2).set_ease(Tween.EASE_IN)
	if _sprite:
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _fade_out() -> void:
	if _sprite == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
