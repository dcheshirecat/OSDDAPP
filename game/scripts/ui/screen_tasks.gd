extends Screen

var timer_rows := []   # [{run, label, bar, btn}]
var _was_ready := {}

func fill(b: VBoxContainer) -> void:
	timer_rows.clear()
	var s: Dictionary = Game.state
	var refresh_btn := UI.btn("New board (%d)" % Game.BOARD_REFRESH_COST, func():
		Main.inst.confirm("Shuffle today's board?", "Swap today's remaining tasks for a fresh set. Costs %d coins." % Game.BOARD_REFRESH_COST, "Shuffle", func():
			if not Game.refresh_board():
				Main.inst.toast("Not enough coins.")), "soft", 60)
	refresh_btn.add_theme_font_size_override("font_size", 20)
	b.add_child(header("Today's Tasks", false, refresh_btn))

	b.add_child(section("In progress  ·  %d/%d slots" % [s.active.size(), Game.max_active()]))
	if s.active.is_empty():
		var e := UI.card(UI.CARD_SOFT)
		e.add_child(UI.lbl("No tasks running. Pick one from the board below and assemble a team!", 22, UI.MUTED, false, true))
		b.add_child(e)
	for run in s.active:
		b.add_child(_active_card(run))

	b.add_child(section("Today's board"))
	for cid in s.daily.board:
		b.add_child(_board_card(cid))
	var tip := UI.lbl("The board refreshes every day. Self-care tasks lower stress; Work and Errands earn more coins. Story chapters unlock new kinds of tasks.", 19, UI.MUTED, false, true)
	b.add_child(tip)

func _active_card(run: Dictionary) -> Control:
	var c: Dictionary = DB.chores[run.chore]
	var card := UI.card()
	var v := UI.vbox(10)
	var h := UI.hbox(12)
	h.add_child(UI.icon_badge(DB.AREA_ICONS[c.area], UI.PRIMARY, 56))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.lbl(c.name, 24, UI.TEXT, true, true))
	tv.add_child(UI.lbl("%d%% chance · %s fronting" % [int(round(run.chance * 100)), Game.alter_name(run.fronter)], 19, UI.MUTED))
	h.add_child(tv)
	var team_row := UI.hbox(-14)
	for aid in run.team:
		team_row.add_child(UI.portrait(aid, 52))
	h.add_child(team_row)
	v.add_child(h)
	var total: float = float(c.minutes) * 60.0
	var bar := UI.bar(total - Game.chore_remaining(run), total, UI.PRIMARY, 14)
	v.add_child(bar)
	var bh := UI.hbox(10)
	var tl := UI.lbl("", 22, UI.TEXT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(tl)
	var cancel := UI.btn("Stop", func():
		Main.inst.confirm("Stop this task?", "The team comes home and you get half the spoons back.", "Stop task", func(): Game.cancel_chore(run), "bad"), "ghost", 56)
	bh.add_child(cancel)
	var rush := UI.btn("", func():
		if not Game.rush(run):
			Main.inst.toast("Not enough sparks."), "soft", 56)
	bh.add_child(rush)
	var collect := UI.btn("Collect", func(): _collect(run), "good", 56)
	bh.add_child(collect)
	v.add_child(bh)
	card.add_child(v)
	timer_rows.append({"run": run, "label": tl, "bar": bar, "rush": rush, "collect": collect, "cancel": cancel})
	_update_row(timer_rows.back())
	return card

func _update_row(row: Dictionary) -> void:
	var run: Dictionary = row.run
	var rem := Game.chore_remaining(run)
	var total: float = float(DB.chores[run.chore].minutes) * 60.0
	row.bar.value = total - rem
	var done := rem <= 0
	row.label.text = "Done!" if done else UI.fmt_time(rem) + " left"
	row.label.add_theme_color_override("font_color", UI.GOOD if done else UI.TEXT)
	row.collect.visible = done
	row.rush.visible = not done
	row.cancel.visible = not done
	if not done:
		row.rush.text = "Finish now (%d✦)" % Game.rush_cost(run)

func _process(_d: float) -> void:
	for row in timer_rows:
		if is_instance_valid(row.label):
			_update_row(row)

func _board_card(cid: String) -> Control:
	var c: Dictionary = DB.chores[cid]
	var done: bool = cid in Game.state.daily.done
	var running := false
	for r in Game.state.active:
		if r.chore == cid:
			running = true
	var card := UI.card(UI.CARD_SOFT if done or running else UI.CARD)
	var v := UI.vbox(8)
	var h := UI.hbox(12)
	h.add_child(UI.icon_badge(DB.AREA_ICONS[c.area], UI.PRIMARY if not done else Color("b9b0c8"), 56))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.lbl(c.name, 24, UI.TEXT, true, true))
	tv.add_child(UI.lbl(c.desc, 19, UI.MUTED, false, true))
	h.add_child(tv)
	if done:
		h.add_child(UI.chip("done", UI.GOOD))
	elif running:
		h.add_child(UI.chip("running", UI.WARN))
	v.add_child(h)
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 8)
	meta.add_theme_constant_override("v_separation", 6)
	meta.add_child(UI.chip("Tier %d" % int(c.tier), Color("cfc6dc"), UI.TEXT))
	meta.add_child(UI.chip(UI.fmt_minutes(c.minutes), Color("e3ecfa"), UI.TEXT, "alarm-clock", 18))
	meta.add_child(UI.chip("%d" % int(c.spoons), Color("dff3e4"), UI.TEXT, "spoon", 18))
	for s in c.skills:
		meta.add_child(UI.skill_chip(s))
	var rw := Game.chore_rewards(cid)
	meta.add_child(UI.chip("+%d" % rw.coins, Color("fff4d6"), UI.TEXT, "two-coins", 18))
	meta.add_child(UI.chip("+%d" % rw.sparks, Color("f1e6fb"), UI.TEXT, "sparkles", 18))
	if c.has("stress") and float(c.stress) < 0:
		meta.add_child(UI.chip("%d stress" % int(c.stress), Color("dff3e4"), UI.TEXT, "lightning-trio", 18))
	v.add_child(meta)
	card.add_child(v)
	if done or running:
		return card
	return UI.tappable(card, func():
		TeamPicker.open("chore", cid, func(team, fronter):
			var err := Game.start_chore(cid, team, fronter)
			if err != "":
				Main.inst.toast(err)
			else:
				Main.inst.toast("%s is on it!" % Game.alter_name(fronter))))

