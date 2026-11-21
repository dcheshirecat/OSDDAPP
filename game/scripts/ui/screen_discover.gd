extends Screen

func fill(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	b.add_child(header("Discover"))
	var f := Game.featured()

	# featured banner with full-body art
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 470)
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(30)
	sb.bg_color = Color("3b2d63")
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	banner.add_child(bg)
	for i in 14:
		var star := UI.icon("sparkles", 18 + (i * 7) % 26, Color(1, 1, 1, 0.18 + (i % 4) * 0.08))
		star.position = Vector2((i * 137) % 640 + 10, (i * 89) % 420 + 20)
		bg.add_child(star)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 90
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -30)
	var b4 := UI.body(f.r4, 330)
	b4.size_flags_vertical = Control.SIZE_SHRINK_END
	var b5 := UI.body(f.r5, 380)
	b5.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(b4)
	row.add_child(b5)
	bg.add_child(row)
	var tv := UI.vbox(2)
	tv.position = Vector2(28, 22)
	tv.add_child(UI.lbl("THIS WEEK'S SPOTLIGHT", 19, Color("d9cdfa"), true))
	tv.add_child(UI.lbl("%s & %s" % [DB.alters[f.r5].name, DB.alters[f.r4].name], 32, Color.WHITE, true))
	banner.add_child(tv)
	var chip5 := UI.chip("★5 " + DB.roles[DB.alters[f.r5].role].name, DB.RARITY_COLORS[5])
	chip5.position = Vector2(28, 400)
	banner.add_child(chip5)
	var chip4 := UI.chip("★4 " + DB.roles[DB.alters[f.r4].role].name, DB.RARITY_COLORS[4])
	chip4.position = Vector2(28, 352)
	banner.add_child(chip4)
	b.add_child(banner)

	b.add_child(UI.lbl("Someone new may be ready to make themselves known. Spotlight alters have a boosted chance (50% of their rarity tier).", 20, UI.MUTED, false, true))

	var pr := UI.hbox(12)
	var p1 := UI.btn("Discover ×1\n%d sparks" % Game.PULL_COST, func(): _pull(1), "primary", 110)
	p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1.disabled = s.sparks < Game.PULL_COST
	var p10 := UI.btn("Discover ×10\n%d sparks" % Game.PULL10_COST, func(): _pull(10), "gold", 110)
	p10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p10.disabled = s.sparks < Game.PULL10_COST
	pr.add_child(p1)
	pr.add_child(p10)
	b.add_child(pr)

	# pity info
	var ic := UI.card(UI.CARD_SOFT)
	var iv := UI.vbox(8)
	iv.add_child(UI.lbl("Guaranteed ★4 or better within %d discoveries" % (Game.PITY_4 - int(s.pity4)), 21, UI.TEXT, true, true))
	iv.add_child(UI.lbl("Guaranteed ★5 within %d discoveries" % (Game.PITY_5 - int(s.pity5)), 21, UI.TEXT, true, true))
	var rates := []
	for r in range(5, 0, -1):
		rates.append("★%d %.0f%%" % [r, Game.GACHA_RATES[r]])
	iv.add_child(UI.lbl("Rates: " + "  ".join(rates), 19, UI.MUTED, false, true))
	iv.add_child(UI.lbl("Meeting someone again raises their stars (stronger skills). At max stars, you get memory shards instead.", 19, UI.MUTED, false, true))
	ic.add_child(iv)
	b.add_child(ic)

	# shard exchange
	var sc := UI.card()
	var sv := UI.vbox(10)
	var sh := UI.hbox(10)
	sh.add_child(UI.icon_badge("crystal-cluster", Color("62b6cb"), 52))
	var st := UI.vbox(0)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(UI.lbl("Memory shards: %d" % int(s.shards), 24, UI.TEXT, true))
	st.add_child(UI.lbl("Invite a specific alter (up to ★4) from the Team screen.", 19, UI.MUTED, false, true))
	sh.add_child(st)
	sv.add_child(sh)
	var prices := []
	for r in range(1, 5):
		prices.append("★%d: %d" % [r, Game.SHARD_PRICE[r]])
	sv.add_child(UI.lbl("  ".join(prices), 19, UI.MUTED))
	sc.add_child(sv)
	b.add_child(sc)

