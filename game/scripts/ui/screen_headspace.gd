extends Screen

const COLS := 5
const ROWS := 4
const ROOM_W := 676.0
const ROOM_H := 640.0
const WALL_H := 150.0

static var edit_mode := false
var room: Control
var walkers := []

func fill(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var shop := UI.btn("Shop", _shop, "soft", 60)
	b.add_child(header("Headspace", false, shop))
	b.add_child(UI.lbl("The inner world everyone shares. Decorate it, rest here, and check in with each other.", 20, UI.MUTED, false, true))

	room = Control.new()
	room.custom_minimum_size = Vector2(ROOM_W, ROOM_H)
	room.clip_contents = true
	var mood := _mood_color(s.stress)
	var wall := Panel.new()
	wall.add_theme_stylebox_override("panel", UI.box(mood, 28, 0))
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.add_child(wall)
	# window + floor
	var floor_p := Panel.new()
	var fsb := UI.box(Color("e9dcc9"), 0, 0)
	fsb.corner_radius_bottom_left = 28
	fsb.corner_radius_bottom_right = 28
	floor_p.add_theme_stylebox_override("panel", fsb)
	floor_p.position = Vector2(0, WALL_H)
	floor_p.size = Vector2(ROOM_W, ROOM_H - WALL_H)
	room.add_child(floor_p)
	var sun := UI.icon("sun" if s.stress < 45 else "spiral-bloom", 70, Color(1, 1, 1, 0.75))
	sun.position = Vector2(ROOM_W - 110, 30)
	room.add_child(sun)
	# grid cells
	var cw := ROOM_W / COLS
	var ch := (ROOM_H - WALL_H) / ROWS
	for y in ROWS:
		for x in COLS:
			var key := "%d,%d" % [x, y]
			var did: String = s.layout.get(key, "")
			var cell := Control.new()
			cell.position = Vector2(x * cw, WALL_H + y * ch)
			cell.size = Vector2(cw, ch)
			if edit_mode:
				var outline := Panel.new()
				var osb := UI.box(Color(1, 1, 1, 0.25), 12, 0)
				osb.border_color = Color(0.5, 0.4, 0.7, 0.5)
				osb.set_border_width_all(2)
				outline.add_theme_stylebox_override("panel", osb)
				outline.position = Vector2(4, 4)
				outline.size = Vector2(cw - 8, ch - 8)
				outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(outline)
			if did != "":
				var badge := UI.icon_badge(DB.decor[did].icon, Color("b08968"), int(min(cw, ch) - 26))
				badge.position = Vector2((cw - badge.custom_minimum_size.x) / 2, (ch - badge.custom_minimum_size.y) / 2)
				cell.add_child(badge)
			if edit_mode:
				UI.tappable(cell, func(): _pick_decor(key))
			else:
				cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			room.add_child(cell)
	# residents
	walkers.clear()
	var residents: Array = []
	for aid in s.headspace_residents:
		if Game.owns(aid):
			residents.append(aid)
	for i in residents.size():
		var aid: String = residents[i]
		var w := Control.new()
		w.size = Vector2(110, 165)
		w.position = Vector2(30 + (i * 151) % int(ROOM_W - 140), WALL_H - 60 + (i * 97) % int(ROOM_H - WALL_H - 80))
		var bt := UI.body(aid, 165)
		bt.custom_minimum_size = Vector2(110, 165)
		w.add_child(bt)
		if Game.busy(aid):
			w.modulate.a = 0.35
		if not edit_mode:
			UI.tappable(w, func(): _say(w, aid))
		else:
			w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(w)
		walkers.append(w)
		if not s.settings.reduce_motion and not Game.busy(aid):
			_wander(w)
	b.add_child(UI.center(room))

	var eb := UI.btn("Done decorating" if edit_mode else "Decorate room", func():
		edit_mode = not edit_mode
		refresh(), "accent" if edit_mode else "soft", 64)
	b.add_child(eb)
	if edit_mode:
		b.add_child(UI.lbl("Tap a square to place or remove decor. Decor only gives its bonus while it's placed.", 19, UI.MUTED, false, true))

	# actions
	var ar := UI.hbox(12)
	var rr := Game.rest_ready_in()
	var rest := UI.btn("Rest together\n-%d stress, +1 spoon" % int(Game.REST_AMOUNT + Game.decor_effect("rest_bonus")) if rr <= 0 else "Rest again in\n" + UI.fmt_time(rr), func():
		if Game.rest():
			Main.inst.toast("Everyone curls up for a while. Stress eases."), "good", 100)
	rest.disabled = rr > 0
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var meet := UI.btn("System meeting\n+3 comm, -5 stress" if not s.daily.meeting else "Met today ✓", _meeting, "primary", 100)
	meet.disabled = s.daily.meeting
	meet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.add_child(rest)
	ar.add_child(meet)
	b.add_child(ar)

	# active effects
	b.add_child(section("Room effects"))
	var ec := UI.card()
	var ev := UI.vbox(8)
	var any := false
	for key in s.layout:
		var did: String = s.layout[key]
		if DB.decor.has(did):
			any = true
			var row := UI.hbox(10)
			row.add_child(UI.icon_badge(DB.decor[did].icon, Color("b08968"), 44))
			var l := UI.lbl("%s: %s" % [DB.decor[did].name, DB.decor[did].desc], 20, UI.TEXT, false, true)
			row.add_child(l)
			ev.add_child(row)
	if not any:
		ev.add_child(UI.lbl("No decor placed yet. Buy some in the shop, then tap Decorate room.", 20, UI.MUTED, false, true))
	ec.add_child(ev)
	b.add_child(ec)
	b.add_child(UI.lbl("Choose who hangs out here from each alter's page (up to 8).", 19, UI.MUTED, false, true))

func _process(_d: float) -> void:
	pass

func _wander(w: Control) -> void:
	if not is_instance_valid(w):
		return
	var target := Vector2(randf_range(10, ROOM_W - 120), randf_range(WALL_H - 70, ROOM_H - 175))
	var dist := w.position.distance_to(target)
	var tw := w.create_tween()
	tw.tween_interval(randf_range(1.0, 4.0))
	tw.tween_property(w, "position", target, dist / 60.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _wander(w))

func _say(w: Control, aid: String) -> void:
	var bubble := UI.card(Color.WHITE, 14, 16)
	var lines: Array = [DB.alters[aid].quote]
	var st: float = Game.state.stress
	if st >= 60:
		lines.append("It's a lot today. Maybe we rest?")
	if DB.alters[aid].role == "little":
		lines.append("Can we play? Pleeease?")
	if DB.alters[aid].role == "caretaker":
		lines.append("Have you had water today?")
	if DB.alters[aid].role == "protector":
		lines.append("I'm keeping watch. You're safe.")
	var l := UI.lbl(Game.alter_name(aid) + ": " + lines[randi() % lines.size()], 19, UI.TEXT, false, true)
	l.custom_minimum_size.x = 300
	bubble.add_child(l)
	bubble.position = Vector2(clamp(w.position.x - 100, 0, ROOM_W - 320), max(0, w.position.y - 90))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(bubble)
	var tw := bubble.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bubble.queue_free)

