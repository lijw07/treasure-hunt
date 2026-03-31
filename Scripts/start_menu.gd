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

const P_EXIT          := Color("#884040")
const P_EXIT_HOVER    := Color("#a85454")
const P_EXIT_PRESS    := Color("#6c2c2c")
const P_EXIT_BORDER   := Color("#4c1c1c")

const P_GOLD          := Color("#ffd860")
const P_GOLD_DIM      := Color("#c8a040")
const P_TEXT          := Color("#f8f0e0")
const P_TEXT_DIM      := Color("#a89880")
const P_OVERLAY       := Color(0.0, 0.0, 0.0, 0.7)
const P_KEY_BG        := Color("#3c5830")

# ── Sizing ───────────────────────────────────────────────────────────
const PANEL_W         := 260
const BTN_W           := 220
const BTN_H           := 30
const BTN_GAP         := 8
const BORDER          := 3
const CORNER          := 1

# Magic numbers for sparkle generation and rendering
const SPARKLE_COUNT   := 30
const SPARKLE_SPEED_MIN := 6.0
const SPARKLE_SPEED_MAX := 18.0
const SPARKLE_ALPHA_MIN := 0.08
const SPARKLE_ALPHA_MAX := 0.35
const SPARKLE_SIZES   := [2, 2, 2, 3]
const SPARKLE_DRIFT_MIN := -0.4
const SPARKLE_DRIFT_MAX := 0.4
const SPARKLE_WAVE_SPEED := 0.0015
const SPARKLE_WAVE_AMP := 0.15
const SPARKLE_RESET_OFFSET := 4.0

# Transition timing
const POPUP_FADE_IN_TIME := 0.15
const POPUP_SCALE_IN_TIME := 0.15
const POPUP_FADE_OUT_TIME := 0.12
const POPUP_SCALE_OUT_TIME := 0.12
const TITLE_FADE_IN_TIME := 0.5
const START_FADE_OUT_TIME := 0.4
const EXIT_FADE_OUT_TIME := 0.25

# Volume and audio settings
const VOLUME_BGM_SILENT := -40.0

# ── Audio ────────────────────────────────────────────────────────────
var sfx_hover         : AudioStream
var sfx_click         : AudioStream
var sfx_back          : AudioStream
var sfx_start         : AudioStream
var sfx_player        : AudioStreamPlayer
var bgm_player        : AudioStreamPlayer

# ── Node References ──────────────────────────────────────────────────
var font_title        : Font
var font_body         : Font
var main_vbox         : VBoxContainer
var overlay           : ColorRect
var popup_htp         : PanelContainer
var popup_set         : PanelContainer
var sparkle_lyr       : Control
var sparkles          : Array[Dictionary] = []
var menu_buttons      : Array[Button] = []
var popup_active      : PanelContainer = null

# ── Settings and State ───────────────────────────────────────────────
var _dirty_cb         : Callable
var _settings_scroll  : ScrollContainer
var _rebind_action    : String = ""
var _rebind_btn       : Button = null
var popup_confirm     : PanelContainer = null   # "Unsaved changes" dialog

# References for in-place reset (avoid full rebuild flicker)
var _rebind_buttons   : Dictionary = {}   # action_name → Button
var _slider_music     : HSlider = null
var _slider_sfx       : HSlider = null
var _slider_sens      : HSlider = null
var _invert_btn       : CheckButton = null

# Autoload reference (resolved at runtime to avoid compile-time errors)
var input_mgr         : Node


# ─────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────

## Initialize the main menu scene.
func _ready() -> void:
	input_mgr = get_node("/root/InputManager")

	font_title = load("res://Assets/Cute_Fantasy_UI/Fonts/VT323.ttf")
	font_body = font_title

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
	overlay.visible = false

	_wire_focus(menu_buttons)
	_entrance_anim()


# ═════════════════════════════════════════════════════════════════════
#  AUDIO
# ═════════════════════════════════════════════════════════════════════

