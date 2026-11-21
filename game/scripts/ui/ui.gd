class_name UI
extends RefCounted
## Code-built UI helpers and theme.

const BG := Color("f5f0fb")
const CARD := Color("ffffff")
const CARD_SOFT := Color("efe8fa")
const PRIMARY := Color("8b6fd6")
const PRIMARY_DARK := Color("6a50b5")
const ACCENT := Color("e07a9a")
const GOOD := Color("4fae7e")
const BAD := Color("d9645f")
const WARN := Color("e6a23c")
const TEXT := Color("2b2233")
const MUTED := Color("7a6f88")
const LINE := Color("e2d9ef")

static var _theme: Theme
static var font_regular: Font
static var font_bold: Font

static func theme() -> Theme:
	if _theme:
		return _theme
	font_regular = load("res://assets/fonts/nunito-400.woff2")
	font_bold = load("res://assets/fonts/nunito-800.woff2")
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	# buttons
	t.set_stylebox("normal", "Button", box(PRIMARY, 18))
	t.set_stylebox("hover", "Button", box(PRIMARY.lightened(0.08), 18))
	t.set_stylebox("pressed", "Button", box(PRIMARY_DARK, 18))
	t.set_stylebox("disabled", "Button", box(Color("cfc6dc"), 18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("f6f3fa"))
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 24)
	# panels
	t.set_stylebox("panel", "PanelContainer", box(CARD, 22, 20))
	t.set_stylebox("panel", "Panel", box(CARD, 22))
	# line edit / text edit
	var le := box(Color("faf8fd"), 14, 14)
	le.border_color = LINE
	le.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", le)
	t.set_color("font_color", "TextEdit", TEXT)
	# progress bar
	t.set_stylebox("background", "ProgressBar", box(Color("e9e2f3"), 10))
	t.set_stylebox("fill", "ProgressBar", box(PRIMARY, 10))
	t.set_constant("separation", "VBoxContainer", 14)
	t.set_constant("separation", "HBoxContainer", 12)
	# scrollbars: slim
	var sb := box(Color(0, 0, 0, 0.12), 4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "HScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "HScrollBar", StyleBoxEmpty.new())
	# check button
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", TEXT)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_font("font", "CheckButton", load("res://assets/fonts/nunito-400.woff2"))
	_theme = t
	return t

static func box(color: Color, radius := 16, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	return s

# ---------------------------------------------------------------- basics
static func lbl(text: String, size := 24, color := TEXT, bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 40
	return l

static func title(text: String, size := 34) -> Label:
	return lbl(text, size, TEXT, true)

static func btn(text: String, cb: Callable, kind := "primary", min_h := 76) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_h
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	match kind:
		"soft":
			_style_btn(b, CARD_SOFT, PRIMARY_DARK)
		"ghost":
			_style_btn(b, Color(0, 0, 0, 0), PRIMARY_DARK)
		"good":
			_style_btn(b, GOOD, Color.WHITE)
		"bad":
			_style_btn(b, BAD, Color.WHITE)
		"accent":
			_style_btn(b, ACCENT, Color.WHITE)
		"gold":
			_style_btn(b, Color("e8b13a"), Color.WHITE)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func _style_btn(b: Button, bg: Color, fg: Color) -> void:
	b.add_theme_stylebox_override("normal", box(bg, 18))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.05) if bg.a > 0 else Color(0, 0, 0, 0.04), 18))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.12) if bg.a > 0 else Color(0, 0, 0, 0.08), 18))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)

static func card(color := CARD, margin := 20, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, margin))
	return p

static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h := true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func icon(name: String, size := 32, color := TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DB.icon(name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Small round colored badge with a white icon.
static func icon_badge(name: String, color: Color, size := 44) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, int(size / 2.0), 0))
	p.custom_minimum_size = Vector2(size, size)
	var i := icon(name, int(size * 0.62), Color.WHITE)
	i.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(i)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