func _meeting() -> void:
	if not Game.system_meeting():
		return
	var v := UI.vbox(14)
	v.add_child(UI.title("System meeting", 30))
	var names := []
	for aid in Game.state.headspace_residents.slice(0, 4):
		names.append(Game.alter_name(aid))
	var topics := ["what to have for dinner this week", "who's going to make the dentist call", "a new rule: no buying art supplies without a vote", "how everyone's been feeling lately", "a plan for the next hard day", "what everyone is grateful for"]
	v.add_child(UI.lbl("Everyone gathers in the headspace. %s talk about %s." % [", ".join(names), topics[randi() % topics.size()]], 23, UI.TEXT, false, true))
	v.add_child(UI.lbl("System communication +3 · Stress -5", 21, UI.GOOD, true))
	v.add_child(UI.btn("Meeting adjourned", Main.inst.close_modal))
	Main.inst.modal(v)

func _mood_color(st: float) -> Color:
	if st < 20:
		return Color("cde8f6")
	if st < 45:
		return Color("d9def0")
	if st < 70:
		return Color("d6d1df")
	return Color("bdb6c9")

func _pick_decor(key: String) -> void:
	var v := UI.vbox(12)
	v.add_child(UI.title("Place decor", 30))
	var cur: String = Game.state.layout.get(key, "")
	if cur != "":
		v.add_child(UI.btn("Remove " + DB.decor[cur].name, func():
			Game.place_decor(key, "")
			Main.inst.close_modal(), "soft", 64))
	var any := false
	for did in Game.state.decor_owned:
		any = true
		var d: Dictionary = DB.decor[did]
		var placed := Game.decor_placed(did)
		var row := UI.card(UI.CARD_SOFT, 14)
		var h := UI.hbox(12)
		h.add_child(UI.icon_badge(d.icon, Color("b08968"), 52))
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.lbl(d.name + ("  (placed – will move)" if placed else ""), 22, UI.TEXT, true, true))
		tv.add_child(UI.lbl(d.desc, 18, UI.MUTED, false, true))
		h.add_child(tv)
		row.add_child(h)
		v.add_child(UI.tappable(row, func():
			Game.place_decor(key, did)
			Main.inst.close_modal()))
	if not any:
		v.add_child(UI.lbl("You don't own any decor yet. Visit the shop!", 22, UI.MUTED, false, true))
	v.add_child(UI.btn("Close", Main.inst.close_modal, "ghost", 60))
	Main.inst.modal(v)