## Load UI audio streams and configure audio players.
func _load_audio() -> void:
	sfx_hover = load("res://Assets/Audio/UI/hover.wav")
	sfx_click = load("res://Assets/Audio/UI/click.wav")
	sfx_back = load("res://Assets/Audio/UI/back.wav")
	sfx_start = load("res://Assets/Audio/UI/start.wav")

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
	add_child(sfx_player)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = input_mgr.volume_to_db(input_mgr.volume_music)
	var bgm_stream = load("res://Assets/Audio/UI/menu_bgm.wav")
	bgm_player.stream = bgm_stream
	add_child(bgm_player)

	bgm_player.finished.connect(func():
		if is_instance_valid(bgm_player):
			bgm_player.play())

	if input_mgr.volume_music > 0:
		bgm_player.play()


## Play a UI sound effect.
func _play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()


# ═════════════════════════════════════════════════════════════════════
#  BACKGROUND
# ═════════════════════════════════════════════════════════════════════

## Create background color and decorative top/bottom border lines.
func _add_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(P_BG, 0.55)
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
			line.anchor_left = 0
			line.anchor_right = 1
			line.anchor_top = 1
			line.anchor_bottom = 1
			line.offset_top = -2
			line.custom_minimum_size.y = 2
		add_child(line)


# ═════════════════════════════════════════════════════════════════════
#  SPARKLES
# ═════════════════════════════════════════════════════════════════════

## Initialize animated sparkle particles.
func _add_sparkles() -> void:
	sparkle_lyr = Control.new()
	sparkle_lyr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sparkle_lyr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle_lyr.z_index = -1
	add_child(sparkle_lyr)
	sparkle_lyr.draw.connect(_draw_sparkles)

	var vp := get_viewport_rect().size
	for i in range(SPARKLE_COUNT):
		sparkles.append({
			"x": randf() * vp.x,
			"y": randf() * vp.y,
			"spd": randf_range(SPARKLE_SPEED_MIN, SPARKLE_SPEED_MAX),
			"a": randf_range(SPARKLE_ALPHA_MIN, SPARKLE_ALPHA_MAX),
			"sz": SPARKLE_SIZES[randi() % SPARKLE_SIZES.size()],
			"drift": randf_range(SPARKLE_DRIFT_MIN, SPARKLE_DRIFT_MAX),
			"phase": randf() * TAU,
		})


## Update sparkle positions each frame.
func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	for s in sparkles:
		s["y"] -= s["spd"] * delta
		s["x"] += s["drift"] + sin(s["phase"] + Time.get_ticks_msec() * SPARKLE_WAVE_SPEED) * SPARKLE_WAVE_AMP
		if s["y"] < -SPARKLE_RESET_OFFSET:
			s["y"] = vp.y + SPARKLE_RESET_OFFSET
			s["x"] = randf() * vp.x
	sparkle_lyr.queue_redraw()


## Draw all sparkles as small colored rectangles.
func _draw_sparkles() -> void:
	for s in sparkles:
		sparkle_lyr.draw_rect(Rect2(s["x"], s["y"], s["sz"], s["sz"]), Color(P_GOLD, s["a"]))


# ═════════════════════════════════════════════════════════════════════
#  MAIN MENU
# ═════════════════════════════════════════════════════════════════════

## Construct the main menu UI with title, buttons, and footer.
func _add_main_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(main_vbox)

	# Title block
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

	main_vbox.add_child(_spacer(8))

	# Button card
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

	# Footer
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

## Configure focus neighbors for cyclic button navigation.
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
		btn.focus_entered.connect(_on_btn_focus)


## Play hover SFX when a button receives keyboard focus.
func _on_btn_focus() -> void:
	_play_sfx(sfx_hover)


