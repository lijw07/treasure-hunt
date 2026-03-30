extends Control

## =========================================================================
##  TREASURE HUNT — Main Menu
##  Pixel-themed with BGM, SFX, and full WASD/arrow keyboard navigation.
##  UI auto-scales via project stretch mode (canvas_items / keep).
## =========================================================================

# ── Palette (sampled from Cute Fantasy sprite sheets) ────────────────
const P_BG            := Color("#181c14")
const P_FRAME_OUTER   := Color("#c89248")
const P_FRAME_INNER   := Color("#7c4428")
const P_FRAME_BORDER  := Color("#4c2810")
const P_FRAME_HILITE  := Color("#e8b468")

const P_BTN           := Color("#48883c")
const P_BTN_HOVER     := Color("#5ca84c")
const P_BTN_PRESS     := Color("#346828")
const P_BTN_BORDER    := Color("#284e1c")

const P_EXIT           := Color("#884040")
const P_EXIT_HOVER     := Color("#a85454")
const P_EXIT_PRESS     := Color("#6c2c2c")
const P_EXIT_BORDER    := Color("#4c1c1c")

const P_GOLD          := Color("#ffd860")
const P_GOLD_DIM      := Color("#c8a040")
const P_TEXT           := Color("#f8f0e0")
const P_TEXT_DIM       := Color("#a89880")
const P_OVERLAY        := Color(0.0, 0.0, 0.0, 0.7)
const P_KEY_BG         := Color("#3c5830")

# ── Sizing ───────────────────────────────────────────────────────────
const PANEL_W := 260;  const BTN_W := 220;  const BTN_H := 30
const BTN_GAP := 8;    const BORDER := 3;   const CORNER := 1

# ── Audio ────────────────────────────────────────────────────────────
var sfx_hover  : AudioStream
var sfx_click  : AudioStream
var sfx_back   : AudioStream
var sfx_start  : AudioStream
var sfx_player : AudioStreamPlayer
var bgm_player : AudioStreamPlayer

# ── Node refs ────────────────────────────────────────────────────────
var font_title : Font   # VT323 for readability
var font_body  : Font   # same font, different sizes via overrides
var main_vbox  : VBoxContainer
var overlay    : ColorRect
var popup_htp  : PanelContainer
var popup_set  : PanelContainer
var sparkle_lyr: Control
var sparkles   : Array[Dictionary] = []
var menu_buttons : Array[Button] = []
var popup_active : PanelContainer = null
var _dirty_cb    : Callable                # kept so we can disconnect on rebuild

# Autoload reference (resolved at runtime to avoid compile-time errors)
var input_mgr : Node


# ─────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	input_mgr = get_node("/root/InputManager")

	font_title = load("res://Assets/Cute_Fantasy_UI/Fonts/VT323.ttf")
	font_body  = font_title

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_load_audio()
	_add_background()
	_add_sparkles()
	_add_main_menu()
	_add_overlay()
	_add_how_to_play()
	_add_settings()

	popup_htp.visible = false
	popup_set.visible = false
	overlay.visible   = false

	_wire_focus(menu_buttons)
	_entrance_anim()

	if menu_buttons.size() > 0:
		menu_buttons[0].call_deferred("grab_focus")

	# Start background music after a short delay
	bgm_player.call_deferred("play")


# ═════════════════════════════════════════════════════════════════════
#  AUDIO
# ═════════════════════════════════════════════════════════════════════
func _load_audio() -> void:
	sfx_hover = load("res://Assets/Audio/UI/hover.wav")
	sfx_click = load("res://Assets/Audio/UI/click.wav")
	sfx_back  = load("res://Assets/Audio/UI/back.wav")
	sfx_start = load("res://Assets/Audio/UI/start.wav")

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

	# BGM — loops seamlessly
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = input_mgr.volume_to_db(input_mgr.volume_music)
	var bgm_stream = load("res://Assets/Audio/UI/menu_bgm.wav")
	bgm_player.stream = bgm_stream
	add_child(bgm_player)
	# Loop when finished
	bgm_player.finished.connect(func(): bgm_player.play())
	# Start playing if volume > 0
	if input_mgr.volume_music > 0:
		bgm_player.play()