static var shop_tab := "decor"

func _shop() -> void:
	var v := UI.vbox(12)
	_fill_shop(v)
	Main.inst.modal(v, true, true)

func _fill_shop(v: VBoxContainer) -> void:
	UI.clear(v)
	var hh := UI.hbox(10)
	var t := UI.title("Shop", 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(t)
	hh.add_child(UI.chip("%d" % int(Game.state.coins), Color("e8b13a"), Color.WHITE, "two-coins"))
	var x := UI.btn("✕", Main.inst.close_modal, "ghost", 56)
	x.custom_minimum_size.x = 56
	hh.add_child(x)
	v.add_child(hh)
	var tabs := UI.hbox(10)
	for tb in [["decor", "Headspace decor"], ["comfort", "Comfort items"]]:
		var b := UI.btn(tb[1], func():
			shop_tab = tb[0]
			_fill_shop(v), "primary" if shop_tab == tb[0] else "soft", 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	v.add_child(tabs)
	if shop_tab == "decor":
		for did in DB.decor_order:
			var d: Dictionary = DB.decor[did]
			var owned: bool = did in Game.state.decor_owned
			v.add_child(_shop_row(d.icon, Color("b08968"), d.name, d.desc, int(d.price), owned, func():
				if Game.buy_decor(did):
					Main.inst.toast("Bought %s! Tap Decorate room to place it." % d.name)
					_fill_shop(v)
				else:
					Main.inst.toast("Not enough coins.")))
	else:
		v.add_child(UI.lbl("Equip comfort items from an alter's page. Each alter has 2 slots.", 19, UI.MUTED, false, true))
		for iid in DB.comfort_order:
			var it: Dictionary = DB.comfort[iid]
			var have := int(Game.state.inventory.get(iid, 0))
			var desc := "%s · %s%s" % [_bonus(it.bonus), it.desc, ("  (own %d)" % have) if have > 0 else ""]
			v.add_child(_shop_row(it.icon, DB.RARITY_COLORS[int(it.rarity)], it.name, desc, int(it.price), false, func():
				if Game.buy_item(iid):
					Main.inst.toast("Bought %s!" % it.name)
					_fill_shop(v)
				else:
					Main.inst.toast("Not enough coins.")))

static func _bonus(bonus: Dictionary) -> String:
	var parts := []
	for s in bonus:
		parts.append("+%d %s" % [bonus[s], s])
	return " ".join(parts)

func _shop_row(ic: String, col: Color, name: String, desc: String, price: int, owned: bool, cb: Callable) -> Control:
	var c := UI.card(UI.CARD_SOFT, 14)
	var h := UI.hbox(12)
	h.add_child(UI.icon_badge(ic, col, 56))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.lbl(name, 22, UI.TEXT, true, true))
	tv.add_child(UI.lbl(desc, 18, UI.MUTED, false, true))
	h.add_child(tv)
	if owned:
		h.add_child(UI.chip("owned", UI.GOOD))
	else:
		var b := UI.btn("%d" % price, cb, "gold", 60)
		b.icon = DB.icon("two-coins")
		b.add_theme_constant_override("icon_max_width", 26)
		b.disabled = Game.state.coins < price
		h.add_child(b)
	c.add_child(h)
	return c