## Intercept input before the GUI system.
## Handles: (1) ESC to close popups / trigger unsaved-changes confirmation,
## (2) key rebinding capture (must run before GUI buttons consume clicks).
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# ── Rebind mode: capture the next key/mouse press ────────────
	if _rebind_action != "":
		# Cancel rebind with Escape or pause key (unless rebinding pause itself)
		if _rebind_action != "pause" and event is InputEventKey and event.is_pressed():
			var key := (event as InputEventKey).physical_keycode
			if key == KEY_NONE:
				key = (event as InputEventKey).keycode
			var is_cancel := (key == KEY_ESCAPE)
			if not is_cancel and InputMap.has_action("pause"):
				is_cancel = InputMap.event_is_action(event, "pause")
			if is_cancel:
				_cancel_rebind()
				_play_sfx(sfx_back)
				get_viewport().set_input_as_handled()
				return

		# Accept key or mouse button presses (ignore scroll wheel)
		var accepted := false
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			input_mgr.rebind_action(_rebind_action, event)
			accepted = true
		elif event is InputEventMouseButton and event.is_pressed():
			var mb := (event as InputEventMouseButton).button_index
			if mb != MOUSE_BUTTON_WHEEL_UP and mb != MOUSE_BUTTON_WHEEL_DOWN \
					and mb != MOUSE_BUTTON_WHEEL_LEFT and mb != MOUSE_BUTTON_WHEEL_RIGHT:
				input_mgr.rebind_action(_rebind_action, event)
				accepted = true

		if accepted:
			if is_instance_valid(_rebind_btn):
				_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
				_rebind_btn.add_theme_color_override("font_color", P_GOLD)
			_play_sfx(sfx_click)
			_rebind_action = ""
			_rebind_btn = null
		# Swallow all events during rebind to prevent clicks hitting UI
		get_viewport().set_input_as_handled()
		return

	# ── ESC / ui_cancel: close popups (must be in _input so GUI ─
	#    buttons don't swallow the key before we see it)
	if event.is_action_pressed("ui_cancel"):
		if popup_confirm and is_instance_valid(popup_confirm) and popup_confirm.visible:
			_play_sfx(sfx_back)
			_close_confirm_popup()
			get_viewport().set_input_as_handled()
			return
		if popup_active:
			_play_sfx(sfx_back)
			_try_close_settings()
			get_viewport().set_input_as_handled()
		return