func _play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()


# ═════════════════════════════════════════════════════════════════════
#  BACKGROUND
# ═════════════════════════════════════════════════════════════════════
func _add_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = P_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for is_top in [true, false]:
		var line := ColorRect.new()
		line.color = P_FRAME_OUTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_top:
			line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			line.custom_minimum_size.y = 2
		else:
			line.anchor_left = 0; line.anchor_right = 1
			line.anchor_top = 1;  line.anchor_bottom = 1
			line.offset_top = -2; line.custom_minimum_size.y = 2
		add_child(line)


# ═════════════════════════════════════════════════════════════════════
#  SPARKLES
# ═════════════════════════════════════════════════════════════════════
func _add_sparkles() -> void:
	sparkle_lyr = Control.new()
	sparkle_lyr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sparkle_lyr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle_lyr.z_index = -1
	add_child(sparkle_lyr)
	sparkle_lyr.draw.connect(_draw_sparkles)

	var vp := get_viewport_rect().size
	for i in range(30):
		sparkles.append({
			"x": randf() * vp.x, "y": randf() * vp.y,
			"spd": randf_range(6.0, 18.0),
			"a": randf_range(0.08, 0.35),
			"sz": [2, 2, 2, 3][randi() % 4],
			"drift": randf_range(-0.4, 0.4),
			"phase": randf() * TAU,
		})


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	for s in sparkles:
		s["y"] -= s["spd"] * delta
		s["x"] += s["drift"] + sin(s["phase"] + Time.get_ticks_msec() * 0.0015) * 0.15
		if s["y"] < -4.0:
			s["y"] = vp.y + 4.0
			s["x"] = randf() * vp.x
	sparkle_lyr.queue_redraw()


func _draw_sparkles() -> void:
	for s in sparkles:
		sparkle_lyr.draw_rect(Rect2(s["x"], s["y"], s["sz"], s["sz"]), Color(P_GOLD, s["a"]))


# ═════════════════════════════════════════════════════════════════════
#  MAIN MENU
# ═════════════════════════════════════════════════════════════════════
func _add_main_menu() -> void:
	# Use a CenterContainer that fills the screen
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(main_vbox)

	# ── Title block ──────────────────────────────────────────────
	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	title_panel.add_theme_stylebox_override("panel",
		_make_frame_style(P_FRAME_BORDER, P_FRAME_INNER, BORDER))
	main_vbox.add_child(title_panel)

	var tvbox := VBoxContainer.new()
	tvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tvbox.add_theme_constant_override("separation", 0)
	title_panel.add_child(tvbox)

	tvbox.add_child(_spacer(6))

	var title := Label.new()
	title.text = "TREASURE HUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", P_GOLD)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", P_FRAME_BORDER)
	tvbox.add_child(title)

	var sub := Label.new()
	sub.text = "~ A Pixel Adventure ~"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", font_body)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", P_GOLD_DIM)
	tvbox.add_child(sub)

	tvbox.add_child(_spacer(6))

	# ── Gap ──────────────────────────────────────────────────────
	main_vbox.add_child(_spacer(8))

	# ── Button card ──────────────────────────────────────────────
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(PANEL_W, 0)
	card.add_theme_stylebox_override("panel", _make_double_frame_style())
	main_vbox.add_child(card)

	var bvbox := VBoxContainer.new()
	bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bvbox.add_theme_constant_override("separation", BTN_GAP)
	card.add_child(bvbox)

	var b_start := _make_button("Start Game", false)
	b_start.pressed.connect(_on_start)
	bvbox.add_child(b_start)
	menu_buttons.append(b_start)

	var b_htp := _make_button("How to Play", false)
	b_htp.pressed.connect(_on_how_to_play)
	bvbox.add_child(b_htp)
	menu_buttons.append(b_htp)

	var b_set := _make_button("Settings", false)
	b_set.pressed.connect(_on_settings)
	bvbox.add_child(b_set)
	menu_buttons.append(b_set)

	bvbox.add_child(_spacer(2))

	var b_exit := _make_button("Exit", true)
	b_exit.pressed.connect(_on_exit)
	bvbox.add_child(b_exit)
	menu_buttons.append(b_exit)

	# ── Footer ───────────────────────────────────────────────────
	main_vbox.add_child(_spacer(10))
	var foot := Label.new()
	foot.text = "v0.1"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_override("font", font_body)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(P_TEXT_DIM, 0.4))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(foot)


