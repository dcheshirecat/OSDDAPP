extends SceneTree
## Headless logic tests: godot --headless --path game -s tests/test_logic.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	await process_frame
	var DB = root.get_node("DB")
	var G = root.get_node("Game")
	G.disable_save = true
	G.rng.seed = 12345
	G.new_game()
	print("== data")
	check(DB.alters.size() == 34, "34 alters")
	check(DB.chores.size() >= 35, "chores loaded: %d" % DB.chores.size())
	check(DB.events.size() == 16, "16 events")
	for aid in DB.alter_order:
		check(DB.portrait_tex(aid) != null and DB.body_tex(aid) != null, "art for " + aid) if false else null
		if DB.portrait_tex(aid) == null or DB.body_tex(aid) == null:
			check(false, "missing art for " + aid)
	for ch in DB.chapters:
		for e in ch.events:
			check(DB.events.has(e), "event exists " + e) if not DB.events.has(e) else null
	for cid in DB.chores:
		for s in DB.chores[cid].skills:
			if not s in DB.SKILLS:
				check(false, "bad skill in chore " + cid)
	for eid in DB.events:
		for n in DB.events[eid].nodes:
			for c in n.choices:
				if not c.skill in DB.SKILLS:
					check(false, "bad skill in event " + eid)
	for aid in DB.alters:
		if not DB.roles.has(DB.alters[aid].role):
			check(false, "bad role " + aid)
	for k in DB.roles:
		if DB.icon(DB.roles[k].icon) == null:
			check(false, "role icon " + k)
	for k in DB.comfort:
		if DB.icon(DB.comfort[k].icon) == null:
			check(false, "item icon " + k)
	for k in DB.decor:
		if DB.icon(DB.decor[k].icon) == null:
			check(false, "decor icon " + k)

	print("== new game")
	check(G.state.roster.size() == 3, "3 starters")
	check(G.state.daily.board.size() > 0, "board rolled: %s" % [G.state.daily.board])
	var team: Array = G.state.roster.keys()

	print("== balance (starter team, level 1)")
	for cid in DB.chore_order:
		var c = DB.chores[cid]
		if int(c.chapter) == 1:
			var f = G.best_fronter(cid, team)
			print("    %-22s tier %d  chance %3d%%  front %s" % [cid, c.tier, G.chore_chance(cid, team, f) * 100, f])

	print("== chore flow")
	var cid: String = G.state.daily.board[0]
	var f: String = G.best_fronter(cid, team)
	var sp: float = G.state.spoons
	check(G.start_chore(cid, team, f) == "", "start chore " + cid)
	check(G.state.spoons == sp - float(DB.chores[cid].spoons), "spoons spent")
	check(G.busy(team[0]), "team busy")
	check(G.start_chore(cid, team, f) != "", "can't double start")
	var run = G.state.active[0]
	check(G.collect_chore(run).is_empty(), "can't collect early")
	G.time_offset += float(DB.chores[cid].minutes) * 60 + 1
	var res = G.collect_chore(run)
	check(res.has("success"), "collected: success=%s xp=%d coins=%d" % [res.success, res.xp, res.coins])
	check(not G.busy(team[0]), "team free")
	check(cid in G.state.daily.done, "marked done")

	print("== spoons regen")
	G.state.spoons = 0.0
	G.state.spoon_tick = G.now()
	G.time_offset += 20 * 60 * 3 + 5
	G.tick()
	check(int(G.state.spoons) == 3, "3 spoons after 60 min (%s)" % G.state.spoons)

	print("== gacha")
	G.state.sparks = 100000
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 100:
		for r in G.pull(10):
			counts[int(DB.alters[r.id].rarity)] += 1
	print("    1000 pulls by rarity: ", counts)
	check(counts[5] >= 10, "5★ appear (pity works)")
	check(G.state.roster.size() > 25, "collected many alters: %d" % G.state.roster.size())
	check(G.state.shards > 0, "dupes gave shards")
	var any_star := false
	for aid in G.state.roster:
		if G.state.roster[aid].stars > 1:
			any_star = true
	check(any_star, "dupes raised stars")

	print("== leveling & equipment")
	var a: String = "sam"
	var before = G.skill_avg(a, "FOC")
	G.add_xp(a, 5000)
	check(G.state.roster[a].level > 10, "leveled to %d" % G.state.roster[a].level)
	check(G.skill_avg(a, "FOC") > before, "skill grew")
	G.give_item("headphones")
	check(G.equip(a, 0, "headphones"), "equip")
	check(G.item_free("headphones") == 0, "item in use")
	check(not G.equip("pip", 0, "headphones"), "can't double-equip")
	check(G.equip_bonus(a, "FOC") == 12.0, "equip bonus")

	print("== bonds")
	G.add_bonds(["sam", "pip"])
	G.add_bonds(["sam", "pip"])
	check(G.bond_level("sam", "pip") == 1, "bond level 1 after 2 together")

	print("== event flow")
	G.state.spoons = 12.0
	team = ["sam", "pip", "rook"]
	check(G.start_event("ev_morning", team) == "", "start event")
	var guard := 0
	while not G.event_finished() and guard < 50:
		guard += 1
		var node = DB.events["ev_morning"].nodes[G.state.event_run.node]
		var r = G.event_attempt(0, team[guard % 3])
		if not r.ok:
			G.event_push_through()
	check(G.event_finished(), "event finished")
	var er = G.complete_event()
	check(er.first and er.stars >= 1, "event rewards stars=%d sparks=%d" % [er.stars, er.sparks])
	check(G.event_unlocked("ev_grocery"), "next event unlocked")
	check(not G.event_unlocked("ev_first_day"), "chapter 2 locked")
	G.start_event("ev_grocery", team)
	while not G.event_finished():
		if not G.event_attempt(0, "sam").ok:
			G.event_push_through()
	var er2 = G.complete_event()
	check(er2.chapter_unlocked == 2 and G.state.story.chapter == 2, "chapter 2 unlocked")

	print("== headspace")
	G.state.coins = 5000
	check(G.buy_decor("sofa"), "buy decor")
	G.place_decor("1,1", "sofa")
	check(G.decor_effect("rest_bonus") == 5.0, "decor effect active")
	G.state.stress = 50.0
	check(G.rest(), "rest")
	check(G.state.stress == 30.0, "rest -20 stress (%s)" % G.state.stress)
	check(not G.rest(), "rest cooldown")

	print("== save export/import")
	var code: String = G.export_code()
	var coins = G.state.coins
	G.state.coins = 1
	check(G.import_code(code), "import ok")
	check(G.state.coins == coins, "coins restored")
	check(not G.import_code("garbage"), "reject garbage")

	print("== daily reset")
	var old_board = G.state.daily.board.duplicate()
	G.time_offset += 86400
	G.tick()
	check(G.state.daily.date == G.today() and not G.state.daily.login, "new day")
	check(G.claim_daily() and not G.claim_daily(), "daily claim once")

	print("\n%s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