## Map game movement keys (WASD) to UI navigation actions.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Map movement actions to UI navigation
	var mapping := {
		"move_up": "ui_up",
		"move_down": "ui_down",
		"move_left": "ui_left",
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

## Create a frame style with specified border color and background color.
func _make_frame_style(border_col: Color, bg_col: Color, bw: int = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(bw)
	s.set_corner_radius_all(CORNER)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Create a double-frame style with shadow for card containers.
func _make_double_frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = P_FRAME_INNER
	s.border_color = P_FRAME_BORDER
	s.set_border_width_all(BORDER)
	s.set_corner_radius_all(CORNER)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = P_FRAME_OUTER
	s.shadow_size = 4
	s.shadow_offset = Vector2.ZERO
	return s


# ═════════════════════════════════════════════════════════════════════
#  BUTTON FACTORY
# ═════════════════════════════════════════════════════════════════════

## Create a styled menu button with hover and press effects.
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

	var base := P_EXIT if is_exit else P_BTN
	var hover := P_EXIT_HOVER if is_exit else P_BTN_HOVER
	var press := P_EXIT_PRESS if is_exit else P_BTN_PRESS
	var border := P_EXIT_BORDER if is_exit else P_BTN_BORDER
	var hilite := Color("#c86060") if is_exit else P_FRAME_HILITE

	# Normal state
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

	# Hover state
	var sh := sn.duplicate()
	sh.bg_color = hover
	sh.border_color = hilite
	btn.add_theme_stylebox_override("hover", sh)

	# Pressed state
	var sp := sn.duplicate()
	sp.bg_color = press
	sp.border_width_bottom = 2
	sp.content_margin_top = 6
	sp.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", sp)

	# Focus state (keyboard)
	var sf := sh.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	# Disabled state
	var sd := sn.duplicate()
	sd.bg_color = Color(base, 0.4)
	sd.border_color = Color(border, 0.3)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_disabled_color", Color(P_TEXT, 0.35))

	# Mouse hover effects
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


# ═════════════════════════════════════════════════════════════════════
#  OVERLAY
# ═════════════════════════════════════════════════════════════════════

## Create a semi-transparent overlay for popup backgrounds.
func _add_overlay() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = P_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)


# ═════════════════════════════════════════════════════════════════════
#  HOW TO PLAY
# ═════════════════════════════════════════════════════════════════════

## Create the "How to Play" popup with control bindings.
func _add_how_to_play() -> void:
	popup_htp = _popup_shell("How to Play")
	var box : VBoxContainer = popup_htp.get_meta("content")

	var controls := [
		["%s %s %s %s" % [
			str(input_mgr.get_binding_text("move_up")),
			str(input_mgr.get_binding_text("move_left")),
			str(input_mgr.get_binding_text("move_down")),
			str(input_mgr.get_binding_text("move_right"))],
			"Move in all directions"],
		[str(input_mgr.get_binding_text("dodge")), "Dodge roll"],
		[str(input_mgr.get_binding_text("basic_attack")), "Basic attack"],
		[str(input_mgr.get_binding_text("heavy_attack")), "Heavy attack"],
		[str(input_mgr.get_binding_text("interact")), "Interact"],
		[str(input_mgr.get_binding_text("jump")), "Jump"],
		["MOUSE", "Aim direction"],
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
	var cc := CenterContainer.new()
	cc.add_child(close)
	box.add_child(cc)
	popup_htp.set_meta("close_btn", close)


## Create a styled key badge for displaying control inputs.
func _key_badge(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(80, 22)
	var s := StyleBoxFlat.new()
	s.bg_color = P_KEY_BG
	s.border_color = P_BTN_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(CORNER)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
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

## Create the Settings popup with volume, mouse, and control rebinding options.
func _add_settings() -> void:
	popup_set = _popup_shell("Settings")
	var box : VBoxContainer = popup_set.get_meta("content")

	# Fixed-height clip wrapper prevents the popup from growing when
	# child content (e.g. rebind text) changes size.
	var clip_wrapper := Control.new()
	clip_wrapper.custom_minimum_size = Vector2(280, 360)
	clip_wrapper.clip_contents = true
	clip_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(clip_wrapper)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = false
	clip_wrapper.add_child(scroll)
	_settings_scroll = scroll

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	# Volume section
	content.add_child(_section_header("Volume"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	var music_row := _make_slider_row("Music", 0, 100, 5, input_mgr.volume_music, func(val: float):
		input_mgr.volume_music = val
		input_mgr.mark_dirty()
		bgm_player.volume_db = input_mgr.volume_to_db(val)
		if val > 0 and not bgm_player.playing:
			bgm_player.play()
		_play_sfx(sfx_hover))
	content.add_child(music_row)
	_slider_music = _find_slider_in_row(music_row)

	var sfx_row := _make_slider_row("SFX", 0, 100, 5, input_mgr.volume_sfx, func(val: float):
		input_mgr.volume_sfx = val
		input_mgr.mark_dirty()
		sfx_player.volume_db = input_mgr.sfx_to_db(val)
		_play_sfx(sfx_hover))
	content.add_child(sfx_row)
	_slider_sfx = _find_slider_in_row(sfx_row)

	content.add_child(_spacer(6))

	# Mouse section
	content.add_child(_section_header("Mouse"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	var sens_row := _make_slider_row("Sensitivity", 10, 300, 10,
		int(input_mgr.mouse_sensitivity * 100), func(val: float):
			input_mgr.mouse_sensitivity = val / 100.0
			input_mgr.mark_dirty()
			_play_sfx(sfx_hover))
	content.add_child(sens_row)
	_slider_sens = _find_slider_in_row(sens_row)

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
	inv_btn.button_pressed = input_mgr.mouse_inverted
	inv_btn.focus_mode = Control.FOCUS_ALL
	inv_btn.add_theme_color_override("font_color", P_TEXT)
	inv_btn.toggled.connect(func(on: bool):
		input_mgr.mouse_inverted = on
		input_mgr.mark_dirty()
		_play_sfx(sfx_click))
	invert_row.add_child(inv_btn)
	_invert_btn = inv_btn

	content.add_child(_spacer(6))

	# Control rebind section
	_rebind_buttons.clear()
	var categories : Dictionary = input_mgr.get_actions_by_category()
	for cat_name in categories:
		content.add_child(_section_header(cat_name))
		content.add_child(_divider())
		content.add_child(_spacer(2))

		for action_name in categories[cat_name]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.clip_contents = true
			content.add_child(row)

			var lbl := Label.new()
			lbl.text = input_mgr.get_label(action_name)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.clip_text = true
			lbl.add_theme_font_override("font", font_body)
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", P_TEXT)
			row.add_child(lbl)

			var bind_btn := _make_rebind_button(action_name)
			row.add_child(bind_btn)
			_rebind_buttons[action_name] = bind_btn

		content.add_child(_spacer(4))

	# Reset to defaults button
	var reset_btn := _make_button("Reset Defaults", true)
	reset_btn.custom_minimum_size = Vector2(160, 26)
	reset_btn.pressed.connect(func():
		_play_sfx(sfx_click)
		_cancel_rebind()
		input_mgr.reset_to_defaults()

		# Update sliders in-place (no rebuild, no flicker)
		if is_instance_valid(_slider_music):
			_slider_music.set_value_no_signal(input_mgr.volume_music)
			_update_slider_pct(_slider_music)
		if is_instance_valid(_slider_sfx):
			_slider_sfx.set_value_no_signal(input_mgr.volume_sfx)
			_update_slider_pct(_slider_sfx)
		if is_instance_valid(_slider_sens):
			_slider_sens.set_value_no_signal(int(input_mgr.mouse_sensitivity * 100))
			_update_slider_pct(_slider_sens)
		if is_instance_valid(_invert_btn):
			_invert_btn.set_pressed_no_signal(input_mgr.mouse_inverted)

		# Update all rebind button labels
		for action_name in _rebind_buttons:
			var btn : Button = _rebind_buttons[action_name]
			if is_instance_valid(btn):
				btn.text = input_mgr.get_binding_text(action_name)

		# Sync audio players to new default values
		bgm_player.volume_db = input_mgr.volume_to_db(input_mgr.volume_music)
		sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
		if input_mgr.volume_music > 0 and not bgm_player.playing:
			bgm_player.play()

		# Keep focus on the reset button
		reset_btn.grab_focus())
	var rc := CenterContainer.new()
	rc.add_child(reset_btn)
	content.add_child(rc)

	content.add_child(_spacer(6))

	# Save and Back buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	var save_btn := _make_button("Save", false)
	save_btn.custom_minimum_size = Vector2(100, 26)
	save_btn.pressed.connect(func():
		_cancel_rebind()
		input_mgr.save_settings()
		_play_sfx(sfx_click)
		_close_popup(popup_set)
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus())

	# Disconnect previous dirty callback if rebuilding
	if _dirty_cb.is_valid() and input_mgr.dirty_changed.is_connected(_dirty_cb):
		input_mgr.dirty_changed.disconnect(_dirty_cb)

	# Enable/disable Save button based on unsaved changes
	_dirty_cb = func(dirty: bool):
		if not is_instance_valid(save_btn):
			return
		save_btn.disabled = not dirty
		save_btn.focus_mode = Control.FOCUS_ALL if dirty else Control.FOCUS_NONE
		save_btn.mouse_filter = Control.MOUSE_FILTER_STOP if dirty else Control.MOUSE_FILTER_IGNORE
	input_mgr.dirty_changed.connect(_dirty_cb)

	# Initialize as disabled
	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_child(save_btn)

	var back_btn := _make_button("Back", false)
	back_btn.custom_minimum_size = Vector2(100, 26)
	back_btn.pressed.connect(func():
		_play_sfx(sfx_back)
		_try_close_settings())
	btn_row.add_child(back_btn)

	var cc := CenterContainer.new()
	cc.add_child(btn_row)
	content.add_child(cc)
	popup_set.set_meta("close_btn", back_btn)

	# Clear dirty state from initialization
	input_mgr.clear_dirty()
	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ═════════════════════════════════════════════════════════════════════
#  REBIND BUTTON FACTORY
# ═════════════════════════════════════════════════════════════════════

## Create a button that displays the current key binding and enters rebind mode on click.
func _make_rebind_button(action_name: String) -> Button:
	var btn := Button.new()
	btn.text = input_mgr.get_binding_text(action_name)
	btn.custom_minimum_size = Vector2(120, 22)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_body)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", P_GOLD)
	btn.add_theme_color_override("font_hover_color", P_GOLD)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_GOLD)

	# Normal style
	var sn := StyleBoxFlat.new()
	sn.bg_color = P_KEY_BG
	sn.border_color = P_BTN_BORDER
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 6
	sn.content_margin_right = 6
	sn.content_margin_top = 2
	sn.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", sn)

	# Hover state
	var sh := sn.duplicate()
	sh.border_color = P_FRAME_HILITE
	btn.add_theme_stylebox_override("hover", sh)

	# Focus state
	var sf := sn.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	# Pressed/listening state
	var sp := sn.duplicate()
	sp.bg_color = P_FRAME_BORDER
	sp.border_color = P_GOLD
	btn.add_theme_stylebox_override("pressed", sp)

	btn.pressed.connect(func():
		_start_rebind(action_name, btn))

	return btn


## Start listening for a key/mouse press to rebind an action.
func _start_rebind(action_name: String, btn: Button) -> void:
	_cancel_rebind()
	_rebind_action = action_name
	_rebind_btn = btn
	var cancel_key = str(input_mgr.get_binding_text("pause"))
	if action_name == "pause":
		btn.text = "Press a key..."
	else:
		btn.text = "... %s to cancel" % cancel_key
	btn.add_theme_color_override("font_color", P_GOLD)
	_play_sfx(sfx_click)


## Cancel the current rebind operation without saving changes.
func _cancel_rebind() -> void:
	if _rebind_btn and is_instance_valid(_rebind_btn) and _rebind_action != "":
		_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
		_rebind_btn.add_theme_color_override("font_color", P_GOLD)
	_rebind_action = ""
	_rebind_btn = null


## Create a horizontal slider row with label, slider, and percentage display.
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
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	slider.custom_minimum_size = Vector2(110, 16)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL

	# Track style
	var track := StyleBoxFlat.new()
	track.bg_color = P_FRAME_BORDER
	track.set_corner_radius_all(1)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)

	# Filled portion
	var fill := StyleBoxFlat.new()
	fill.bg_color = P_BTN
	fill.set_corner_radius_all(1)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
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
		if is_instance_valid(pct):
			pct.text = "%d%%" % int(val)
		on_change.call(val))

	return row


## Find the HSlider child inside a slider row created by _make_slider_row().
func _find_slider_in_row(row: HBoxContainer) -> HSlider:
	for child in row.get_children():
		if child is HSlider:
			return child
	return null


## Update the percent label next to a slider (sibling at index + 1).
func _update_slider_pct(slider: HSlider) -> void:
	var row := slider.get_parent()
	if row == null:
		return
	var idx := slider.get_index()
	if idx + 1 < row.get_child_count():
		var pct := row.get_child(idx + 1)
		if pct is Label:
			pct.text = "%d%%" % int(slider.value)


## Create a small square grabber texture for slider controls.
func _make_grabber_texture(fill: Color, border: Color) -> ImageTexture:
	var tex_size := 10
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(border)
	# Inner fill inset by 2 pixels
	for y in range(2, tex_size - 2):
		for x in range(2, tex_size - 2):
			img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


## Create a thin horizontal divider line.
func _divider() -> ColorRect:
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = P_FRAME_OUTER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return div


## Create a gold section header label.
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

## Create a popup panel container with title and content area.
func _popup_shell(title_text: String) -> PanelContainer:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapper)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(300, 0)
	var os := StyleBoxFlat.new()
	os.bg_color = P_FRAME_OUTER
	os.border_color = P_FRAME_BORDER
	os.set_border_width_all(BORDER)
	os.set_corner_radius_all(CORNER + 1)
	os.content_margin_left = 4
	os.content_margin_right = 4
	os.content_margin_top = 4
	os.content_margin_bottom = 4
	outer.add_theme_stylebox_override("panel", os)
	wrapper.add_child(outer)

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
	outer.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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

## Show a popup with fade-in and scale animation.
func _open_popup(panel: PanelContainer) -> void:
	popup_active = panel
	overlay.visible = true
	panel.visible = true
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, POPUP_FADE_IN_TIME)
	tw.tween_property(panel, "scale", Vector2.ONE, POPUP_SCALE_IN_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var close_btn = panel.get_meta("close_btn", null)
	if close_btn:
		(close_btn as Button).call_deferred("grab_focus")


## Hide a popup with fade-out and scale animation.
func _close_popup(panel: PanelContainer) -> void:
	popup_active = null
	if not is_instance_valid(panel):
		overlay.visible = false
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, POPUP_FADE_OUT_TIME)
	tw.tween_property(panel, "scale", Vector2(0.95, 0.95), POPUP_SCALE_OUT_TIME).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		overlay.visible = false
		if is_instance_valid(panel):
			panel.visible = false
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus())