# ═════════════════════════════════════════════════════════════════════
#  FOCUS / KEYBOARD NAVIGATION
# ═════════════════════════════════════════════════════════════════════
func _wire_focus(buttons: Array[Button]) -> void:
	for i in buttons.size():
		var btn := buttons[i]
		var prev := buttons[(i - 1) % buttons.size()]
		var nxt  := buttons[(i + 1) % buttons.size()]
		btn.focus_neighbor_top    = prev.get_path()
		btn.focus_neighbor_bottom = nxt.get_path()
		btn.focus_neighbor_left   = btn.get_path()
		btn.focus_neighbor_right  = btn.get_path()
		btn.focus_previous        = prev.get_path()
		btn.focus_next            = nxt.get_path()
		btn.focus_entered.connect(_on_btn_focus)


func _on_btn_focus() -> void:
	_play_sfx(sfx_hover)


## Rebind intercept — uses _input so mouse clicks are caught BEFORE the GUI
## consumes them (otherwise LMB/RMB land on a button and never reach
## _unhandled_input).
func _input(event: InputEvent) -> void:
	if not visible or _rebind_action == "":
		return

	# Let Escape cancel the rebind
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_cancel_rebind()
		_play_sfx(sfx_back)
		get_viewport().set_input_as_handled()
		return

	# Accept key presses or mouse button presses
	var accepted := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		input_mgr.rebind_action(_rebind_action, event)
		accepted = true
	elif event is InputEventMouseButton and event.is_pressed():
		input_mgr.rebind_action(_rebind_action, event)
		accepted = true

	if accepted:
		if is_instance_valid(_rebind_btn):
			_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
		_play_sfx(sfx_click)
		_rebind_action = ""
		_rebind_btn = null
		get_viewport().set_input_as_handled()
	else:
		# Swallow everything while in rebind mode so clicks don't hit UI
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if popup_active:
			_play_sfx(sfx_back)
			_close_popup(popup_active)
			get_viewport().set_input_as_handled()
		return

	# Map WASD game-movement keys → UI navigation
	var mapping := {
		"move_up":    "ui_up",
		"move_down":  "ui_down",
		"move_left":  "ui_left",
		"move_right": "ui_right",
	}
	for game_action in mapping:
		if event.is_action_pressed(game_action):
			var ui_ev := InputEventAction.new()
			ui_ev.action = mapping[game_action]
			ui_ev.pressed = true
			Input.parse_input_event(ui_ev)
			get_viewport().set_input_as_handled()
			return


