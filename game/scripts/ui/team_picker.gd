class_name TeamPicker
extends VBoxContainer
## Modal content for choosing a team of up to 4 alters (+ fronter for chores).

var mode := "chore"          # "chore" or "event"
var target := ""             # chore id or event id
var team: Array = []
var fronter := ""
var on_confirm: Callable
var slots_row: HBoxContainer
var info_box: VBoxContainer
var start_btn: Button
var weights := {}            # skill -> weight (relevance)

static func open(p_mode: String, p_target: String, confirm_cb: Callable) -> void:
	var tp := TeamPicker.new()
	tp.mode = p_mode
	tp.target = p_target
	tp.on_confirm = confirm_cb
	tp._setup()
	Main.inst.modal(tp, true, true)

func _setup() -> void:
	add_theme_constant_override("separation", 14)
	if mode == "chore":
		weights = DB.chores[target].skills
	else:
		for n in DB.events[target].nodes:
			for c in n.choices:
				weights[c.skill] = weights.get(c.skill, 0.0) + 1.0
	_build()
	suggest()

func _relevance(aid: String) -> float:
	var t := 0.0
	for s in weights:
		t += Game.skill_avg(aid, s) * float(weights[s])
	return t

func suggest() -> void:
	team.clear()
	var cands := []
	for aid in Game.state.roster:
		if not Game.busy(aid):
			cands.append(aid)
	if mode == "chore":
		# greedy: add whoever raises the chance most
		for i in 4:
			var best := ""
			var bv := -1.0
			for aid in cands:
				if aid in team:
					continue
				var t2 := team.duplicate()
				t2.append(aid)
				var f := Game.best_fronter(target, t2)
				var v := Game.chore_power(target, t2, f)
				if v > bv:
					bv = v
					best = aid
			if best == "":
				break
			team.append(best)
		fronter = Game.best_fronter(target, team) if not team.is_empty() else ""
	else:
		cands.sort_custom(func(a, b): return _relevance(a) > _relevance(b))
		# prefer a balanced team covering different skills
		team = cands.slice(0, 4)
	_refresh()

