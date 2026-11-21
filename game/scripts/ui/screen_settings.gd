extends Screen

func build() -> void:
	auto_refresh = false
	super.build()

func fill(b: VBoxContainer) -> void:
	match args.get("page", "main"):
		"resources":
			_resources(b)
		"credits":
			_credits(b)
		"about":
			_about(b)
		_:
			_main(b)

func _main(b: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	b.add_child(header("Settings", true))

	var nc := UI.card()
	var nv := UI.vbox(10)
	nv.add_child(UI.lbl("System name", 20, UI.MUTED, true))
	var nh := UI.hbox(10)
	var le := LineEdit.new()
	le.text = s.system_name
	le.max_length = 24
	le.custom_minimum_size.y = 64
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(le)
	nh.add_child(UI.btn("Save", func():
		if le.text.strip_edges() != "":
			Game.state.system_name = le.text.strip_edges()
			Game.mark()
			Main.inst.toast("Saved."), "primary", 64))
	nv.add_child(nh)
	nc.add_child(nv)
	b.add_child(nc)

	var oc := UI.card()
	var ov := UI.vbox(6)
	ov.add_child(_toggle("Show content notes before story events", s.settings.cw, func(on):
		Game.state.settings.cw = on
		Game.mark()))
	ov.add_child(_toggle("Reduce motion", s.settings.reduce_motion, func(on):
		Game.state.settings.reduce_motion = on
		Game.mark()))
	oc.add_child(ov)
	b.add_child(oc)

	b.add_child(section("Backup"))
	var bc := UI.card()
	var bv := UI.vbox(10)
	bv.add_child(UI.lbl("Your progress is saved on this device. To back it up (or move to a new phone), copy your backup code and keep it somewhere safe, like a note or cloud drive. Paste it back in to restore.", 20, UI.MUTED, false, true))
	var bh := UI.hbox(10)
	var ex := UI.btn("Copy backup code", func():
		DisplayServer.clipboard_set(Game.export_code())
		Main.inst.toast("Backup code copied to clipboard."), "soft", 64)
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var im := UI.btn("Restore…", _import, "soft", 64)
	im.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(ex)
	bh.add_child(im)
	bv.add_child(bh)
	bc.add_child(bv)
	b.add_child(bc)

	b.add_child(section("More"))
	b.add_child(_link("heart-plus", "Support & resources", func(): Main.inst.push("settings", {"page": "resources"})))
	b.add_child(_link("open-book", "About this game", func(): Main.inst.push("settings", {"page": "about"})))
	b.add_child(_link("star-formation", "Art & font credits", func(): Main.inst.push("settings", {"page": "credits"})))
	b.add_child(_link("scroll-unfurled", "Replay the welcome", func():
		Game.state.intro_seen = false
		Main.inst.open_full("intro")))
	b.add_child(UI.gap(20))
	b.add_child(UI.btn("Start over", func():
		Main.inst.confirm("Start over?", "This erases ALL progress on this device. Copy a backup code first if you might want it back.", "Erase everything", func():
			Main.inst.confirm("Are you sure?", "This can't be undone.", "Yes, start over", func():
				Game.reset_game()
				Main.inst.open_full("intro"), "bad"), "bad"), "ghost", 60))

func _toggle(text: String, on: bool, cb: Callable) -> Control:
	return UI.toggle(text, on, cb)

func _link(ic: String, text: String, cb: Callable) -> Control:
	var c := UI.card(UI.CARD, 16)
	var h := UI.hbox(12)
	h.add_child(UI.icon_badge(ic, UI.PRIMARY, 48))
	var l := UI.lbl(text, 23, UI.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.lbl("›", 34, UI.MUTED, true))
	c.add_child(h)
	return UI.tappable(c, cb)

func _import() -> void:
	var v := UI.vbox(12)
	v.add_child(UI.title("Restore from backup", 30))
	v.add_child(UI.lbl("Paste your backup code. This replaces your current progress.", 20, UI.MUTED, false, true))
	var te := TextEdit.new()
	te.custom_minimum_size.y = 200
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(te)
	var paste := UI.btn("Paste from clipboard", func(): te.text = DisplayServer.clipboard_get(), "soft", 60)
	v.add_child(paste)
	v.add_child(UI.btn("Restore", func():
		if Game.import_code(te.text):
			Main.inst.close_modal()
			Main.inst.toast("Restored! Welcome back.")
			Main.inst.show_tab("home")
		else:
			Main.inst.toast("That code didn't work. Check it was copied completely."), "primary"))
	v.add_child(UI.btn("Cancel", Main.inst.close_modal, "ghost", 56))
	Main.inst.modal(v)

func _para(b: VBoxContainer, text: String, size := 22, color := UI.TEXT, bold := false) -> void:
	b.add_child(UI.lbl(text, size, color, bold, true))

func _resources(b: VBoxContainer) -> void:
	b.add_child(header("Support & resources", true))
	var c := UI.card(Color("fdeeee"))
	var v := UI.vbox(10)
	_para(v, "If you are in danger or crisis right now", 24, UI.TEXT, true)
	_para(v, "• Call your local emergency number.\n• US: call or text 988 (Suicide & Crisis Lifeline).\n• UK & Ireland: Samaritans, 116 123.\n• Elsewhere: findahelpline.com lists free, confidential helplines by country.", 21)
	c.add_child(v)
	b.add_child(c)
	var c2 := UI.card()
	var v2 := UI.vbox(10)
	_para(v2, "Learning about DID & OSDD", 24, UI.TEXT, true)
	_para(v2, "• ISSTD (International Society for the Study of Trauma and Dissociation), isst-d.org: public information and a therapist directory.\n• Beauty After Bruises, beautyafterbruises.org: a nonprofit supporting survivors with dissociative disorders.\n• Your doctor or a trauma-informed therapist can help with diagnosis and treatment.", 21)
	c2.add_child(v2)
	b.add_child(c2)
	var c3 := UI.card(UI.CARD_SOFT)
	var v3 := UI.vbox(8)
	_para(v3, "A note", 22, UI.TEXT, true)
	_para(v3, "This game is a gentle, fictional take on living as a system. It isn't therapy or a diagnostic tool, and every system is different. Some story events touch on hard topics; content notes appear before them (you can turn them off in Settings). Take breaks whenever you need.", 20, UI.MUTED)
	c3.add_child(v3)
	b.add_child(c3)

func _about(b: VBoxContainer) -> void:
	b.add_child(header("About", true))
	var c := UI.card()
	var v := UI.vbox(12)
	_para(v, "Many Hands", 30, UI.TEXT, true)
	_para(v, "A cozy team-building game about a plural system (DID/OSDD) getting through daily life together.", 22)
	_para(v, "How to play", 24, UI.TEXT, true)
	_para(v, "• Tasks: pick a chore from today's board, choose up to 4 alters and who fronts. The fronter's skills matter most. Tasks run in real time; come back to collect.\n• Story: multi-step events where you choose an approach and a fronter at each step. Clearing a chapter unlocks new kinds of tasks.\n• Discover: spend sparks to meet new alters. Meeting someone again raises their stars.\n• Grow: alters level up from tasks, bond with teammates, and can hold 2 comfort items.\n• Headspace: rest, hold system meetings, and decorate the room for passive bonuses.\n• Watch your spoons (energy) and stress. Self-care tasks help!", 20)
	_para(v, "No ads, no real-money purchases, no account needed. All data stays on your device.", 20, UI.MUTED)
	c.add_child(v)
	b.add_child(c)

func _credits(b: VBoxContainer) -> void:
	b.add_child(header("Credits", true))
	_para(b, "Every alter has a different art style, because every alter is their own person. All art is used under licenses that allow free commercial use:", 21, UI.MUTED)
	var seen := {}
	for c in DB.credits_art:
		var key: String = c.style + c.creator
		if seen.has(key):
			continue
		seen[key] = true
		var card := UI.card(UI.CARD, 16)
		var v := UI.vbox(2)
		v.add_child(UI.lbl(c.style, 22, UI.TEXT, true, true))
		v.add_child(UI.lbl("by %s · %s" % [c.creator, c.license], 19, UI.MUTED, false, true))
		if c.source != "":
			v.add_child(UI.lbl(c.source, 17, UI.PRIMARY_DARK, false, true))
		card.add_child(v)
		b.add_child(card)
	_para(b, "Avatars generated with DiceBear (dicebear.com). Full-body art via the react-peeps and react-humaaans packages. Built with Godot Engine (MIT).", 19, UI.MUTED)
