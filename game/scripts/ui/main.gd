class_name Main
extends Control
## App shell: top resource bar, screen area, bottom navigation, modal + toast layers.

static var inst: Main

const TABS := [
	{"id": "home", "label": "Home", "icon": "house"},
	{"id": "team", "label": "Team", "icon": "three-friends"},
	{"id": "tasks", "label": "Tasks", "icon": "alarm-clock"},
	{"id": "story", "label": "Story", "icon": "open-book"},
	{"id": "discover", "label": "Discover", "icon": "sparkles"},
	{"id": "headspace", "label": "Inside", "icon": "sofa"},
]
const SCREENS := {
	"home": "res://scripts/ui/screen_home.gd",
	"team": "res://scripts/ui/screen_team.gd",
	"tasks": "res://scripts/ui/screen_tasks.gd",
	"story": "res://scripts/ui/screen_story.gd",
	"discover": "res://scripts/ui/screen_discover.gd",
	"headspace": "res://scripts/ui/screen_headspace.gd",
	"alter": "res://scripts/ui/screen_alter.gd",
	"event": "res://scripts/ui/screen_event.gd",
	"settings": "res://scripts/ui/screen_settings.gd",
	"intro": "res://scripts/ui/screen_intro.gd",
}

var top_bar: PanelContainer
var top_content: HBoxContainer
var screen_holder: Control
var nav_bar: PanelContainer
var nav_buttons := {}
var modal_layer: Control
var toast_layer: VBoxContainer
var current_tab := "home"
var stack: Array = []          # [{"id", "args"}]
var current_screen: Control
var _refresh_queued := false

func _ready() -> void:
	inst = self
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var safe := _safe_top()
	top_bar = PanelContainer.new()
	var tsb := UI.box(Color.WHITE, 0, 16)
	tsb.content_margin_top = 10 + safe
	tsb.content_margin_bottom = 10
	tsb.shadow_color = Color(0.3, 0.2, 0.5, 0.08)
	tsb.shadow_size = 8
	top_bar.add_theme_stylebox_override("panel", tsb)
	top_content = UI.hbox(8)
	top_bar.add_child(top_content)
	col.add_child(top_bar)

	screen_holder = Control.new()
	screen_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_holder.clip_contents = true
	col.add_child(screen_holder)

	nav_bar = PanelContainer.new()
	var nsb := UI.box(Color.WHITE, 0, 4)
	nsb.content_margin_top = 6
	nsb.content_margin_bottom = 10
	nsb.shadow_color = Color(0.3, 0.2, 0.5, 0.1)
	nsb.shadow_size = 10
	nav_bar.add_theme_stylebox_override("panel", nsb)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 0)
	nav_bar.add_child(nh)
	for t in TABS:
		var b := _nav_button(t)
		nh.add_child(b)
		nav_buttons[t.id] = b
	col.add_child(nav_bar)

	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	toast_layer = VBoxContainer.new()
	toast_layer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_layer.offset_top = 130 + safe
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(toast_layer)

	Game.changed.connect(_on_changed)
	Game.toast.connect(toast)
	_build_top()
	if not Game.state.intro_seen:
		open_full("intro")
	else:
		show_tab("home")

func _safe_top() -> int:
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return 0
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if scr.y <= 0:
		return 0
	return int(safe.position.y * get_viewport_rect().size.y / scr.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		back()

# ---------------------------------------------------------------- nav
func _nav_button(t: Dictionary) -> Control:
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.y = 84
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UI.icon(t.icon, 40, UI.MUTED)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.name = "Icon"
	v.add_child(ic)
	var l := UI.lbl(t.label, 18, UI.MUTED, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.name = "Label"
	v.add_child(l)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			show_tab(t.id))
	return v

func _highlight_nav() -> void:
	for id in nav_buttons:
		var on: bool = id == current_tab and stack.is_empty()
		var c := UI.PRIMARY if on else UI.MUTED
		nav_buttons[id].get_node("Icon").modulate = c
		nav_buttons[id].get_node("Label").add_theme_color_override("font_color", c)

func show_tab(id: String) -> void:
	close_all_modals()
	current_tab = id
	stack.clear()
	nav_bar.visible = true
	top_bar.visible = true
	_mount(id, {})
	_highlight_nav()

## Push a sub-screen (with back navigation).
func push(id: String, args := {}) -> void:
	stack.append({"id": id, "args": args})
	_mount(id, args)
	_highlight_nav()

## Full-screen flow without nav bar (intro, event run).
func open_full(id: String, args := {}) -> void:
	stack.append({"id": id, "args": args, "full": true})
	nav_bar.visible = false
	_mount(id, args)

func back() -> void:
	if modal_layer.get_child_count() > 0:
		var top = modal_layer.get_child(modal_layer.get_child_count() - 1)
		if top.get_meta("dismissable", true):
			close_modal()
		return
	if current_screen and current_screen.has_method("on_back") and current_screen.on_back():
		return
	if stack.is_empty():
		if current_tab != "home":
			show_tab("home")
		return
	stack.pop_back()
	nav_bar.visible = true
	for s in stack:
		if s.get("full", false):
			nav_bar.visible = false
	if stack.is_empty():
		_mount(current_tab, {})
	else:
		var s = stack.back()
		_mount(s.id, s.args)
	_highlight_nav()

func _mount(id: String, args: Dictionary) -> void:
	if current_screen:
		current_screen.queue_free()
	var script = load(SCREENS[id])
	var s: Control = script.new()
	s.set_meta("args", args)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_holder.add_child(s)
	current_screen = s
	if s.has_method("build"):
		s.build()

func refresh_screen() -> void:
	if current_screen and current_screen.has_method("refresh"):
		current_screen.refresh()

func _on_changed() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()

func _do_refresh() -> void:
	_refresh_queued = false
	_build_top()
	refresh_screen()

# ---------------------------------------------------------------- top bar
func _build_top() -> void:
	UI.clear(top_content)
	var s: Dictionary = Game.state
	top_content.add_child(_res_chip("spoon", "%d/%d" % [int(s.spoons), Game.spoons_max()], Color("7cbf8e"), "spoons"))
	top_content.add_child(_stress_chip())
	top_content.add_child(_res_chip("hearts", "%d" % int(s.comm), Color("e07a9a"), "comm"))
	top_content.add_child(UI.spacer())
	top_content.add_child(_res_chip("sparkles", _short(s.sparks), Color("a66bd6"), "sparks"))
	top_content.add_child(_res_chip("two-coins", _short(s.coins), Color("e8b13a"), "coins"))

func _short(v) -> String:
	var n := int(v)
	if n >= 100000:
		return "%dk" % (n / 1000)
	if n >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)