# ═════════════════════════════════════════════════════════════════════
#  UNSAVED CHANGES CONFIRMATION
# ═════════════════════════════════════════════════════════════════════

## Check for unsaved changes before closing settings.  If dirty, show
## a confirmation dialog; otherwise close immediately.
func _try_close_settings() -> void:
	_cancel_rebind()
	if popup_active != popup_set:
		_close_popup(popup_active)
		return
	if input_mgr.is_dirty():
		_show_confirm_popup()
	else:
		_close_popup(popup_set)


## Build and show the "Unsaved changes" confirmation dialog.
func _show_confirm_popup() -> void:
	if popup_confirm and is_instance_valid(popup_confirm):
		popup_confirm.get_parent().queue_free()

	# Build a small centered panel
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wrapper)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = P_FRAME_INNER
	ps.border_color = P_FRAME_BORDER
	ps.set_border_width_all(BORDER)
	ps.set_corner_radius_all(CORNER + 1)
	ps.content_margin_left = 18;  ps.content_margin_right = 18
	ps.content_margin_top = 14;   ps.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", ps)
	wrapper.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var msg := Label.new()
	msg.text = "You have unsaved changes."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_override("font", font_body)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", P_TEXT)
	vb.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	# "Save & Close" button
	var save_btn := _make_button("Save", false)
	save_btn.custom_minimum_size = Vector2(90, 26)
	save_btn.pressed.connect(func():
		_play_sfx(sfx_click)
		input_mgr.save_settings()
		_close_confirm_popup()
		_close_popup(popup_set))
	btn_row.add_child(save_btn)

	# "Discard" button — reverts bindings and rebuilds the settings UI
	var discard_btn := _make_button("Discard", true)
	discard_btn.custom_minimum_size = Vector2(90, 26)
	discard_btn.pressed.connect(func():
		_play_sfx(sfx_back)
		input_mgr.load_settings()
		# Sync audio players to reverted values
		bgm_player.volume_db = input_mgr.volume_to_db(input_mgr.volume_music)
		sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
		_close_confirm_popup()
		# Tear down and rebuild settings so button labels show reverted bindings
		popup_active = null
		overlay.visible = false
		var old_wrapper := popup_set.get_parent()
		if old_wrapper:
			old_wrapper.queue_free()
		else:
			popup_set.queue_free()
		_add_settings()
		popup_set.visible = false
		overlay.visible = false
		# Return focus to main menu
		if menu_buttons.size() > 0:
			menu_buttons[0].grab_focus())
	btn_row.add_child(discard_btn)

	popup_confirm = panel

	# Animate in
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, POPUP_FADE_IN_TIME)
	tw.tween_property(panel, "scale", Vector2.ONE, POPUP_SCALE_IN_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	save_btn.call_deferred("grab_focus")


## Dismiss the confirmation dialog without taking action.
func _close_confirm_popup() -> void:
	if popup_confirm and is_instance_valid(popup_confirm):
		var wrapper_node := popup_confirm.get_parent()
		if wrapper_node:
			wrapper_node.queue_free()
	popup_confirm = null


# ═════════════════════════════════════════════════════════════════════
#  ENTRANCE ANIMATION
# ═════════════════════════════════════════════════════════════════════

## Fade in the main menu on entrance.
func _entrance_anim() -> void:
	main_vbox.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(main_vbox, "modulate:a", 1.0, TITLE_FADE_IN_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ═════════════════════════════════════════════════════════════════════
#  BUTTON CALLBACKS
# ═════════════════════════════════════════════════════════════════════

## Start Game button handler — transition to grass biome.
func _on_start() -> void:
	_play_sfx(sfx_start)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, START_FADE_OUT_TIME)
	tw.tween_property(bgm_player, "volume_db", VOLUME_BGM_SILENT, START_FADE_OUT_TIME)
	tw.chain().tween_callback(func():
		if is_instance_valid(bgm_player):
			bgm_player.stop()
		get_tree().change_scene_to_file("res://Scene/grass_biome.tscn"))


## How to Play button handler — show the control popup.
func _on_how_to_play() -> void:
	_play_sfx(sfx_click)
	_open_popup(popup_htp)


## Settings button handler — show the settings popup.
func _on_settings() -> void:
	_play_sfx(sfx_click)
	_open_popup(popup_set)


## Exit button handler — fade out and quit the game.
func _on_exit() -> void:
	_play_sfx(sfx_click)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, EXIT_FADE_OUT_TIME)
	tw.tween_property(bgm_player, "volume_db", VOLUME_BGM_SILENT, EXIT_FADE_OUT_TIME)
	tw.chain().tween_callback(func():
		if is_instance_valid(self):
			get_tree().quit())


# ═════════════════════════════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════════════════════════════

## Create a vertical spacer control for layout padding.
func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
