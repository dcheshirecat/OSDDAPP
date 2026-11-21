extends Screen
## First-launch welcome: what the game is, a content note, and naming the system.

var page := 0
var name_edit: LineEdit

func build() -> void:
	auto_refresh = false
	Main.inst.top_bar.visible = false
	super.build()

func redraw() -> void:
	UI.clear(body)
	fill(body)

func fill(b: VBoxContainer) -> void:
	b.add_child(UI.gap(30))
	match page:
		0:
			var row := UI.hbox(-40)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			for aid in ["pip", "sam", "rook"]:
				row.add_child(UI.body(aid, 320))
			b.add_child(row)
			var t := UI.title("Many Hands", 52)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_child(t)
			_p(b, "You are a system: many people sharing one life. Groceries, emails, phone calls, hard days. None of it has to be done alone.")
			_p(b, "Build a team from the alters in your system, match the right skills to each task, and help everyone grow, together.", UI.MUTED)
			b.add_child(UI.btn("Next", _next))
		1:
			b.add_child(UI.title("Before we start", 40))
			var c := UI.card(UI.CARD_SOFT)
			var v := UI.vbox(12)
			_p(v, "This game is about Dissociative Identity Disorder (DID) and OSDD. It's meant to be cozy and validating, made with the plural community in mind.")
			_p(v, "Some story events touch on things like panic, dissociation, medical settings or family tension. They're never graphic, and a content note appears before them.", UI.MUTED)
			_p(v, "It's a game, not therapy, and every system is different. If you ever need support, there are resources in Settings.", UI.MUTED)
			c.add_child(v)
			b.add_child(c)
			b.add_child(UI.btn("Support resources", func(): Main.inst.push("settings", {"page": "resources"}), "soft", 64))
			b.add_child(UI.btn("Sounds good", _next))
		2:
			b.add_child(UI.title("What's your system called?", 38))
			_p(b, "Pick a name for your system. You can change it later.", UI.MUTED)
			name_edit = LineEdit.new()
			name_edit.text = Game.state.system_name
			name_edit.max_length = 24
			name_edit.custom_minimum_size.y = 80
			name_edit.add_theme_font_size_override("font_size", 30)
			b.add_child(name_edit)
			var sug := HFlowContainer.new()
			sug.add_theme_constant_override("h_separation", 8)
			sug.add_theme_constant_override("v_separation", 8)
			for n in ["The Crew", "The Collective", "The Household", "The Constellation", "The Garden", "The Flock"]:
				var bt := UI.btn(n, func(): name_edit.text = n, "soft", 56)
				bt.add_theme_font_size_override("font_size", 20)
				sug.add_child(bt)
			b.add_child(sug)
			var c := UI.card()
			var v := UI.vbox(10)
			_p(v, "Sam (host), Pip (little) and Rook (protector) are already here. You also have %d sparks to Discover who else is inside." % int(Game.state.sparks))
			var row2 := UI.hbox(12)
			row2.alignment = BoxContainer.ALIGNMENT_CENTER
			for aid in ["sam", "pip", "rook"]:
				row2.add_child(UI.portrait(aid, 110))
			v.add_child(row2)
			c.add_child(v)
			b.add_child(c)
			b.add_child(UI.btn("Let's begin", _finish, "good"))

func _p(b: Control, text: String, color := UI.TEXT) -> void:
	b.add_child(UI.lbl(text, 25, color, false, true))

func _next() -> void:
	page += 1
	redraw()

func _finish() -> void:
	var n := name_edit.text.strip_edges()
	if n != "":
		Game.state.system_name = n
	Game.state.intro_seen = true
	Game.mark()
	Game.save_game()
	Main.inst.top_bar.visible = true
	Main.inst.show_tab("home")
	Main.inst.toast("Welcome, %s!" % Game.state.system_name)