func _res_chip(icon_name: String, text: String, color: Color, info: String) -> Control:
	var h := UI.hbox(4)
	h.add_child(UI.icon_badge(icon_name, color, 38))
	h.add_child(UI.lbl(text, 22, UI.TEXT, true))
	return UI.tappable(h, func(): explain(info))

func _stress_chip() -> Control:
	var st: float = Game.state.stress
	var v := UI.vbox(0)
	v.custom_minimum_size.x = 96
	var h := UI.hbox(4)
	h.add_child(UI.icon_badge("lightning-trio", _stress_color(st), 38))
	h.add_child(UI.lbl("%d" % int(st), 22, UI.TEXT, true))
	v.add_child(h)
	return UI.tappable(v, func(): explain("stress"))

static func _stress_color(st: float) -> Color:
	if st >= 70:
		return UI.BAD
	if st >= 45:
		return UI.WARN
	return Color("62b6cb")

func explain(what: String) -> void:
	var texts := {
		"spoons": ["Spoons", "Your energy for the day. Tasks and story events cost spoons. You regain 1 spoon every 20 minutes (faster with some headspace decor), or by resting in the headspace."],
		"stress": ["Stress", "How overwhelmed the system feels (0–100). Failed tasks and hard days raise it; self-care, resting and Soothers lower it. Above 50, every task gets harder. Protectors get stronger as stress rises."],
		"comm": ["System Communication", "How well everyone inside is talking to each other (0–100). Every point gives teams a small bonus. Grow it with journaling, system meetings, therapy homework and story events."],
		"sparks": ["Sparks", "Used to Discover new alters. Earn them from tasks, story events and the daily check-in. There are no real-money purchases."],
		"coins": ["Coins", "Used for training, comfort items and headspace decor. Earned from completing tasks."],
	}
	var t = texts[what]
	var v := UI.vbox(16)
	v.add_child(UI.title(t[0]))
	v.add_child(UI.lbl(t[1], 24, UI.MUTED, false, true))
	v.add_child(UI.btn("Got it", close_modal))
	modal(v)

# ---------------------------------------------------------------- modals
## Show content in a centered card over a dim background. Returns the overlay.
func modal(content: Control, dismissable := true, full := false) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_meta("dismissable", dismissable)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	if dismissable:
		dim.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				close_modal())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := _safe_top()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 40 + safe)
	m.add_theme_constant_override("margin_bottom", 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(m)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.card(UI.CARD, 28, 28)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if full:
		m.add_child(panel)
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		m.add_child(cc)
		cc.add_child(panel)
		panel.custom_minimum_size.x = min(640.0, get_viewport_rect().size.x - 48)
	# scroll if content gets tall
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	modal_layer.add_child(overlay)
	if full:
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		# size the scroll to its content, capped to the screen
		var fit := func():
			var max_h: float = get_viewport_rect().size.y - 160 - safe
			sc.custom_minimum_size.y = min(content.get_combined_minimum_size().y, max_h)
		fit.call_deferred()
		content.minimum_size_changed.connect(fit)
	if not Game.state.settings.get("reduce_motion", false):
		panel.pivot_offset = Vector2(320, 200)
		panel.scale = Vector2(0.94, 0.94)
		panel.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.22)
		tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	return overlay

func close_modal() -> void:
	var n := modal_layer.get_child_count()
	if n > 0:
		var top := modal_layer.get_child(n - 1)
		modal_layer.remove_child(top)
		top.queue_free()

func close_all_modals() -> void:
	while modal_layer.get_child_count() > 0:
		close_modal()

func confirm(title_text: String, body: String, yes_text: String, on_yes: Callable, kind := "primary") -> void:
	var v := UI.vbox(16)
	v.add_child(UI.title(title_text, 30))
	v.add_child(UI.lbl(body, 24, UI.MUTED, false, true))
	var h := UI.hbox(12)
	var no := UI.btn("Cancel", close_modal, "soft")
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.btn(yes_text, func():
		close_modal()
		on_yes.call(), kind)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	v.add_child(h)
	modal(v)

func toast(text: String) -> void:
	var p := UI.card(Color("2b2233"), 18, 18)
	p.add_child(UI.lbl(text, 22, Color.WHITE, true, true))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size.x = 400
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(p)
	var tw := create_tween()
	p.modulate.a = 0
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
