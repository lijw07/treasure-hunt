extends Node2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var controller: CharacterBody2D = get_parent()


func _process(_delta: float) -> void:
	match controller.state:
		controller.State.IDLE:
			if controller.mounted:
				_play("idle_mount_" + controller.facing)
			else:
				_play("idle_" + controller.facing)
		controller.State.MOVE:
			if controller.mounted:
				_play("walk_mount_" + controller.facing)
			else:
				_play("walk_" + controller.facing)
		controller.State.DODGE:
			_play_once("roll_" + controller.dodge_facing, 1.5)
		controller.State.JUMP:
			_play_once("jump_" + controller.facing)
		controller.State.ATTACK:
			_play_once(controller.attack_anim_name)
		controller.State.STUN:
			_play_once("idle_" + controller.facing)
		controller.State.DEAD:
			pass  # Handled by _on_died() in the controller


func _play(anim_name: String) -> void:
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _play_once(anim_name: String, speed: float = 1.0) -> void:
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name, -1, speed)