# ═════════════════════════════════════════════════════════════════════
#  STYLE BUILDERS
# ═════════════════════════════════════════════════════════════════════
func _make_frame_style(border_col: Color, bg_col: Color, bw: int = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(bw)
	s.set_corner_radius_all(CORNER)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 8;   s.content_margin_bottom = 8
	return s


func _make_double_frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = P_FRAME_INNER
	s.border_color = P_FRAME_BORDER
	s.set_border_width_all(BORDER)
	s.set_corner_radius_all(CORNER)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 14;  s.content_margin_bottom = 14
	s.shadow_color = P_FRAME_OUTER
	s.shadow_size = 4
	s.shadow_offset = Vector2.ZERO
	return s


# ═════════════════════════════════════════════════════════════════════
#  BUTTON FACTORY
# ═════════════════════════════════════════════════════════════════════
func _make_button(label_text: String, is_exit: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_body)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", P_TEXT)
	btn.add_theme_color_override("font_hover_color", P_TEXT)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_TEXT)

	var base   := P_EXIT if is_exit else P_BTN
	var hover  := P_EXIT_HOVER if is_exit else P_BTN_HOVER
	var press  := P_EXIT_PRESS if is_exit else P_BTN_PRESS
	var border := P_EXIT_BORDER if is_exit else P_BTN_BORDER
	var hilite := Color("#c86060") if is_exit else P_FRAME_HILITE

	# Normal
	var sn := StyleBoxFlat.new()
	sn.bg_color = base;  sn.border_color = border
	sn.set_border_width_all(2);  sn.border_width_bottom = 4
	sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 8;  sn.content_margin_right = 8
	sn.content_margin_top = 4;   sn.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sn)

	# Hover
	var sh := sn.duplicate()
	sh.bg_color = hover;  sh.border_color = hilite
	btn.add_theme_stylebox_override("hover", sh)

	# Pressed
	var sp := sn.duplicate()
	sp.bg_color = press;  sp.border_width_bottom = 2
	sp.content_margin_top = 6;  sp.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", sp)

	# Focus (keyboard)
	var sf := sh.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	# Disabled (greyed-out)
	var sd := sn.duplicate()
	sd.bg_color = Color(base, 0.4)
	sd.border_color = Color(border, 0.3)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_disabled_color", Color(P_TEXT, 0.35))

	# Mouse hover → sync with keyboard focus + SFX + scale
	btn.mouse_entered.connect(func():
		btn.grab_focus()
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08))
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.08))
	# Click SFX is connected per-button in _add_main_menu callbacks

	return btn


# ═════════════════════════════════════════════════════════════════════
#  OVERLAY
# ═════════════════════════════════════════════════════════════════════
func _add_overlay() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = P_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)


# ═════════════════════════════════════════════════════════════════════
#  HOW TO PLAY
# ═════════════════════════════════════════════════════════════════════
func _add_how_to_play() -> void:
	popup_htp = _popup_shell("How to Play")
	var box : VBoxContainer = popup_htp.get_meta("content")

	var controls := [
		["W A S D", "Move in all directions"],
		["SPACE", "Dodge roll"],
		["L-CLICK", "Shoot your bow"],
		["MOUSE", "Change aim direction"],
	]
	for c in controls:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		row.add_child(_key_badge(c[0]))
		var desc := Label.new()
		desc.text = c[1]
		desc.add_theme_font_override("font", font_body)
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", P_TEXT)
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(desc)

	box.add_child(_spacer(8))
	var tip := Label.new()
	tip.text = "Explore, defeat enemies, find treasure!"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_override("font", font_body)
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", P_TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(tip)

	box.add_child(_spacer(8))
	var close := _make_button("Back", false)
	close.custom_minimum_size = Vector2(120, 26)
	close.pressed.connect(func():
		_play_sfx(sfx_back)
		_close_popup(popup_htp))
	var cc := CenterContainer.new(); cc.add_child(close)
	box.add_child(cc)
	popup_htp.set_meta("close_btn", close)


func _key_badge(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(80, 22)
	var s := StyleBoxFlat.new()
	s.bg_color = P_KEY_BG; s.border_color = P_BTN_BORDER
	s.set_border_width_all(2); s.set_corner_radius_all(CORNER)
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 2;  s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_body)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", P_GOLD)
	p.add_child(l)
	return p


# ═════════════════════════════════════════════════════════════════════
#  SETTINGS  (reads from InputManager autoload)
# ═════════════════════════════════════════════════════════════════════
var _rebind_action : String = ""       # action currently waiting for a key
var _rebind_btn    : Button  = null    # the button showing "Press a key…"

