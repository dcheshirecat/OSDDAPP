extends Screen

var aid: String

func fill(b: VBoxContainer) -> void:
	aid = args.id
	var d: Dictionary = DB.alters[aid]
	var owned := Game.owns(aid)
	b.add_child(header(Game.alter_name(aid) if owned else "Not met yet", true))

	# hero: full body over colored backdrop, headshot overlapping
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 520)
	var bg := Panel.new()
	var sb := UI.box(UI.alter_bg(aid), 30, 0)
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	hero.add_child(bg)
	# soft circles for depth
	for i in 3:
		var circ := Panel.new()
		circ.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.22 - i * 0.05), 400, 0))
		var r := 260 + i * 120
		circ.size = Vector2(r, r)
		circ.position = Vector2(420 - r / 2.0, 300 - r / 2.0)
		bg.add_child(circ)
	var body_tex := UI.body(aid, 480)
	body_tex.custom_minimum_size = Vector2.ZERO
	body_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	body_tex.offset_left = 170
	body_tex.offset_top = 24
	body_tex.offset_right = -10
	body_tex.offset_bottom = -16
	if not owned:
		body_tex.modulate = Color(0.2, 0.15, 0.3, 0.85)
	bg.add_child(body_tex)
	var head := UI.portrait(aid, 150, owned)
	head.position = Vector2(24, 24)
	hero.add_child(head)
	var rar := UI.chip(DB.RARITY_NAMES[int(d.rarity)], DB.RARITY_COLORS[int(d.rarity)], Color.WHITE, "star-formation")
	rar.position = Vector2(24, 186)
	hero.add_child(rar)
	b.add_child(hero)

	# identity card
	var ic := UI.card()
	var iv := UI.vbox(10)
	var nh := UI.hbox(10)
	nh.add_child(UI.lbl(Game.alter_name(aid) if owned else "???", 34, UI.TEXT, true))
	nh.add_child(UI.lbl("(" + Game.alter_pronouns(aid) + ")" if owned else "", 22, UI.MUTED))
	nh.add_child(UI.spacer())
	if owned:
		nh.add_child(UI.stars(Game.state.roster[aid].stars, int(d.rarity), 26))
	iv.add_child(nh)
	var role: Dictionary = DB.roles[d.role]
	var rh := UI.hbox(10)
	rh.add_child(UI.icon_badge(role.icon, Color(role.color), 46))
	rh.add_child(UI.lbl(role.name, 26, Color(role.color).darkened(0.25), true))
	iv.add_child(rh)
	iv.add_child(UI.lbl(role.desc, 21, UI.MUTED, false, true))
	var tf := HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 8)
	tf.add_theme_constant_override("v_separation", 8)
	for t in d.traits:
		tf.add_child(UI.chip(t, UI.CARD_SOFT, UI.PRIMARY_DARK))
	iv.add_child(tf)
	if owned:
		iv.add_child(UI.lbl(d.bio, 23, UI.TEXT, false, true))
		var q := UI.lbl("“" + d.quote + "”", 23, UI.PRIMARY_DARK, false, true)
		iv.add_child(q)
	ic.add_child(iv)
	b.add_child(ic)

	if not owned:
		_unowned(b, d)
		return

	var r: Dictionary = Game.state.roster[aid]
	# level
	var lc := UI.card()
	var lv := UI.vbox(10)
	var lh := UI.hbox(10)
	lh.add_child(UI.lbl("Level %d" % r.level, 28, UI.TEXT, true))
	lh.add_child(UI.spacer())
	lh.add_child(UI.lbl("Power %d" % Game.power_rating(aid), 22, UI.MUTED, true))
	lv.add_child(lh)
	if r.level < Game.MAX_LEVEL:
		lv.add_child(UI.bar(r.xp, Game.xp_to_next(r.level), UI.PRIMARY, 16))
		lv.add_child(UI.lbl("%d / %d XP · stars raise all skills by 20%% each" % [r.xp, Game.xp_to_next(r.level)], 19, UI.MUTED))
		var tb := UI.btn("Practice together  (%d coins)" % Game.train_cost(aid), func():
			if Game.train(aid):
				Main.inst.toast("%s reached level %d!" % [Game.alter_name(aid), Game.state.roster[aid].level])
			else:
				Main.inst.toast("Not enough coins."), "soft", 64)
		tb.disabled = Game.state.coins < Game.train_cost(aid)
		lv.add_child(tb)
	else:
		lv.add_child(UI.lbl("Max level!", 22, UI.GOOD, true))
	lc.add_child(lv)
	b.add_child(lc)

	# skills
	b.add_child(section("Skills"))
	var sc := UI.card()
	var sv := UI.vbox(12)
	var maxv := 1.0
	for s in DB.SKILLS:
		maxv = max(maxv, Game.skill(aid, s).base + Game.skill(aid, s).hi)
	for s in DB.SKILLS:
		var sk := Game.skill(aid, s)
		if sk.base <= 0 and sk.hi <= 0:
			continue
		var row := UI.hbox(10)
		var chip := UI.skill_chip(s)
		chip.custom_minimum_size.x = 220
		row.add_child(chip)
		var bv := UI.vbox(2)
		bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bv.add_child(UI.bar(sk.base + sk.hi, maxv * 1.05, DB.SKILL_COLORS[s], 14))
		bv.add_child(UI.lbl("%d  (+%d–%d)" % [sk.base, sk.lo, sk.hi], 19, UI.MUTED, true))
		row.add_child(bv)
		sv.add_child(row)
	sv.add_child(UI.lbl("Base skill plus a random roll in the range. The fronter counts fully; teammates add a share.", 19, UI.MUTED, false, true))
	sc.add_child(sv)
	b.add_child(sc)

	# equipment
	b.add_child(section("Comfort items"))
	var eq := UI.hbox(14)
	for slot in 2:
		eq.add_child(_slot(slot))
	b.add_child(eq)

	# bonds
	var bonds := Game.top_bonds(aid, 4)
	b.add_child(section("Closest bonds"))
	var bc := UI.card()
	var bvb := UI.vbox(10)
	if bonds.is_empty():
		bvb.add_child(UI.lbl("Bonds grow when alters work on tasks together. Each bond level gives +2% when they team up.", 21, UI.MUTED, false, true))
	for bd in bonds:
		var bh := UI.hbox(12)
		bh.add_child(UI.portrait(bd.id, 64))
		var bn := UI.vbox(2)
		bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bn.add_child(UI.lbl(Game.alter_name(bd.id), 23, UI.TEXT, true))
		bn.add_child(UI.lbl("%d tasks together" % bd.count, 19, UI.MUTED))
		bh.add_child(bn)
		bh.add_child(UI.chip("Bond %d" % bd.level, UI.ACCENT, Color.WHITE, "hearts"))
		bvb.add_child(bh)
	bc.add_child(bvb)
	b.add_child(bc)

	# cosmetics
	b.add_child(UI.btn("Customize name, pronouns & look", _customize, "soft"))
	var resident: bool = aid in Game.state.headspace_residents
	b.add_child(UI.btn("Remove from headspace room" if resident else "Show in headspace room", func():
		if resident:
			Game.state.headspace_residents.erase(aid)
		elif Game.state.headspace_residents.size() < 8:
			Game.state.headspace_residents.append(aid)
		else:
			Main.inst.toast("The room fits 8 alters at a time.")
		Game.mark(), "ghost", 60))

