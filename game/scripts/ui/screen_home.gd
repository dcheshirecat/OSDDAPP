extends Screen

func fill(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var gear := UI.btn("", func(): Main.inst.push("settings"), "soft", 64)
	gear.icon = DB.icon("cog")
	gear.expand_icon = true
	gear.custom_minimum_size = Vector2(64, 64)
	gear.add_theme_color_override("icon_normal_color", UI.PRIMARY_DARK)
	gear.add_theme_constant_override("icon_max_width", 36)
	b.add_child(header(_greeting(), false, gear))

	# headspace weather
	var st: float = s.stress
	var w := _weather(st)
	var wc := UI.card(Color(w[2]), 22)
	var wh := UI.hbox(16)
	wh.add_child(UI.icon_badge(w[3], Color(w[2]).darkened(0.35), 64))
	var wv := UI.vbox(4)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.add_child(UI.lbl("Headspace weather: " + w[0], 24, UI.TEXT, true, true))
	wv.add_child(UI.lbl(w[1], 21, UI.TEXT.lightened(0.2), false, true))
	wh.add_child(wv)
	wc.add_child(wh)
	b.add_child(wc)

	# daily check-in
	if not s.daily.login:
		var dc := UI.card(Color("fff4d6"))
		var dv := UI.vbox(10)
		dv.add_child(UI.lbl("Daily check-in", 26, UI.TEXT, true))
		dv.add_child(UI.lbl("Say good morning to the system. Everyone's here, even the quiet ones.", 22, UI.MUTED, false, true))
		dv.add_child(UI.btn("Check in  (+%d sparks, +%d coins)" % [Game.DAILY_SPARKS, Game.DAILY_COINS], func():
			if Game.claim_daily():
				Main.inst.toast("Checked in! See you tomorrow."), "gold"))
		dc.add_child(dv)
		b.add_child(dc)

	# active tasks
	b.add_child(section("Right now"))
	var ready := 0
	for r in s.active:
		if Game.chore_remaining(r) <= 0:
			ready += 1
	var tc := UI.card()
	var th := UI.hbox(16)
	th.add_child(UI.icon_badge("alarm-clock", UI.PRIMARY, 60))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: int = s.daily.board.size() - s.daily.done.size() - s.active.size()
	tv.add_child(UI.lbl("%d of %d task slots in use" % [s.active.size(), Game.max_active()], 24, UI.TEXT, true))
	if ready > 0:
		tv.add_child(UI.lbl("%d ready to collect!" % ready, 22, UI.GOOD, true))
	else:
		tv.add_child(UI.lbl("%d tasks left on today's board" % max(0, left), 22, UI.MUTED))
	th.add_child(tv)
	th.add_child(UI.btn("Open", func(): Main.inst.show_tab("tasks"), "soft", 64))
	tc.add_child(th)
	b.add_child(tc)

	# story
	var next := _next_event()
	var sc := UI.card()
	var sh := UI.hbox(16)
	sh.add_child(UI.icon_badge("open-book", UI.ACCENT, 60))
	var sv := UI.vbox(2)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ch: Dictionary = DB.chapters[int(s.story.chapter) - 1]
	sv.add_child(UI.lbl("Chapter %d · %s" % [ch.id, ch.title], 24, UI.TEXT, true, true))
	if next != "":
		sv.add_child(UI.lbl("Next: " + DB.events[next].name, 22, UI.MUTED, false, true))
	else:
		sv.add_child(UI.lbl("All story events cleared. Replay for better stars!", 22, UI.MUTED, false, true))
	sh.add_child(sv)
	sh.add_child(UI.btn("Go", func(): Main.inst.show_tab("story"), "soft", 64))
	sc.add_child(sh)
	b.add_child(sc)

	# discover + headspace quick cards
	var row := UI.hbox(14)
	row.add_child(_quick("sparkles", "Discover", "%d sparks" % int(s.sparks), Color("a66bd6"), func(): Main.inst.show_tab("discover")))
	var rest_txt := "Rest ready" if Game.rest_ready_in() <= 0 else "Rest in " + UI.fmt_time(Game.rest_ready_in())
	row.add_child(_quick("sofa", "Headspace", rest_txt, Color("5fae9c"), func(): Main.inst.show_tab("headspace")))
	b.add_child(row)

	# system stats
	b.add_child(section("Our system"))
	var stc := UI.card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	var stats := [
		["Alters met", "%d / %d" % [s.roster.size(), DB.alters.size()]],
		["Tasks done", str(int(s.stats.chores))],
		["Story events", "%d / %d" % [s.story.done.size(), DB.events.size()]],
		["Communication", "%d / 100" % int(s.comm)],
	]
	for st2 in stats:
		var l := UI.lbl(st2[0], 22, UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		grid.add_child(UI.lbl(st2[1], 22, UI.TEXT, true))
	stc.add_child(grid)
	b.add_child(stc)

	if not s.log.is_empty():
		b.add_child(section("Journal"))
		var lc := UI.card(UI.CARD_SOFT)
		var lv := UI.vbox(6)
		for line in s.log.slice(0, 6):
			lv.add_child(UI.lbl(line, 21, UI.TEXT, false, true))
		lc.add_child(lv)
		b.add_child(lc)

func _quick(ic: String, t: String, sub: String, col: Color, cb: Callable) -> Control:
	var c := UI.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.add_child(UI.icon_badge(ic, col, 56))
	v.add_child(UI.lbl(t, 24, UI.TEXT, true))
	v.add_child(UI.lbl(sub, 20, UI.MUTED))
	c.add_child(v)
	return UI.tappable(c, cb)

func _greeting() -> String:
	var h: int = Time.get_datetime_dict_from_system().hour
	var g := "Good evening"
	if h < 5:
		g = "Up late"
	elif h < 12:
		g = "Good morning"
	elif h < 18:
		g = "Good afternoon"
	return "%s, %s" % [g, Game.state.system_name]

func _weather(st: float) -> Array:
	if st < 20:
		return ["Sunny & calm", "Everyone feels settled. A great time for harder tasks.", "dff3e4", "sun"]
	if st < 45:
		return ["A few clouds", "Manageable. Keep some self-care on the list.", "e3ecfa", "spiral-bloom"]
	if st < 70:
		return ["Overcast & noisy", "Stress is making tasks harder. Try resting or a grounding exercise.", "fdf0d8", "lightning-trio"]
	return ["Stormy", "It's a hard day. Be gentle with yourselves: rest, drink water, let a Soother help.", "fbe0e0", "lightning-trio"]

func _next_event() -> String:
	for ch in DB.chapters:
		for e in ch.events:
			if Game.event_unlocked(e) and not Game.state.story.done.has(e):
				return e
	return ""