func _add_settings() -> void:
	popup_set = _popup_shell("Settings")
	var box : VBoxContainer = popup_set.get_meta("content")

	# Scrollable area — scrollbar hidden
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode  = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	var im := input_mgr

	# ── Volume ───────────────────────────────────────────────────
	content.add_child(_section_header("Volume"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	content.add_child(_make_slider_row("Music", 0, 100, 5, im.volume_music, func(val: float):
		im.volume_music = val
		im.mark_dirty()
		bgm_player.volume_db = input_mgr.volume_to_db(val)
		if val > 0 and not bgm_player.playing:
			bgm_player.play()
		_play_sfx(sfx_hover)))

	content.add_child(_make_slider_row("SFX", 0, 100, 5, im.volume_sfx, func(val: float):
		im.volume_sfx = val
		im.mark_dirty()
		sfx_player.volume_db = input_mgr.volume_to_db(val)
		_play_sfx(sfx_hover)))

	content.add_child(_spacer(6))

	# ── Mouse ────────────────────────────────────────────────────
	content.add_child(_section_header("Mouse"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	content.add_child(_make_slider_row("Sensitivity", 10, 300, 10,
		int(im.mouse_sensitivity * 100), func(val: float):
			im.mouse_sensitivity = val / 100.0
			im.mark_dirty()
			_play_sfx(sfx_hover)))

	# Invert Y toggle
	var invert_row := HBoxContainer.new()
	invert_row.add_theme_constant_override("separation", 8)
	content.add_child(invert_row)

	var inv_lbl := Label.new()
	inv_lbl.text = "Invert Y"
	inv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_lbl.add_theme_font_override("font", font_body)
	inv_lbl.add_theme_font_size_override("font_size", 16)
	inv_lbl.add_theme_color_override("font_color", P_TEXT)
	invert_row.add_child(inv_lbl)

	var inv_btn := CheckButton.new()
	inv_btn.button_pressed = im.mouse_inverted
	inv_btn.focus_mode = Control.FOCUS_ALL
	inv_btn.add_theme_color_override("font_color", P_TEXT)
	inv_btn.toggled.connect(func(on: bool):
		im.mouse_inverted = on
		im.mark_dirty()
		_play_sfx(sfx_click))
	invert_row.add_child(inv_btn)

	content.add_child(_spacer(6))

	# ── Controls (clickable rebind buttons) ──────────────────────
	var categories : Dictionary = im.get_actions_by_category()
	for cat_name in categories:
		content.add_child(_section_header(cat_name))
		content.add_child(_divider())
		content.add_child(_spacer(2))

		for action_name in categories[cat_name]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			content.add_child(row)

			var lbl := Label.new()
			lbl.text = im.get_label(action_name)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_override("font", font_body)
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", P_TEXT)
			row.add_child(lbl)

			var bind_btn := _make_rebind_button(action_name)
			row.add_child(bind_btn)

		content.add_child(_spacer(4))

	# Reset to defaults
	var reset_btn := _make_button("Reset Defaults", true)
	reset_btn.custom_minimum_size = Vector2(160, 26)
	reset_btn.pressed.connect(func():
		im.reset_to_defaults()
		_play_sfx(sfx_click)
		_cancel_rebind()
		# Tear down old popup immediately (no tween — it's being replaced)
		popup_active = null
		overlay.visible = false
		var old_wrapper := popup_set.get_parent()
		if old_wrapper:
			old_wrapper.queue_free()
		else:
			popup_set.queue_free()
		# Rebuild fresh
		_add_settings()
		_open_popup(popup_set))
	var rc := CenterContainer.new(); rc.add_child(reset_btn)
	content.add_child(rc)

	content.add_child(_spacer(6))

	# Save + Back buttons side by side
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	var save_btn := _make_button("Save", false)
	save_btn.custom_minimum_size = Vector2(100, 26)
	save_btn.pressed.connect(func():
		_cancel_rebind()
		im.save_settings()
		_play_sfx(sfx_click)
		_close_popup(popup_set)
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus())
	# Disconnect previous dirty callback if rebuilding
	if _dirty_cb.is_valid() and im.dirty_changed.is_connected(_dirty_cb):
		im.dirty_changed.disconnect(_dirty_cb)
	# Enable / disable Save based on unsaved changes
	_dirty_cb = func(dirty: bool):
		if not is_instance_valid(save_btn):
			return
		save_btn.disabled = not dirty
		save_btn.focus_mode = Control.FOCUS_ALL if dirty else Control.FOCUS_NONE
		save_btn.mouse_filter = Control.MOUSE_FILTER_STOP if dirty else Control.MOUSE_FILTER_IGNORE
	im.dirty_changed.connect(_dirty_cb)
	# Start fully disabled
	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_child(save_btn)

	var back_btn := _make_button("Back", false)
	back_btn.custom_minimum_size = Vector2(100, 26)
	back_btn.pressed.connect(func():
		_cancel_rebind()
		im.load_settings()   # revert unsaved changes
		_play_sfx(sfx_back)
		_close_popup(popup_set))
	btn_row.add_child(back_btn)

	var cc := CenterContainer.new(); cc.add_child(btn_row)
	content.add_child(cc)
	popup_set.set_meta("close_btn", back_btn)

	# Clear any dirty state that may have been triggered during popup construction
	im.clear_dirty()
	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ═════════════════════════════════════════════════════════════════════
#  REBIND BUTTON FACTORY
# ═════════════════════════════════════════════════════════════════════

## Create a button that shows the current binding and enters listen mode on click.
func _make_rebind_button(action_name: String) -> Button:
	var btn := Button.new()
	btn.text = input_mgr.get_binding_text(action_name)
	btn.custom_minimum_size = Vector2(72, 22)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_body)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", P_GOLD)
	btn.add_theme_color_override("font_hover_color", P_GOLD)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_GOLD)

	# Normal style — looks like a key badge
	var sn := StyleBoxFlat.new()
	sn.bg_color = P_KEY_BG; sn.border_color = P_BTN_BORDER
	sn.set_border_width_all(2); sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 6; sn.content_margin_right = 6
	sn.content_margin_top = 2;  sn.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", sn)

	# Hover
	var sh := sn.duplicate()
	sh.border_color = P_FRAME_HILITE
	btn.add_theme_stylebox_override("hover", sh)

	# Focus
	var sf := sn.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	# Pressed / listening
	var sp := sn.duplicate()
	sp.bg_color = P_FRAME_BORDER; sp.border_color = P_GOLD
	btn.add_theme_stylebox_override("pressed", sp)

	btn.pressed.connect(func():
		_start_rebind(action_name, btn))

	return btn


## Enter listening mode — next key/mouse press will rebind the action.
func _start_rebind(action_name: String, btn: Button) -> void:
	_cancel_rebind()   # cancel any previous listen
	_rebind_action = action_name
	_rebind_btn = btn
	btn.text = "..."
	_play_sfx(sfx_click)


## Cancel listening mode without changing anything.
func _cancel_rebind() -> void:
	if _rebind_btn and is_instance_valid(_rebind_btn) and _rebind_action != "":
		_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
	_rebind_action = ""
	_rebind_btn = null


## (Rebind intercept is now handled inside _unhandled_input above)


## Build a labelled slider row:  "Label  ───●─── 50%"
func _make_slider_row(label_text: String, min_val: float, max_val: float,
		step_val: float, initial: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_override("font", font_body)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", P_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val;  slider.max_value = max_val;  slider.step = step_val
	slider.value = initial
	slider.custom_minimum_size = Vector2(110, 16)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL

	# Track style
	var track := StyleBoxFlat.new()
	track.bg_color = P_FRAME_BORDER
	track.set_corner_radius_all(1)
	track.content_margin_top = 6;  track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)

	# Filled portion
	var fill := StyleBoxFlat.new()
	fill.bg_color = P_BTN; fill.set_corner_radius_all(1)
	fill.content_margin_top = 6;  fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	# Grabber knob
	slider.add_theme_icon_override("grabber", _make_grabber_texture(P_BTN, P_BTN_BORDER))
	slider.add_theme_icon_override("grabber_highlight", _make_grabber_texture(P_BTN_HOVER, P_FRAME_HILITE))
	row.add_child(slider)

	# Value label
	var pct := Label.new()
	pct.text = "%d%%" % int(initial)
	pct.custom_minimum_size.x = 42
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_override("font", font_body)
	pct.add_theme_font_size_override("font_size", 14)
	pct.add_theme_color_override("font_color", P_TEXT_DIM)
	row.add_child(pct)

	slider.value_changed.connect(func(val: float):
		pct.text = "%d%%" % int(val)
		on_change.call(val))

	# Sync initial display (update pct label only — don't fire on_change
	# to avoid marking dirty on popup build)
	pct.text = "%d%%" % int(initial)
	return row


## Create a small square grabber texture via an Image.
func _make_grabber_texture(fill: Color, border: Color) -> ImageTexture:
	var tex_size := 10
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(border)
	# Inner fill (inset by 2px)
	for y in range(2, tex_size - 2):
		for x in range(2, tex_size - 2):
			img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


## Thin horizontal divider line.
func _divider() -> ColorRect:
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = P_FRAME_OUTER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return div


## Gold section header label.
func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_body)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", P_GOLD)
	return lbl


# ═════════════════════════════════════════════════════════════════════
#  POPUP SHELL
# ═════════════════════════════════════════════════════════════════════
func _popup_shell(title_text: String) -> PanelContainer:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapper)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(300, 0)
	var os := StyleBoxFlat.new()
	os.bg_color = P_FRAME_OUTER; os.border_color = P_FRAME_BORDER
	os.set_border_width_all(BORDER); os.set_corner_radius_all(CORNER + 1)
	os.content_margin_left = 4;  os.content_margin_right = 4
	os.content_margin_top = 4;   os.content_margin_bottom = 4
	outer.add_theme_stylebox_override("panel", os)
	wrapper.add_child(outer)

	var inner := PanelContainer.new()
	var ins := StyleBoxFlat.new()
	ins.bg_color = P_FRAME_INNER; ins.border_color = Color(P_FRAME_BORDER, 0.5)
	ins.set_border_width_all(2); ins.set_corner_radius_all(CORNER)
	ins.content_margin_left = 16; ins.content_margin_right = 16
	ins.content_margin_top = 12;  ins.content_margin_bottom = 12
	inner.add_theme_stylebox_override("panel", ins)
	outer.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	inner.add_child(vbox)

	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font_title)
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", P_GOLD)
	t.add_theme_constant_override("outline_size", 2)
	t.add_theme_color_override("font_outline_color", P_FRAME_BORDER)
	vbox.add_child(t)
	vbox.add_child(_spacer(4))

	outer.set_meta("content", vbox)
	return outer