func _unowned(b: VBoxContainer, d: Dictionary) -> void:
	var c := UI.card(UI.CARD_SOFT)
	var v := UI.vbox(12)
	v.add_child(UI.lbl("This alter hasn't made themselves known yet. Keep Discovering!", 23, UI.TEXT, false, true))
	var tf := HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 8)
	for s in d.skills:
		tf.add_child(UI.skill_chip(s))
	v.add_child(tf)
	var r := int(d.rarity)
	if r < 5:
		var price: int = Game.SHARD_PRICE[r]
		var bt := UI.btn("Invite with %d memory shards (have %d)" % [price, Game.state.shards], func():
			if Game.shard_buy(aid):
				Main.inst.toast("%s has joined the system!" % d.name), "accent")
		bt.disabled = Game.state.shards < price
		v.add_child(bt)
	c.add_child(v)
	b.add_child(c)

func _slot(slot: int) -> Control:
	var iid: String = Game.state.roster[aid].equip[slot]
	var c := UI.card(UI.CARD if iid != "" else UI.CARD_SOFT, 16)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(10)
	if iid != "":
		var it: Dictionary = DB.comfort[iid]
		h.add_child(UI.icon_badge(it.icon, DB.RARITY_COLORS[int(it.rarity)], 56))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UI.lbl(it.name, 20, UI.TEXT, true, true)
		v.add_child(n)
		v.add_child(UI.lbl(_bonus_text(it.bonus), 18, UI.MUTED, false, true))
		h.add_child(v)
	else:
		h.add_child(UI.icon_badge("chest", Color("cfc6dc"), 56))
		h.add_child(UI.lbl("Empty slot", 21, UI.MUTED, true))
	c.add_child(h)
	return UI.tappable(c, func(): _pick_item(slot))

