extends Screen

static var sort_mode := "rarity"
static var show_unmet := true

func fill(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	b.add_child(header("Our System  %d/%d" % [s.roster.size(), DB.alters.size()]))

	var row := UI.hbox(8)
	for m in [["rarity", "Rarity"], ["level", "Level"], ["role", "Role"], ["name", "Name"]]:
		var kind := "primary" if sort_mode == m[0] else "soft"
		var bt := UI.btn(m[1], func():
			sort_mode = m[0]
			refresh(), kind, 56)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.add_theme_font_size_override("font_size", 20)
		row.add_child(bt)
	b.add_child(row)
	b.add_child(UI.toggle("Show alters we haven't met yet", show_unmet, func(on):
		show_unmet = on
		refresh()))

	var ids: Array = []
	for id in DB.alter_order:
		if Game.owns(id) or show_unmet:
			ids.append(id)
	ids.sort_custom(_cmp)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for id in ids:
		grid.add_child(alter_tile(id))
	b.add_child(grid)

func _cmp(a: String, c: String) -> bool:
	var oa := Game.owns(a)
	var oc := Game.owns(c)
	if oa != oc:
		return oa
	var da: Dictionary = DB.alters[a]
	var dc: Dictionary = DB.alters[c]
	match sort_mode:
		"level":
			if oa and Game.state.roster[a].level != Game.state.roster[c].level:
				return Game.state.roster[a].level > Game.state.roster[c].level
		"role":
			if da.role != dc.role:
				return da.role < dc.role
		"name":
			return Game.alter_name(a) < Game.alter_name(c)
	if int(da.rarity) != int(dc.rarity):
		return int(da.rarity) > int(dc.rarity)
	return Game.alter_name(a) < Game.alter_name(c)

static func alter_tile(id: String, cb := Callable()) -> Control:
	var owned := Game.owns(id)
	var c := UI.card(UI.CARD, 12, 20)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	var top := Control.new()
	top.custom_minimum_size = Vector2(180, 180)
	var p := UI.portrait(id, 180, owned)
	p.position = Vector2.ZERO
	top.add_child(p)
	if owned:
		var rb := UI.icon_badge(DB.roles[DB.alters[id].role].icon, UI.role_color(id), 44)
		rb.position = Vector2(140, -4)
		top.add_child(rb)
		if Game.busy(id):
			var bz := UI.chip("busy", UI.WARN, Color.WHITE, "", 16)
			bz.position = Vector2(4, 146)
			top.add_child(bz)
	v.add_child(UI.center(top))
	var n := UI.lbl(Game.alter_name(id) if owned else "???", 23, UI.TEXT, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	v.add_child(n)
	var info := UI.hbox(4)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	if owned:
		info.add_child(UI.stars(Game.state.roster[id].stars, int(DB.alters[id].rarity), 18))
		info.add_child(UI.lbl("Lv%d" % Game.state.roster[id].level, 18, UI.MUTED, true))
	else:
		info.add_child(UI.stars(int(DB.alters[id].rarity), int(DB.alters[id].rarity), 18))
	v.add_child(info)
	c.add_child(v)
	var action := cb if cb.is_valid() else func(): Main.inst.push("alter", {"id": id})
	return UI.tappable(c, action)