func _collect(run: Dictionary) -> void:
	var res := Game.collect_chore(run)
	if res.is_empty():
		return
	show_result(res)

static func show_result(res: Dictionary) -> void:
	var c: Dictionary = DB.chores[res.chore]
	var v := UI.vbox(14)
	var ok: bool = res.success
	var head := UI.hbox(12)
	head.add_child(UI.icon_badge("check-mark" if ok else "spiral-bloom", UI.GOOD if ok else UI.WARN, 64))
	var hv := UI.vbox(0)
	hv.add_child(UI.title("Success!" if ok else "Not this time", 32))
	hv.add_child(UI.lbl(c.name, 22, UI.MUTED, false, true))
	head.add_child(hv)
	v.add_child(head)
	var fr: String = res.team[0]
	var line := ""
	if ok:
		line = "The team pulled it off. Someone leaves a little gold star in the journal."
	else:
		line = "It didn't go to plan, and that's okay. Everyone still learned something. We'll try again another day."
	v.add_child(UI.lbl(line, 22, UI.TEXT, false, true))
	var team_row := UI.hbox(8)
	for aid in res.team:
		var tv := UI.vbox(2)
		tv.add_child(UI.portrait(aid, 84))
		if aid in res.levels:
			tv.add_child(UI.chip("LV UP", UI.ACCENT, Color.WHITE, "", 15))
		team_row.add_child(tv)
	v.add_child(team_row)
	var rw := HFlowContainer.new()
	rw.add_theme_constant_override("h_separation", 8)
	rw.add_theme_constant_override("v_separation", 8)
	rw.add_child(UI.chip("+%d XP" % res.xp, UI.PRIMARY))
	if res.coins > 0:
		rw.add_child(UI.chip("+%d" % res.coins, Color("e8b13a"), Color.WHITE, "two-coins"))
	if res.sparks > 0:
		rw.add_child(UI.chip("+%d" % res.sparks, Color("a66bd6"), Color.WHITE, "sparkles"))
	if abs(res.stress) >= 0.5:
		rw.add_child(UI.chip("%+d stress" % int(round(res.stress)), UI.BAD if res.stress > 0 else UI.GOOD, Color.WHITE, "lightning-trio"))
	if res.comm >= 0.5:
		rw.add_child(UI.chip("+%.1f comm" % res.comm, UI.ACCENT, Color.WHITE, "hearts"))
	v.add_child(rw)
	if res.item != "":
		var it: Dictionary = DB.comfort[res.item]
		var ic := UI.card(Color("fff4d6"), 16)
		var ih := UI.hbox(12)
		ih.add_child(UI.icon_badge(it.icon, DB.RARITY_COLORS[int(it.rarity)], 56))
		ih.add_child(UI.lbl("Found a comfort item: " + it.name + "!", 22, UI.TEXT, true, true))
		ic.add_child(ih)
		v.add_child(ic)
	v.add_child(UI.btn("Nice", Main.inst.close_modal, "primary"))
	Main.inst.modal(v)