static func _bonus_text(bonus: Dictionary) -> String:
	var parts := []
	for s in bonus:
		parts.append("+%d %s" % [bonus[s], s])
	return " ".join(parts)

func _pick_item(slot: int) -> void:
	var v := UI.vbox(12)
	v.add_child(UI.title("Choose a comfort item", 30))
	var cur: String = Game.state.roster[aid].equip[slot]
	if cur != "":
		v.add_child(UI.btn("Unequip " + DB.comfort[cur].name, func():
			Game.equip(aid, slot, "")
			Main.inst.close_modal(), "soft", 64))
	var any := false
	for iid in DB.comfort_order:
		var free := Game.item_free(iid)
		if free <= 0:
			continue
		any = true
		var it: Dictionary = DB.comfort[iid]
		var row := UI.card(UI.CARD_SOFT, 14)
		var h := UI.hbox(12)
		h.add_child(UI.icon_badge(it.icon, DB.RARITY_COLORS[int(it.rarity)], 56))
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.lbl("%s  ×%d" % [it.name, free], 22, UI.TEXT, true, true))
		tv.add_child(UI.lbl(_bonus_text(it.bonus) + " · " + it.desc, 18, UI.MUTED, false, true))
		h.add_child(tv)
		row.add_child(h)
		v.add_child(UI.tappable(row, func():
			Game.equip(aid, slot, iid)
			Main.inst.close_modal()))
	if not any:
		v.add_child(UI.lbl("No free comfort items. Find them on tasks, or buy them in the Headspace shop.", 22, UI.MUTED, false, true))
	v.add_child(UI.btn("Close", Main.inst.close_modal, "ghost", 60))
	Main.inst.modal(v)

func _customize() -> void:
	var r: Dictionary = Game.state.roster[aid]
	var v := UI.vbox(14)
	v.add_child(UI.title("Customize", 30))
	v.add_child(UI.lbl("Make them look like someone in your own system, if you like. The look changes both their full body and headshot. Stats stay the same.", 20, UI.MUTED, false, true))
	v.add_child(UI.lbl("Name", 20, UI.MUTED, true))
	var name_edit := LineEdit.new()
	name_edit.text = Game.alter_name(aid)
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 64
	v.add_child(name_edit)
	v.add_child(UI.lbl("Pronouns", 20, UI.MUTED, true))
	var pr := LineEdit.new()
	pr.text = Game.alter_pronouns(aid)
	pr.max_length = 20
	pr.custom_minimum_size.y = 64
	v.add_child(pr)
	v.add_child(UI.lbl("Look", 20, UI.MUTED, true))
	var chosen := [r.portrait]
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var options := [""]
	for a in DB.looks:
		options.append(a.id)
	var tiles := []
	for pid in options:
		var t := TextureRect.new()
		t.texture = DB.portrait_tex(aid if pid == "" else pid)
		t.custom_minimum_size = Vector2(100, 100)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var holder := PanelContainer.new()
		holder.add_child(t)
		tiles.append([holder, pid])
		grid.add_child(UI.tappable(holder, func():
			chosen[0] = pid
			for tt in tiles:
				tt[0].add_theme_stylebox_override("panel", UI.box(UI.PRIMARY if tt[1] == chosen[0] else Color(0, 0, 0, 0), 14, 6))))
	for tt in tiles:
		tt[0].add_theme_stylebox_override("panel", UI.box(UI.PRIMARY if tt[1] == chosen[0] else Color(0, 0, 0, 0), 14, 6))
	v.add_child(grid)
	var h := UI.hbox(12)
	var reset := UI.btn("Reset", func():
		Game.set_cosmetic(aid, "", "", "")
		Main.inst.close_modal(), "soft")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save := UI.btn("Save", func():
		var nn := name_edit.text if name_edit.text != DB.alters[aid].name else ""
		var pp := pr.text if pr.text != DB.alters[aid].pronouns else ""
		Game.set_cosmetic(aid, nn, pp, chosen[0])
		Main.inst.close_modal())
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(reset)
	h.add_child(save)
	v.add_child(h)
	Main.inst.modal(v)
