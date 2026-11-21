extends Screen
## Step-by-step story event ("away mission"): pick an approach + fronter per step.

var phase := "intro"       # intro | choose | result | done
var selected := ""         # chosen fronter for this step
var last := {}             # last attempt result
var final := {}            # completion rewards

func build() -> void:
	auto_refresh = false
	var run: Dictionary = Game.state.event_run
	if run.is_empty():
		Main.inst.back.call_deferred()
		return
	phase = "intro" if run.node == 0 and run.log.is_empty() else "choose"
	var node0: Dictionary = DB.events[run.id].nodes[min(run.node, DB.events[run.id].nodes.size() - 1)]
	selected = run.fronter if run.fronter != "" else _best_for(run.team, node0.choices[0].skill)
	super.build()

func on_back() -> bool:
	if phase == "done":
		_leave()
		return true
	return false

func redraw() -> void:
	UI.clear(body)
	fill(body)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 0

func fill(b: VBoxContainer) -> void:
	var run: Dictionary = Game.state.event_run
	if phase == "done":
		_fill_done(b)
		return
	var ev: Dictionary = DB.events[run.id]
	b.add_child(header(ev.name, true))
	# progress dots
	var dots := UI.hbox(8)
	for i in ev.nodes.size():
		var col := UI.LINE
		if i < run.node:
			col = UI.GOOD
		elif i == run.node:
			col = UI.PRIMARY
		var d := Panel.new()
		d.add_theme_stylebox_override("panel", UI.box(col, 8, 0))
		d.custom_minimum_size = Vector2(0, 12)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dots.add_child(d)
	b.add_child(dots)

	if phase == "intro":
		var c := UI.card()
		var v := UI.vbox(14)
		v.add_child(UI.lbl(ev.intro, 26, UI.TEXT, false, true))
		var tr := UI.hbox(0)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		for aid in run.team:
			tr.add_child(UI.body(aid, 230))
		v.add_child(tr)
		v.add_child(UI.btn("Let's go", func():
			phase = "choose"
			redraw(), "good"))
		c.add_child(v)
		b.add_child(c)
		return

	if Game.event_finished():
		_finish()
		return

	var node: Dictionary = ev.nodes[run.node]
	# scene card: current fronter full-body + situation
	var sc := UI.card(UI.alter_bg(selected).lightened(0.35), 20)
	var sh := UI.hbox(8)
	var fb := UI.body(selected, 260)
	sh.add_child(fb)
	var sv := UI.vbox(10)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(UI.lbl("STEP %d OF %d" % [run.node + 1, ev.nodes.size()], 18, UI.MUTED, true))
	sv.add_child(UI.lbl(node.text, 25, UI.TEXT, false, true))
	sh.add_child(sv)
	sc.add_child(sh)
	b.add_child(sc)

	if phase == "result":
		_fill_result(b)
		return

	# fronter selection
	b.add_child(section("Who fronts?"))
	var tr2 := UI.hbox(10)
	for aid in run.team:
		var v2 := UI.vbox(4)
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p := UI.portrait(aid, 110)
		if aid == selected:
			var ring := PanelContainer.new()
			var sb := UI.box(Color(0, 0, 0, 0), 30, 4)
			sb.border_color = UI.ACCENT
			sb.set_border_width_all(5)
			ring.add_theme_stylebox_override("panel", sb)
			ring.add_child(p)
			v2.add_child(UI.center(ring))
		else:
			v2.add_child(UI.center(p))
		var n := UI.lbl(Game.alter_name(aid), 19, UI.ACCENT if aid == selected else UI.TEXT, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v2.add_child(n)
		var cost := Game.switch_cost(run.team, run.fronter, aid)
		var sub := "fronting" if aid == run.fronter else ("switch +%d stress" % cost if cost > 0 else "free switch")
		if run.fronter == "":
			sub = ""
		var sl := UI.lbl(sub, 16, UI.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v2.add_child(sl)
		tr2.add_child(UI.tappable(v2, func():
			selected = aid
			redraw()))
	b.add_child(tr2)

	# choices
	b.add_child(section("Approach"))
	for i in node.choices.size():
		var ch: Dictionary = node.choices[i]
		var chance := Game.event_choice_chance(run.team, selected, ch.skill)
		var col := UI.GOOD if chance >= 0.7 else (UI.WARN if chance >= 0.4 else UI.BAD)
		var cc := UI.card()
		var h := UI.hbox(12)
		var tv := UI.vbox(6)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.lbl(ch.label, 25, UI.TEXT, true, true))
		tv.add_child(UI.skill_chip(ch.skill, Game.skill_avg(selected, ch.skill)))
		var best := _best_for(run.team, ch.skill)
		if best != selected:
			tv.add_child(UI.lbl("Best fit: %s (%d%%)" % [Game.alter_name(best), int(round(Game.event_choice_chance(run.team, best, ch.skill) * 100))], 18, UI.MUTED, true))
		h.add_child(tv)
		h.add_child(UI.lbl("%d%%" % int(round(chance * 100)), 38, col, true))
		cc.add_child(h)
		b.add_child(UI.tappable(cc, func(): _attempt(i)))
	b.add_child(UI.lbl("Tip: the fronter's skill counts fully, teammates add 25%. Gatekeepers make switching free.", 18, UI.MUTED, false, true))

func _best_for(team: Array, skill: String) -> String:
	var best: String = team[0]
	for aid in team:
		if Game.skill_avg(aid, skill) > Game.skill_avg(best, skill):
			best = aid
	return best

func _attempt(i: int) -> void:
	last = Game.event_attempt(i, selected)
	phase = "result"
	redraw()

func _fill_result(b: VBoxContainer) -> void:
	var ok: bool = last.ok
	var c := UI.card(Color("e3f5ea") if ok else Color("fdeeee"))
	var v := UI.vbox(12)
	var h := UI.hbox(12)
	h.add_child(UI.icon_badge("check-mark" if ok else "spiral-bloom", UI.GOOD if ok else UI.BAD, 56))
	h.add_child(UI.title("Success!" if ok else "Stumble", 30))
	v.add_child(h)
	v.add_child(UI.lbl(last.text, 25, UI.TEXT, false, true))
	if last.stress > 0:
		v.add_child(UI.chip("+%d stress" % int(last.stress), UI.BAD, Color.WHITE, "lightning-trio"))
	c.add_child(v)
	b.add_child(c)
	if ok:
		var label := "Finish" if Game.event_finished() else "Continue"
		b.add_child(UI.btn(label, func():
			phase = "choose"
			redraw(), "good"))
	else:
		var retry := UI.btn("Try again  (%d spoon)" % Game.event_retry_cost(), func():
			if Game.event_retry():
				phase = "choose"
				redraw(), "primary")
		retry.disabled = not Game.event_can_retry()
		b.add_child(retry)
		b.add_child(UI.btn("Push through anyway  (lose a star)", func():
			Game.event_push_through()
			phase = "choose"
			redraw(), "soft"))
		b.add_child(UI.btn("Take a break (leave event)", func():
			Main.inst.confirm("Leave this event?", "Spoons spent are not returned. You can try again any time.", "Leave", func():
				Game.event_abandon()
				_leave(), "bad"), "ghost", 60))

func _finish() -> void:
	final = Game.complete_event()
	phase = "done"
	redraw()

func _fill_done(b: VBoxContainer) -> void:
	var ev: Dictionary = DB.events[final.id]
	b.add_child(header(ev.name))
	var c := UI.card()
	var v := UI.vbox(14)
	v.add_child(UI.center(UI.stars(final.stars, 3, 56)))
	v.add_child(UI.lbl(ev.outro, 25, UI.TEXT, false, true))
	var rw := HFlowContainer.new()
	rw.add_theme_constant_override("h_separation", 8)
	rw.add_theme_constant_override("v_separation", 8)
	rw.add_child(UI.chip("+%d" % final.sparks, Color("a66bd6"), Color.WHITE, "sparkles"))
	rw.add_child(UI.chip("+%d" % final.coins, Color("e8b13a"), Color.WHITE, "two-coins"))
	rw.add_child(UI.chip("+%d XP each" % final.xp, UI.PRIMARY))
	rw.add_child(UI.chip("+2 comm", UI.ACCENT, Color.WHITE, "hearts"))
	v.add_child(rw)
	if not final.first:
		v.add_child(UI.lbl("Replay rewards are reduced. Best stars are kept.", 19, UI.MUTED, false, true))
	if final.item != "":
		v.add_child(UI.lbl("Perfect clear! Comfort item: " + DB.comfort[final.item].name, 22, UI.GOOD, true, true))
	if not final.levels.is_empty():
		var names := []
		for a in final.levels:
			names.append(Game.alter_name(a))
		v.add_child(UI.lbl("Level up: " + ", ".join(names), 22, UI.ACCENT, true, true))
	c.add_child(v)
	b.add_child(c)
	if final.chapter_unlocked > 0:
		var ch: Dictionary = DB.chapters[final.chapter_unlocked - 1]
		var cc := UI.card(Color("fff4d6"))
		var cv := UI.vbox(10)
		cv.add_child(UI.lbl("NEW CHAPTER UNLOCKED  ·  +300 sparks", 19, UI.MUTED, true))
		cv.add_child(UI.title("Chapter %d: %s" % [ch.id, ch.title], 30))
		cv.add_child(UI.lbl(ch.intro, 22, UI.TEXT, false, true))
		cv.add_child(UI.lbl("New kinds of tasks will appear on tomorrow's board (or shuffle it now).", 19, UI.MUTED, false, true))
		cc.add_child(cv)
		b.add_child(cc)
	b.add_child(UI.btn("Back to the story", _leave, "good"))

func _leave() -> void:
	Main.inst.show_tab("story")