# ═════════════════════════════════════════════════════════════════════
#  POPUP TRANSITIONS
# ═════════════════════════════════════════════════════════════════════
func _open_popup(panel: PanelContainer) -> void:
	popup_active = panel
	overlay.visible = true
	panel.visible = true
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var close_btn = panel.get_meta("close_btn", null)
	if close_btn:
		(close_btn as Button).call_deferred("grab_focus")


func _close_popup(panel: PanelContainer) -> void:
	popup_active = null
	if not is_instance_valid(panel):
		overlay.visible = false
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.12)
	tw.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.12).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		overlay.visible = false
		if is_instance_valid(panel):
			panel.visible = false
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus())


# ═════════════════════════════════════════════════════════════════════
#  ENTRANCE ANIMATION
# ═════════════════════════════════════════════════════════════════════
func _entrance_anim() -> void:
	main_vbox.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(main_vbox, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ═════════════════════════════════════════════════════════════════════
#  BUTTON CALLBACKS
# ═════════════════════════════════════════════════════════════════════
func _on_start() -> void:
	_play_sfx(sfx_start)
	# Fade out BGM
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(bgm_player, "volume_db", -40.0, 0.4)
	tw.chain().tween_callback(func():
		bgm_player.stop()
		get_tree().change_scene_to_file("res://Scene/grass_biome.tscn"))


func _on_how_to_play() -> void:
	_play_sfx(sfx_click)
	_open_popup(popup_htp)


func _on_settings() -> void:
	_play_sfx(sfx_click)
	_open_popup(popup_set)


func _on_exit() -> void:
	_play_sfx(sfx_click)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_property(bgm_player, "volume_db", -40.0, 0.25)
	tw.chain().tween_callback(func(): get_tree().quit())


# ═════════════════════════════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════════════════════════════
func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
