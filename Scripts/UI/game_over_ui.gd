extends CanvasLayer
## Game-Over screen shown when the player dies.
##
## Offers two choices:
##   • Respawn at Checkpoint — resets health and moves the player to the
##     last checkpoint (or spawn point).
##   • Quit — returns to the main menu scene.

signal respawn_requested
signal quit_requested

const FADE_DURATION: float = 0.6

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _respawn_btn: Button
var _quit_btn: Button
var _vbox: VBoxContainer
var _visible: bool = false


func _ready() -> void:
	layer = 100  # Always on top
	_build_ui()
	_hide_immediate()


# ═══════════════════════════════════════════════════════════════════════
#  PUBLIC
# ═══════════════════════════════════════════════════════════════════════

func show_game_over() -> void:
	if _visible:
		return
	_visible = true
	visible = true
	_overlay.modulate = Color(1, 1, 1, 0)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.8, 0.8)

	# Pause the game tree so enemies/physics stop
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	tw.parallel().tween_property(_panel, "modulate:a", 1.0, FADE_DURATION * 0.8).set_delay(0.15)
	tw.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.15)


func hide_game_over() -> void:
	_visible = false
	get_tree().paused = false
	var tw = create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_hide_immediate)


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.05, 0.02, 0.08, 0.75)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game
	root.add_child(_overlay)

	# Centre panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -160
	_panel.offset_right = 160
	_panel.offset_top = -120
	_panel.offset_bottom = 120
	_panel.pivot_offset = Vector2(160, 120)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.65, 0.25, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Game Over"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "You have fallen..."
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 1.0))
	_vbox.add_child(_subtitle_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(spacer)

	# Respawn button
	_respawn_btn = _make_button("Respawn at Checkpoint", Color(0.2, 0.55, 0.3, 1.0))
	_respawn_btn.pressed.connect(_on_respawn_pressed)
	_vbox.add_child(_respawn_btn)

	# Quit button
	_quit_btn = _make_button("Quit to Menu", Color(0.55, 0.2, 0.2, 1.0))
	_quit_btn.pressed.connect(_on_quit_pressed)
	_vbox.add_child(_quit_btn)


func _make_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 40)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.set_corner_radius_all(6)
	style_hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.15)
	style_pressed.set_corner_radius_all(6)
	style_pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	return btn


# ═══════════════════════════════════════════════════════════════════════
#  CALLBACKS
# ═══════════════════════════════════════════════════════════════════════

func _on_respawn_pressed() -> void:
	hide_game_over()
	respawn_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	quit_requested.emit()
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn")


func _hide_immediate() -> void:
	visible = false