func _build() -> void:
	var title_text := ""
	if mode == "chore":
		var c: Dictionary = DB.chores[target]
		title_text = c.name
	else:
		title_text = DB.events[target].name
	var hh := UI.hbox(10)
	var tl := UI.title(title_text, 30)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hh.add_child(tl)
	var x := UI.btn("✕", Main.inst.close_modal, "ghost", 56)
	x.custom_minimum_size.x = 56
	hh.add_child(x)
	add_child(hh)

	var req := HFlowContainer.new()
	req.add_theme_constant_override("h_separation", 8)
	req.add_theme_constant_override("v_separation", 8)
	for s in weights:
		req.add_child(UI.skill_chip(s))
	if mode == "chore":
		for t in DB.chores[target].traits:
			req.add_child(UI.chip("★ " + t, UI.CARD_SOFT, UI.PRIMARY_DARK))
	add_child(req)
	var hint := "Tap alters below to add them (max 4). Tap a team member to make them front; tap the fronter to remove." if mode == "chore" else "Pick up to 4 alters. You'll choose who fronts at each step of the event."
	add_child(UI.lbl(hint, 19, UI.MUTED, false, true))

	slots_row = UI.hbox(10)
	add_child(slots_row)
	info_box = UI.vbox(6)
	add_child(info_box)

	var bh := UI.hbox(10)
	var sug := UI.btn("Suggest team", suggest, "soft", 68)
	sug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(sug)
	start_btn = UI.btn("Start", _start, "good", 68)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(start_btn)
	add_child(bh)

	add_child(UI.lbl("AVAILABLE", 19, UI.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	var ids: Array = Game.state.roster.keys()
	ids.sort_custom(func(a, b): return _relevance(a) > _relevance(b))
	for aid in ids:
		grid.add_child(_avail_tile(aid))
	add_child(grid)

func _avail_tile(aid: String) -> Control:
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := UI.portrait(aid, 110)
	v.add_child(UI.center(p))
	var n := UI.lbl(Game.alter_name(aid), 18, UI.TEXT, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size.x = 110
	v.add_child(n)
	var busy := Game.busy(aid)
	var sub := UI.lbl("busy" if busy else "%d" % _relevance(aid), 17, UI.WARN if busy else UI.MUTED, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if busy:
		v.modulate.a = 0.4
		return v
	return UI.tappable(v, func(): _toggle(aid))

func _toggle(aid: String) -> void:
	if aid in team:
		team.erase(aid)
		if fronter == aid:
			fronter = team[0] if not team.is_empty() else ""
	elif team.size() < 4:
		team.append(aid)
		if fronter == "":
			fronter = aid
	else:
		Main.inst.toast("Teams are 4 alters max.")
	_refresh()

func _slot_tap(aid: String) -> void:
	if mode == "chore" and fronter != aid:
		fronter = aid
	else:
		team.erase(aid)
		if fronter == aid:
			fronter = team[0] if not team.is_empty() else ""
	_refresh()

func _refresh() -> void:
	UI.clear(slots_row)
	for i in 4:
		if i < team.size():
			var aid: String = team[i]
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(130, 150)
			holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var p := UI.portrait(aid, 120)
			p.position = Vector2(5, 0)
			holder.add_child(p)
			if mode == "chore" and aid == fronter:
				var f := UI.chip("FRONT", UI.ACCENT, Color.WHITE, "", 16)
				f.position = Vector2(14, 106)
				holder.add_child(f)
			else:
				var n := UI.lbl(Game.alter_name(aid), 17, UI.TEXT, true)
				n.position = Vector2(8, 122)
				holder.add_child(n)
			slots_row.add_child(UI.tappable(holder, func(): _slot_tap(aid)))
		else:
			var e := Panel.new()
			e.add_theme_stylebox_override("panel", UI.box(UI.CARD_SOFT, 26, 0))
			e.custom_minimum_size = Vector2(120, 120)
			e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slots_row.add_child(e)
	UI.clear(info_box)
	if mode == "chore":
		var c: Dictionary = DB.chores[target]
		var ch := Game.chore_chance(target, team, fronter) if not team.is_empty() else 0.0
		var col := UI.GOOD if ch >= 0.7 else (UI.WARN if ch >= 0.4 else UI.BAD)
		var h := UI.hbox(12)
		h.add_child(UI.lbl("%d%%" % int(round(ch * 100)), 48, col, true))
		var sv := UI.vbox(0)
		sv.add_child(UI.lbl("success chance", 20, UI.MUTED, true))
		sv.add_child(UI.lbl("%s · %d spoons" % [UI.fmt_minutes(c.minutes), int(c.spoons)], 20, UI.MUTED))
		h.add_child(sv)
		info_box.add_child(h)
		if not team.is_empty():
			var bon := Game.team_bonus(team, fronter, c.tags, c.traits)
			var notes: Array = bon.notes
			for n in notes.slice(0, 5):
				info_box.add_child(UI.lbl("• " + n, 18, UI.MUTED, false, true))
			if notes.size() > 5:
				info_box.add_child(UI.lbl("• …and %d more" % (notes.size() - 5), 18, UI.MUTED))
		var err := Game.can_start_chore(target, team, fronter)
		start_btn.disabled = err != ""
		if err != "":
			info_box.add_child(UI.lbl(err, 20, UI.BAD, true, true))
	else:
		var ev: Dictionary = DB.events[target]
		info_box.add_child(UI.lbl("Costs %d spoons · %d steps" % [int(ev.spoons), ev.nodes.size()], 20, UI.MUTED, true))
		start_btn.disabled = team.is_empty() or Game.state.spoons < float(ev.spoons)
		if Game.state.spoons < float(ev.spoons):
			info_box.add_child(UI.lbl("Not enough spoons. Rest in the headspace or wait a bit.", 20, UI.BAD, true, true))

func _start() -> void:
	var t := team.duplicate()
	var f := fronter
	Main.inst.close_modal()
	on_confirm.call(t, f)