static func chip(text: String, bg: Color, fg := Color.WHITE, icon_name := "", size := 20) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, 14, 10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := hbox(6)
	if icon_name != "":
		h.add_child(icon(icon_name, size + 2, fg))
	h.add_child(lbl(text, size, fg, true))
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

static func skill_chip(s: String, value := -1.0) -> PanelContainer:
	var t: String = DB.SKILL_NAMES[s] if value < 0 else "%s %d" % [s, value]
	return chip(t, DB.SKILL_COLORS[s], Color.WHITE, DB.SKILL_ICONS[s])

static func bar(value: float, max_value: float, color := PRIMARY, h := 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size.y = h
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", box(color, int(h / 2.0), 0))
	b.add_theme_stylebox_override("background", box(Color("e9e2f3"), int(h / 2.0), 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func stars(n: int, max_n: int, size := 22) -> HBoxContainer:
	var h := hbox(1)
	for i in max_n:
		h.add_child(icon("star-formation", size, Color("e8b13a") if i < n else Color("d8d0e4")))
	return h

## Rounded portrait (headshot) with rarity-colored border.
static func portrait(aid: String, size := 120, owned := true) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(size, size)
	var r := int(DB.alters[aid].rarity)
	var sb := box(DB.RARITY_COLORS[r], int(size * 0.22), 0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := Panel.new()
	inner.add_theme_stylebox_override("panel", box(Color.WHITE, int(size * 0.19), 0))
	inner.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bw := maxf(3.0, size * 0.04)
	inner.offset_left = bw
	inner.offset_top = bw
	inner.offset_right = -bw
	inner.offset_bottom = -bw
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)
	var t := TextureRect.new()
	t.texture = DB.portrait_tex(Game.alter_portrait(aid) if owned else aid)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		t.modulate = Color(0.15, 0.12, 0.2, 0.9)
	inner.add_child(t)
	return frame

static func body(aid: String, h := 400) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DB.body_tex(aid)
	t.custom_minimum_size = Vector2(h * 2.0 / 3.0, h)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A labeled on/off switch (custom-drawn so it reads well on light backgrounds).
static func toggle(text: String, on: bool, cb: Callable) -> Control:
	var h := hbox(12)
	h.custom_minimum_size.y = 64
	var l := lbl(text, 22, TEXT, false, true)
	h.add_child(l)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(84, 46)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var knob := Panel.new()
	knob.size = Vector2(36, 36)
	knob.add_theme_stylebox_override("panel", box(Color.WHITE, 18, 0))
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(knob)
	var state := [on]
	var paint := func():
		track.add_theme_stylebox_override("panel", box(GOOD if state[0] else Color("cfc6dc"), 23, 0))
		knob.position = Vector2(43 if state[0] else 5, 5)
	paint.call()
	h.add_child(track)
	return tappable(h, func():
		state[0] = not state[0]
		paint.call()
		cb.call(state[0]))

static func tappable(c: Control, cb: Callable) -> Control:
	# PASS so a parent ScrollContainer still receives drags; only fire on a short tap.
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				c.set_meta("press_pos", e.global_position)
				c.set_meta("press_t", Time.get_ticks_msec())
			elif c.has_meta("press_pos"):
				var moved: float = (e.global_position - c.get_meta("press_pos")).length()
				c.remove_meta("press_pos")
				if moved < 24 and Time.get_ticks_msec() - int(c.get_meta("press_t")) < 900:
					cb.call())
	return c

static func fmt_time(sec: float) -> String:
	var s := int(ceil(sec))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s

static func fmt_minutes(m: float) -> String:
	if m >= 60:
		var h := int(m) / 60
		var r := int(m) % 60
		return "%dh" % h if r == 0 else "%dh %dm" % [h, r]
	return "%dm" % int(m)

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc

static func margin(c: Control, l := 24, t := 16, r := 24, b := 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c)
	return m

static func role_color(aid: String) -> Color:
	return Color(DB.roles[DB.alters[aid].role].color)

static func alter_bg(aid: String) -> Color:
	return Color(DB.alters[aid].art.bg)
