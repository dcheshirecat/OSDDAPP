extends Screen

func fill(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	b.add_child(header("Story"))
	if not s.event_run.is_empty():
		var rc := UI.card(Color("fff4d6"))
		var rv := UI.vbox(10)
		rv.add_child(UI.lbl("In the middle of: " + DB.events[s.event_run.id].name, 24, UI.TEXT, true, true))
		var rh := UI.hbox(10)
		var ab := UI.btn("Give up", func():
			Main.inst.confirm("Give up on this event?", "Spoons spent are not returned. You can try again any time.", "Give up", func(): Game.event_abandon(), "bad"), "soft", 64)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rb := UI.btn("Resume", func(): Main.inst.open_full("event"), "good", 64)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(ab)
		rh.add_child(rb)
		rv.add_child(rh)
		rc.add_child(rv)
		b.add_child(rc)

	for ch in DB.chapters:
		var unlocked: bool = int(ch.id) <= int(s.story.chapter)
		var card := UI.card(UI.CARD if unlocked else UI.CARD_SOFT)
		var v := UI.vbox(12)
		var h := UI.hbox(12)
		h.add_child(UI.icon_badge("open-book" if unlocked else "padlock", UI.ACCENT if unlocked else Color("b9b0c8"), 60))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.lbl("CHAPTER %d" % ch.id, 18, UI.MUTED, true))
		tv.add_child(UI.lbl(ch.title, 28, UI.TEXT, true, true))
		h.add_child(tv)
		v.add_child(h)
		if not unlocked:
			v.add_child(UI.lbl("Finish every event in Chapter %d to unlock." % (int(ch.id) - 1), 20, UI.MUTED, false, true))
			card.add_child(v)
			b.add_child(card)
			continue
		var intro := UI.lbl(ch.intro, 21, UI.TEXT.lightened(0.15), false, true)
		v.add_child(intro)
		for ev_id in ch.events:
			v.add_child(_event_row(ev_id))
		card.add_child(v)
		b.add_child(card)
	b.add_child(UI.lbl("Story events are multi-step challenges. At each step, choose an approach and who fronts. Each failure costs a star; 3 stars on the first clear earns a comfort item.", 19, UI.MUTED, false, true))

func _event_row(ev_id: String) -> Control:
	var ev: Dictionary = DB.events[ev_id]
	var unlocked := Game.event_unlocked(ev_id)
	var stars := Game.event_stars(ev_id)
	var c := UI.card(UI.CARD_SOFT if unlocked else Color("f3f0f7"), 16)
	var v := UI.vbox(6)
	var h := UI.hbox(10)
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.lbl(ev.name, 23, UI.TEXT if unlocked else UI.MUTED, true, true))
	var meta := "Tier %d · %d steps · %d spoons" % [int(ev.tier), ev.nodes.size(), int(ev.spoons)]
	tv.add_child(UI.lbl(meta, 18, UI.MUTED))
	h.add_child(tv)
	if unlocked:
		h.add_child(UI.stars(stars, 3, 26))
	else:
		h.add_child(UI.icon("padlock", 30, UI.MUTED))
	v.add_child(h)
	if ev.cw != null and Game.state.settings.cw:
		v.add_child(UI.chip("Content note: " + ev.cw, Color("fde8d8"), Color("9a4b2a")))
	c.add_child(v)
	if not unlocked:
		return c
	return UI.tappable(c, func(): start_flow(ev_id))

static func start_flow(ev_id: String) -> void:
	var ev: Dictionary = DB.events[ev_id]
	if not Game.state.event_run.is_empty():
		Main.inst.toast("Finish or give up the current event first.")
		return
	var go := func():
		TeamPicker.open("event", ev_id, func(team, _f):
			var err := Game.start_event(ev_id, team)
			if err != "":
				Main.inst.toast(err)
			else:
				Main.inst.open_full("event"))
	if ev.cw != null and Game.state.settings.cw:
		var v := UI.vbox(14)
		v.add_child(UI.title("Content note", 30))
		v.add_child(UI.lbl("“%s” includes: %s." % [ev.name, ev.cw], 24, UI.TEXT, false, true))
		v.add_child(UI.lbl("It's handled gently and without graphic detail, but it's okay to skip it or come back later. You can turn these notes off in Settings.", 21, UI.MUTED, false, true))
		var h := UI.hbox(12)
		var no := UI.btn("Not now", Main.inst.close_modal, "soft")
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var yes := UI.btn("Continue", func():
			Main.inst.close_modal()
			go.call())
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(no)
		h.add_child(yes)
		v.add_child(h)
		v.add_child(UI.btn("Support resources", func():
			Main.inst.close_modal()
			Main.inst.push("settings", {"page": "resources"}), "ghost", 56))
		Main.inst.modal(v)
	else:
		go.call()
