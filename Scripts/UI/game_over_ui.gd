extends CanvasLayer
## Game-Over screen shown when the player dies.
##
## Offers two choices:
##   • Respawn at Checkpoint — resets health and moves the player to the
##     last checkpoint (or spawn point).
##   • Quit — returns to the main menu scene.
##
## Styled to match the pause menu / start menu Cute Fantasy pixel theme.

signal respawn_requested
signal quit_requested

# ── Palette (matches pause_menu / start_menu) ──────────────────────
const P_FRAME_OUTER   := Color("#c89248")
const P_FRAME_INNER   := Color("#7c4428")
const P_FRAME_BORDER  := Color("#4c2810")

const P_BTN           := Color("#48883c")
const P_BTN_HOVER     := Color("#5ca84c")
const P_BTN_PRESS     := Color("#346828")
const P_BTN_BORDER    := Color("#284e1c")
const P_FRAME_HILITE  := Color("#e8b468")

const P_EXIT          := Color("#884040")
const P_EXIT_HOVER    := Color("#a85454")
const P_EXIT_PRESS    := Color("#6c2c2c")
const P_EXIT_BORDER   := Color("#4c1c1c")

const P_GOLD          := Color("#ffd860")
const P_TEXT          := Color("#f8f0e0")
const P_TEXT_DIM      := Color("#a89880")
const P_OVERLAY       := Color(0.0, 0.0, 0.0, 0.7)

# ── Sizing ──────────────────────────────────────────────────────────
const BTN_W           := 220
const BTN_H           := 30
const BORDER          := 3
const CORNER          := 1

const FADE_DURATION: float = 0.6

var _root: Control
var _overlay: ColorRect
var _outer_panel: PanelContainer
var _respawn_btn: Button
var _quit_btn: Button
var _visible: bool = false

var font_main: Font


func _ready() -> void:
	layer = 100  # Always on top
	font_main = load("res://Assets/Cute_Fantasy_UI/Fonts/VT323.ttf")
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
	_outer_panel.modulate = Color(1, 1, 1, 0)
	_outer_panel.scale = Vector2(0.8, 0.8)

	# Pause the game tree so enemies/physics stop
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	tw.parallel().tween_property(_outer_panel, "modulate:a", 1.0, FADE_DURATION * 0.8).set_delay(0.15)
	tw.parallel().tween_property(_outer_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.15)

	# Give focus to respawn button for keyboard navigation
	_respawn_btn.grab_focus()


func hide_game_over() -> void:
	_visible = false
	get_tree().paused = false
	var tw = create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_outer_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_hide_immediate)


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = P_OVERLAY
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game
	_root.add_child(_overlay)

	# Centre wrapper
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wrapper)

	# Outer panel (gold frame)
	_outer_panel = PanelContainer.new()
	_outer_panel.custom_minimum_size = Vector2(300, 0)
	var os := StyleBoxFlat.new()
	os.bg_color = P_FRAME_OUTER
	os.border_color = P_FRAME_BORDER
	os.set_border_width_all(BORDER)
	os.set_corner_radius_all(CORNER + 1)
	os.content_margin_left = 4
	os.content_margin_right = 4
	os.content_margin_top = 4
	os.content_margin_bottom = 4
	_outer_panel.add_theme_stylebox_override("panel", os)
	# Set pivot for scale animation
	_outer_panel.pivot_offset = Vector2(150, 80)
	wrapper.add_child(_outer_panel)

	# Inner panel (dark brown)
	var inner := PanelContainer.new()
	inner.clip_contents = true
	var ins := StyleBoxFlat.new()
	ins.bg_color = P_FRAME_INNER
	ins.border_color = Color(P_FRAME_BORDER, 0.5)
	ins.set_border_width_all(2)
	ins.set_corner_radius_all(CORNER)
	ins.content_margin_left = 16
	ins.content_margin_right = 16
	ins.content_margin_top = 12
	ins.content_margin_bottom = 12
	inner.add_theme_stylebox_override("panel", ins)
	_outer_panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inner.add_child(vbox)

	# Title — "Game Over" in gold
	var title := Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_main)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", P_GOLD)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", P_FRAME_BORDER)
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "You have fallen..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", font_main)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", P_TEXT_DIM)
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(8))

	# Respawn button (green, like regular buttons)
	_respawn_btn = _make_button("Respawn at Checkpoint", false)
	_respawn_btn.pressed.connect(_on_respawn_pressed)
	vbox.add_child(_respawn_btn)

	# Quit button (red/exit style)
	_quit_btn = _make_button("Quit to Menu", true)
	_quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(_quit_btn)

	# Wire keyboard focus navigation
	var buttons: Array[Button] = [_respawn_btn, _quit_btn]
	_wire_focus(buttons)


func _make_button(label_text: String, is_exit: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_main)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", P_TEXT)
	btn.add_theme_color_override("font_hover_color", P_TEXT)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_TEXT)

	var base := P_EXIT if is_exit else P_BTN
	var hover := P_EXIT_HOVER if is_exit else P_BTN_HOVER
	var press := P_EXIT_PRESS if is_exit else P_BTN_PRESS
	var border := P_EXIT_BORDER if is_exit else P_BTN_BORDER
	var hilite := Color("#c86060") if is_exit else P_FRAME_HILITE

	var sn := StyleBoxFlat.new()
	sn.bg_color = base
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.border_width_bottom = 4
	sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 8
	sn.content_margin_right = 8
	sn.content_margin_top = 4
	sn.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate()
	sh.bg_color = hover
	sh.border_color = hilite
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate()
	sp.bg_color = press
	sp.border_width_bottom = 2
	sp.content_margin_top = 6
	sp.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", sp)

	var sf := sh.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	btn.mouse_entered.connect(func():
		if not is_instance_valid(btn):
			return
		btn.grab_focus()
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08))
	btn.mouse_exited.connect(func():
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.08))
	return btn


func _wire_focus(buttons: Array[Button]) -> void:
	for i in buttons.size():
		var btn := buttons[i]
		var prev := buttons[(i - 1) % buttons.size()]
		var nxt := buttons[(i + 1) % buttons.size()]
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = nxt.get_path()
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()
		btn.focus_previous = prev.get_path()
		btn.focus_next = nxt.get_path()


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


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
