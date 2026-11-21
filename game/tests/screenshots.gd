extends Node
## Renders screenshots of each screen. Run with a display (xvfb):
## godot --path game res://tests/screenshots.tscn -- <outdir>

var out := "user://shots"

func shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)

func _ready() -> void:
	var root := get_tree().root
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	var G = get_node("/root/Game")
	G.disable_save = true
	G.rng.seed = 7
	G.new_game()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	await get_tree().process_frame
	await shot("00_intro")
	main.current_screen._next()
	await shot("01_intro2")
	main.current_screen._next()
	await shot("02_intro3")
	main.current_screen._finish()
	await shot("03_home")
	# a decent roster
	G.state.sparks = 5000
	G.pull(10)
	G.pull(10)
	G.state.coins = 3000
	G.give_item("headphones")
	G.equip("sam", 0, "headphones")
	main.show_tab("team")
	await shot("04_team")
	main.push("alter", {"id": "sam"})
	await shot("05_alter")
	main.current_screen.scroll.scroll_vertical = 900
	await shot("05a_alter_scrolled")
	main.push("alter", {"id": "sage"})
	await shot("05b_alter_other")
	main.show_tab("tasks")
	await shot("06_tasks")
	var cid: String = G.state.daily.board[0]
	TeamPicker.open("chore", cid, func(t, f): G.start_chore(cid, t, f))
	await shot("07_picker")
	main.current_screen  # noop
	var tp = main.modal_layer.get_child(0)
	main.close_all_modals()
	G.start_chore(cid, ["sam", "pip"], "sam")
	G.start_chore(G.state.daily.board[1], ["rook"], "rook")
	main.show_tab("tasks")
	await shot("08_tasks_running")
	G.time_offset += 3600 * 3
	G.tick()
	main.refresh_screen()
	await shot("08b_tasks_ready")
	var res = G.collect_chore(G.state.active[0])
	main.current_screen.show_result(res)
	await shot("09_result")
	main.close_all_modals()
	main.show_tab("story")
	await shot("10_story")
	var free := []
	for a in G.state.roster:
		if not G.busy(a) and free.size() < 4:
			free.append(a)
	print(G.start_event("ev_morning", free))
	main.open_full("event")
	await shot("11_event_intro")
	main.current_screen.phase = "choose"
	main.current_screen.redraw()
	await shot("12_event_choose")
	main.current_screen._attempt(0)
	await shot("13_event_result")
	main.show_tab("discover")
	await shot("14_discover")
	main.current_screen._pull(1)
	for i in 30:
		await get_tree().process_frame
	await shot("15_pull1")
	main.close_all_modals()
	main.current_screen._pull(10)
	for i in 60:
		await get_tree().process_frame
	await shot("16_pull10")
	main.close_all_modals()
	G.buy_decor("sofa")
	G.buy_decor("plants")
	G.buy_decor("cat")
	G.place_decor("0,0", "sofa")
	G.place_decor("3,2", "plants")
	G.place_decor("4,0", "cat")
	main.show_tab("headspace")
	for i in 40:
		await get_tree().process_frame
	await shot("17_headspace")
	main.current_screen._shop()
	await shot("18_shop")
	main.close_all_modals()
	main.push("settings")
	await shot("19_settings")
	main.push("settings", {"page": "resources"})
	await shot("20_resources")
	main.show_tab("home")
	await shot("21_home_later")
	get_tree().quit()