func _pull(n: int) -> void:
	var res := Game.pull(n)
	if res.is_empty():
		Main.inst.toast("Not enough sparks.")
		return
	if n == 1:
		_reveal_single(res[0])
	else:
		_reveal_many(res)

static func _result_tag(r: Dictionary) -> String:
	if r.new:
		return "NEW!"
	if r.star_up:
		return "★ UP"
	return "+%d shards" % r.shards

func _reveal_single(r: Dictionary) -> void:
	var aid: String = r.id
	var d: Dictionary = DB.alters[aid]
	var v := UI.vbox(12)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 520)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UI.box(UI.alter_bg(aid), 26, 0))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	stage.add_child(bg)
	var glow := Panel.new()
	glow.add_theme_stylebox_override("panel", UI.box(DB.RARITY_COLORS[int(d.rarity)].lightened(0.3), 300, 0))
	glow.size = Vector2(420, 420)
	glow.position = Vector2(80, 60)
	glow.modulate.a = 0.5
	bg.add_child(glow)
	var body := UI.body(aid, 480)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.custom_minimum_size = Vector2.ZERO
	body.offset_top = 20
	body.offset_bottom = -20
	bg.add_child(body)
	var tag := UI.chip(_result_tag(r), UI.ACCENT if r.new else UI.PRIMARY)
	tag.position = Vector2(20, 20)
	stage.add_child(tag)
	v.add_child(stage)
	var nh := UI.hbox(10)
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nh.add_child(UI.lbl(d.name, 36, UI.TEXT, true))
	nh.add_child(UI.stars(int(d.rarity), int(d.rarity), 26))
	v.add_child(nh)
	var role := UI.lbl("%s · %s" % [DB.roles[d.role].name, d.pronouns], 22, UI.MUTED, true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(role)
	var q := UI.lbl("“" + d.quote + "”", 22, UI.PRIMARY_DARK, false, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var h := UI.hbox(12)
	var meet := UI.btn("Meet them", func():
		Main.inst.close_modal()
		Main.inst.push("alter", {"id": aid}), "soft")
	meet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := UI.btn("Welcome!", Main.inst.close_modal)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(meet)
	h.add_child(ok)
	v.add_child(h)
	Main.inst.modal(v)
	if not Game.state.settings.reduce_motion:
		body.pivot_offset = Vector2(300, 480)
		body.scale = Vector2(0.6, 0.6)
		body.modulate.a = 0
		var tw := body.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "scale", Vector2.ONE, 0.5).set_delay(0.15)
		tw.tween_property(body, "modulate:a", 1.0, 0.3).set_delay(0.15)
		var gt := glow.create_tween().set_loops(4)
		gt.tween_property(glow, "modulate:a", 0.9, 0.6)
		gt.tween_property(glow, "modulate:a", 0.4, 0.6)

func _reveal_many(res: Array) -> void:
	var v := UI.vbox(14)
	v.add_child(UI.title("Discovered!", 32))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	var best := 0
	var i := 0
	for r in res:
		var d: Dictionary = DB.alters[r.id]
		best = max(best, int(d.rarity))
		var tv := UI.vbox(2)
		tv.add_child(UI.portrait(r.id, 104))
		var n := UI.lbl(d.name, 16, UI.TEXT, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		n.custom_minimum_size.x = 104
		tv.add_child(n)
		var t := UI.lbl(_result_tag(r), 15, UI.ACCENT if r.new else UI.MUTED, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(t)
		grid.add_child(UI.tappable(tv, func():
			Main.inst.close_modal()
			Main.inst.push("alter", {"id": r.id})))
		if not Game.state.settings.reduce_motion:
			tv.modulate.a = 0
			var tw := tv.create_tween()
			tw.tween_interval(0.08 * i)
			tw.tween_property(tv, "modulate:a", 1.0, 0.25)
		i += 1
	v.add_child(grid)
	if best >= 4:
		v.add_child(UI.lbl("A ★%d alter stepped forward!" % best, 24, DB.RARITY_COLORS[best].darkened(0.2), true))
	v.add_child(UI.btn("Welcome, everyone!", Main.inst.close_modal))
	Main.inst.modal(v)
