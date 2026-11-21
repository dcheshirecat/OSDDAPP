class_name Screen
extends Control
## Base for scrolling screens. Subclasses implement fill(body: VBoxContainer).
## refresh() rebuilds the content, keeping scroll position.

var scroll: ScrollContainer
var body: VBoxContainer
var args: Dictionary = {}
var auto_refresh := true

func build() -> void:
	args = get_meta("args", {})
	scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(m)
	body = UI.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(body)
	fill(body)

func fill(_b: VBoxContainer) -> void:
	pass

func refresh() -> void:
	if not auto_refresh or body == null:
		return
	var y := scroll.scroll_vertical
	UI.clear(body)
	fill(body)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = y

## Header row with optional back button and title.
func header(text: String, with_back := false, right: Control = null) -> HBoxContainer:
	var h := UI.hbox(10)
	if with_back:
		var b := UI.btn("‹", func(): Main.inst.back(), "soft", 64)
		b.custom_minimum_size.x = 64
		b.add_theme_font_size_override("font_size", 40)
		h.add_child(b)
	var t := UI.title(text, 36)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.clip_text = true
	h.add_child(t)
	if right:
		h.add_child(right)
	return h

func section(text: String) -> Label:
	var l := UI.lbl(text.to_upper(), 20, UI.MUTED, true)
	return l
