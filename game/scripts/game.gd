extends Node
## Player state, rules and persistence. All gameplay math lives here so it can be unit tested.

signal changed                       # any state change (UI refresh)
signal toast(text: String)           # short message for the player

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

# ---- tuning ----
const SPOONS_MAX := 12
const SPOON_REGEN_SEC := 20 * 60
const STRESS_DECAY_SEC := 30 * 60
const REST_COOLDOWN_SEC := 60 * 60
const REST_AMOUNT := 15
const MAX_LEVEL := 50
const PRIMARY_BASE := [0, 30, 45, 65, 90, 120]
const SKILL_FACTORS := [1.0, 0.7, 0.45]
const CHORE_DIFFICULTY := [0, 25, 48, 110, 220, 380]
const EVENT_DIFFICULTY := [0, 30, 60, 125, 230, 400]
const SUPPORT_WEIGHT := 0.35
const EVENT_SUPPORT_WEIGHT := 0.25
const PULL_COST := 100
const PULL10_COST := 900
const GACHA_RATES := [0, 40.0, 30.0, 20.0, 8.0, 2.0]   # percent by rarity
const PITY_5 := 60
const PITY_4 := 10
const DUPE_SHARDS := [0, 5, 10, 20, 40, 80]
const SHARD_PRICE := [0, 30, 60, 120, 250, 500]
const START_SPARKS := 1000
const DAILY_SPARKS := 100
const DAILY_COINS := 100
const BOARD_SIZE := 7
const BOARD_REFRESH_COST := 50

var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var time_offset := 0.0               # debug/testing: shift "now"
var _dirty := false
var _autosave_timer := 0.0
var _tick_timer := 0.0
var disable_save := false            # tests

func _ready() -> void:
	DB.load_all()
	rng.randomize()
	if not load_game():
		new_game()
	process_offline()

func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer = 0.0
		tick()
	_autosave_timer += delta
	if _dirty and _autosave_timer > 5.0:
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not state.is_empty():
			save_game()

func now() -> float:
	return Time.get_unix_time_from_system() + time_offset

func today() -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(now() + _tz_bias()))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func mark() -> void:
	_dirty = true
	changed.emit()

# ======================================================================
# New game / persistence
# ======================================================================
func new_game(system_name := "The Crew") -> void:
	state = {
		"version": SAVE_VERSION,
		"system_name": system_name,
		"created": now(),
		"sparks": START_SPARKS, "coins": 200, "shards": 0,
		"spoons": float(SPOONS_MAX), "spoon_tick": now(),
		"stress": 20.0, "stress_tick": now(),
		"comm": 10.0,
		"roster": {},
		"inventory": {},
		"decor_owned": [],
		"layout": {},          # "x,y" -> decor id
		"headspace_residents": [],
		"bonds": {},
		"pity5": 0, "pity4": 0,
		"active": [],          # running chores
		"next_uid": 1,
		"daily": {"date": "", "board": [], "done": [], "login": false, "meeting": false},
		"rest_at": 0.0,
		"story": {"chapter": 1, "done": {}},
		"event_run": {},
		"settings": {"cw": true, "reduce_motion": false},
		"stats": {"pulls": 0, "chores": 0, "events": 0},
		"intro_seen": false,
		"log": [],
	}
	for id in DB.alter_order:
		if DB.alters[id].get("starter", false):
			_add_alter(id)
	state.headspace_residents = state.roster.keys()
	check_daily()
	mark()

func save_game() -> void:
	_dirty = false
	_autosave_timer = 0.0
	if disable_save:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("roster"):
		return false
	state = _migrate(data)
	return true

func _migrate(data: Dictionary) -> Dictionary:
	# Fill any keys added in later versions with defaults.
	var tmp_state := state
	new_game()
	var defaults := state
	state = tmp_state
	for k in defaults:
		if not data.has(k):
			data[k] = defaults[k]
	for k in defaults.settings:
		if not data.settings.has(k):
			data.settings[k] = defaults.settings[k]
	# JSON numbers come back as floats; normalise roster ints
	for id in data.roster:
		var r: Dictionary = data.roster[id]
		r.level = int(r.level); r.stars = int(r.stars); r.xp = int(r.xp)
		if str(r.get("portrait", "")).begins_with("alt_"):
			r.portrait = ""   # old headshot-only looks were removed
	return data

func export_code() -> String:
	var raw := JSON.stringify(state).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return "MH1:" + str(raw.size()) + ":" + Marshalls.raw_to_base64(packed)

func import_code(code: String) -> bool:
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	var parts := code.split(":")
	if parts.size() != 3 or parts[0] != "MH1":
		return false
	var packed := Marshalls.base64_to_raw(parts[2])
	var raw := packed.decompress(int(parts[1]), FileAccess.COMPRESSION_GZIP)
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("roster"):
		return false
	state = _migrate(data)
	process_offline()
	save_game()
	changed.emit()
	return true

func reset_game() -> void:
	new_game()
	save_game()

# ======================================================================
# Time-based systems
# ======================================================================
func process_offline() -> void:
	tick()
	check_daily()

func tick() -> void:
	if state.is_empty():
		return
	var t := now()
	var changed_any := false
	# spoons
	var regen := SPOON_REGEN_SEC / (1.0 + decor_effect("spoon_regen") / 100.0)
	if state.spoons >= spoons_max():
		state.spoon_tick = t
	else:
		var n := int((t - state.spoon_tick) / regen)
		if n > 0:
			state.spoons = min(float(spoons_max()), state.spoons + n)
			state.spoon_tick += n * regen
			changed_any = true
	# stress decay
	var decay_sec := STRESS_DECAY_SEC / (1.0 + decor_effect("stress_decay") * 0.5)
	var k := int((t - state.stress_tick) / decay_sec)
	if k > 0:
		state.stress_tick += k * decay_sec
		if state.stress > 0:
			state.stress = max(0.0, state.stress - k)
			changed_any = true
	if today() != state.daily.date:
		check_daily()
		changed_any = true
	if changed_any:
		mark()

func spoons_max() -> int:
	return SPOONS_MAX

func check_daily() -> void:
	var d := today()
	if state.daily.date == d:
		return
	state.daily = {"date": d, "board": [], "done": [], "login": false, "meeting": false}
	state.comm = min(100.0, state.comm + decor_effect("comm_daily"))
	roll_board()

func roll_board() -> void:
	var pool := available_chores()
	pool.shuffle()
	var board := []
	# guarantee one self-care chore
	for id in pool:
		if DB.chores[id].area == "selfcare":
			board.append(id)
			break
	for id in pool:
		if board.size() >= BOARD_SIZE:
			break
		if not id in board:
			board.append(id)
	state.daily.board = board
	state.daily.done = []
	mark()

func refresh_board() -> bool:
	if state.coins < BOARD_REFRESH_COST:
		return false
	state.coins -= BOARD_REFRESH_COST
	roll_board()
	return true

func available_chores() -> Array:
	var out := []
	for id in DB.chore_order:
		if int(DB.chores[id].chapter) <= int(state.story.chapter):
			out.append(id)
	return out

func claim_daily() -> bool:
	if state.daily.login:
		return false
	state.daily.login = true
	state.sparks += DAILY_SPARKS
	state.coins += DAILY_COINS
	mark()
	return true

# ======================================================================
# Alters & stats
# ======================================================================
func owns(aid: String) -> bool:
	return state.roster.has(aid)

func _add_alter(aid: String) -> void:
	state.roster[aid] = {"level": 1, "xp": 0, "stars": 1, "equip": ["", ""], "nick": "", "pronouns": "", "portrait": ""}

func alter_name(aid: String) -> String:
	var r = state.roster.get(aid)
	if r and r.nick != "":
		return r.nick
	return DB.alters[aid].name

func alter_pronouns(aid: String) -> String:
	var r = state.roster.get(aid)
	if r and r.pronouns != "":
		return r.pronouns
	return DB.alters[aid].pronouns

## The look (full body + matching headshot) shown for an alter: its own art or a chosen look id.
func alter_portrait(aid: String) -> String:
	var r = state.roster.get(aid)
	if r and r.portrait != "":
		return r.portrait
	return aid

func xp_to_next(level: int) -> int:
	return 40 + level * 20

func stat_mult(aid: String) -> float:
	var r: Dictionary = state.roster.get(aid, {"level": 1, "stars": 1})
	return (1.0 + (r.level - 1) * 0.05) * (1.0 + (r.stars - 1) * 0.2)

## Returns {"base": float, "lo": float, "hi": float} for an alter's skill (0s if untrained).
func skill(aid: String, s: String) -> Dictionary:
	var def: Dictionary = DB.alters[aid]
	var idx: int = def.skills.find(s)
	var eq := equip_bonus(aid, s)
	if idx < 0:
		return {"base": eq, "lo": 0.0, "hi": 0.0}
	var b: float = PRIMARY_BASE[int(def.rarity)] * SKILL_FACTORS[idx] * stat_mult(aid)
	return {"base": b + eq, "lo": b * 0.1, "hi": b * 0.5}

func skill_avg(aid: String, s: String) -> float:
	var sk := skill(aid, s)
	return sk.base + (sk.lo + sk.hi) * 0.5

func skill_roll(aid: String, s: String) -> float:
	var sk := skill(aid, s)
	return sk.base + rng.randf_range(sk.lo, sk.hi)

func equip_bonus(aid: String, s: String) -> float:
	var r = state.roster.get(aid)
	if r == null:
		return 0.0
	var total := 0.0
	for iid in r.equip:
		if iid != "" and DB.comfort.has(iid):
			total += float(DB.comfort[iid].bonus.get(s, 0))
	return total

func power_rating(aid: String) -> int:
	var t := 0.0
	for s in DB.SKILLS:
		t += skill_avg(aid, s)
	return int(t)

func add_xp(aid: String, amount: int) -> bool:
	var r: Dictionary = state.roster[aid]
	if r.level >= MAX_LEVEL:
		return false
	r.xp += amount
	var leveled := false
	while r.level < MAX_LEVEL and r.xp >= xp_to_next(r.level):
		r.xp -= xp_to_next(r.level)
		r.level += 1
		leveled = true
	if r.level >= MAX_LEVEL:
		r.xp = 0
	return leveled

## Spend coins to train an alter one level ("practice").
func train_cost(aid: String) -> int:
	var r: Dictionary = state.roster[aid]
	return 20 + r.level * 12

func train(aid: String) -> bool:
	var r: Dictionary = state.roster[aid]
	if r.level >= MAX_LEVEL or state.coins < train_cost(aid):
		return false
	state.coins -= train_cost(aid)
	r.level += 1
	r.xp = 0
	mark()
	return true

func max_stars(aid: String) -> int:
	return int(DB.alters[aid].rarity)

func busy(aid: String) -> bool:
	for a in state.active:
		if aid in a.team:
			return true
	return false

func set_cosmetic(aid: String, nick: String, pronouns: String, portrait: String) -> void:
	var r: Dictionary = state.roster[aid]
	r.nick = nick.strip_edges().left(20)
	r.pronouns = pronouns.strip_edges().left(20)
	r.portrait = portrait
	mark()

# ---- equipment ----
func give_item(iid: String, n := 1) -> void:
	state.inventory[iid] = int(state.inventory.get(iid, 0)) + n
	mark()

func item_free(iid: String) -> int:
	var used := 0
	for aid in state.roster:
		used += state.roster[aid].equip.count(iid)
	return int(state.inventory.get(iid, 0)) - used

func equip(aid: String, slot: int, iid: String) -> bool:
	var r: Dictionary = state.roster[aid]
	if iid != "" and item_free(iid) <= 0:
		return false
	r.equip[slot] = iid
	mark()
	return true

func buy_item(iid: String) -> bool:
	var price := int(DB.comfort[iid].price)
	if state.coins < price:
		return false
	state.coins -= price
	give_item(iid)
	return true

# ---- bonds ----
func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func bond_count(a: String, b: String) -> int:
	return int(state.bonds.get(_pair_key(a, b), 0))

func bond_level(a: String, b: String) -> int:
	var c := bond_count(a, b)
	return min(5, int(floor(sqrt(c / 2.0))))

func add_bonds(team: Array) -> void:
	for i in team.size():
		for j in range(i + 1, team.size()):
			var k := _pair_key(team[i], team[j])
			state.bonds[k] = int(state.bonds.get(k, 0)) + 1

func top_bonds(aid: String, n := 3) -> Array:
	var out := []
	for other in state.roster:
		if other != aid and bond_count(aid, other) > 0:
			out.append({"id": other, "count": bond_count(aid, other), "level": bond_level(aid, other)})
	out.sort_custom(func(x, y): return x.count > y.count)
	return out.slice(0, n)

# ======================================================================
# Team evaluation (shared by chores and events)
# ======================================================================
func decor_effect(effect: String) -> float:
	var total := 0.0
	for key in state.get("layout", {}):
		var did: String = state.layout[key]
		if DB.decor.has(did) and DB.decor[did].effect == effect:
			total += float(DB.decor[did].value)
	return total

## Percent modifier and a breakdown list for a team on a given set of tags/traits.
func team_bonus(team: Array, fronter: String, tags: Array, traits: Array) -> Dictionary:
	var pct := 0.0
	var notes := []
	# traits
	for aid in team:
		var w := 12.0 if aid == fronter else 6.0
		for t in DB.alters[aid].traits:
			if t in traits:
				pct += w
				notes.append("%s: %s +%d%%" % [alter_name(aid), t, w])
	# roles
	for aid in team:
		var role: String = DB.alters[aid].role
		var scale := 1.0 if aid == fronter else 0.5
		var rdef: Dictionary = DB.roles[role]
		for tag in tags:
			if rdef.tags.has(tag):
				var v: float = float(rdef.tags[tag]) * scale
				pct += v
				notes.append("%s (%s) +%d%%" % [alter_name(aid), rdef.name, v])
		if role == "fictive":
			pct += 6.0 * scale
			notes.append("%s (Fictive) +%d%%" % [alter_name(aid), 6 * scale])
		if role == "protector" and state.stress >= 10:
			var pv: float = min(25.0, floor(state.stress / 10.0) * 3.0) * scale
			pct += pv
			notes.append("%s (Protector, stress) +%d%%" % [alter_name(aid), pv])
	# bonds
	for i in team.size():
		for j in range(i + 1, team.size()):
			var bl := bond_level(team[i], team[j])
			if bl > 0:
				pct += bl * 2
				notes.append("Bond %s & %s +%d%%" % [alter_name(team[i]), alter_name(team[j]), bl * 2])
	# communication
	var cb: float = state.comm * 0.2
	if cb >= 1:
		pct += cb
		notes.append("System communication +%d%%" % cb)
	# stress
	if state.stress > 50:
		var sp: float = min(25.0, (state.stress - 50) * 0.5)
		pct -= sp
		notes.append("High stress -%d%%" % sp)
	return {"pct": pct, "notes": notes}

func team_skill_mult(team: Array, s: String) -> float:
	var m := 1.0 + decor_effect("skill_" + s) / 100.0
	for aid in team:
		var role: String = DB.alters[aid].role
		if role == "manager" and s == "ORG":
			m += 0.05
		if role == "creative" and s == "CRE":
			m += 0.05
	return m

func chance_from_ratio(ratio: float, cap := 0.99) -> float:
	return clamp(0.5 + 0.6 * (ratio - 1.0), 0.05, cap)

# ======================================================================
# Chores (timed, shuttle-style)
# ======================================================================
func chore_difficulty(cid: String) -> float:
	return CHORE_DIFFICULTY[int(DB.chores[cid].tier)]

func chore_power(cid: String, team: Array, fronter: String) -> float:
	var c: Dictionary = DB.chores[cid]
	var total := 0.0
	var wsum := 0.0
	for s in c.skills:
		var w: float = float(c.skills[s])
		var v := 0.0
		for aid in team:
			v += skill_avg(aid, s) * (1.0 if aid == fronter else SUPPORT_WEIGHT)
		v *= team_skill_mult(team, s)
		total += v * w
		wsum += w
	var base: float = total / max(wsum, 0.001)
	var b := team_bonus(team, fronter, c.tags, c.traits)
	return base * (1.0 + b.pct / 100.0)

func chore_chance(cid: String, team: Array, fronter: String) -> float:
	if team.is_empty() or fronter == "":
		return 0.0
	return chance_from_ratio(chore_power(cid, team, fronter) / chore_difficulty(cid))

## Best fronter for a chore among a team = highest weighted solo contribution.
func best_fronter(cid: String, team: Array) -> String:
	var best := ""
	var bv := -1.0
	for aid in team:
		var v := chore_power(cid, team, aid)
		if v > bv:
			bv = v
			best = aid
	return best

func max_active() -> int:
	return 3 if int(state.story.chapter) < 3 else 4

func chore_rewards(cid: String) -> Dictionary:
	var c: Dictionary = DB.chores[cid]
	var tier := int(c.tier)
	var coins := int((15 * tier + float(c.minutes) * 0.8) * (1.0 + decor_effect("coin_bonus") / 100.0))
	var xp := int((10 * tier + float(c.minutes) * 0.5) * (1.0 + decor_effect("xp_bonus") / 100.0))
	return {"coins": coins, "sparks": 5 * tier, "xp": xp}

func can_start_chore(cid: String, team: Array, fronter: String) -> String:
	var c: Dictionary = DB.chores[cid]
	if team.is_empty():
		return "Pick at least one alter."
	if team.size() > 4:
		return "Teams are 4 alters max."
	if not fronter in team:
		return "Choose who fronts."
	if state.active.size() >= max_active():
		return "All task slots are busy."
	if cid in state.daily.done or not cid in state.daily.board:
		return "That task isn't on today's board."
	for a in state.active:
		if a.chore == cid:
			return "Already in progress."
	for aid in team:
		if busy(aid):
			return "%s is busy." % alter_name(aid)
	if state.spoons < float(c.spoons):
		return "Not enough spoons. Rest a bit first."
	return ""

func start_chore(cid: String, team: Array, fronter: String) -> String:
	var err := can_start_chore(cid, team, fronter)
	if err != "":
		return err
	var c: Dictionary = DB.chores[cid]
	state.spoons -= float(c.spoons)
	var t := now()
	state.active.append({
		"uid": state.next_uid, "chore": cid, "team": team.duplicate(), "fronter": fronter,
		"start": t, "end": t + float(c.minutes) * 60.0,
		"chance": chore_chance(cid, team, fronter),
	})
	state.next_uid += 1
	mark()
	return ""

func chore_remaining(run: Dictionary) -> float:
	return max(0.0, run.end - now())

## Finish early using sparks (cost scales with remaining minutes).
func rush_cost(run: Dictionary) -> int:
	return int(ceil(chore_remaining(run) / 60.0 / 3.0)) * 2

func rush(run: Dictionary) -> bool:
	var cost := rush_cost(run)
	if state.sparks < cost:
		return false
	state.sparks -= cost
	run.end = now()
	mark()
	return true

func cancel_chore(run: Dictionary) -> void:
	state.spoons = min(float(spoons_max()), state.spoons + float(DB.chores[run.chore].spoons) * 0.5)
	state.active.erase(run)
	mark()

## Resolve a finished chore. Returns a result dictionary for the UI.
func collect_chore(run: Dictionary) -> Dictionary:
	if chore_remaining(run) > 0:
		return {}
	var cid: String = run.chore
	var c: Dictionary = DB.chores[cid]
	var success := rng.randf() < float(run.chance)
	var rw := chore_rewards(cid)
	var res := {"chore": cid, "success": success, "team": run.team, "levels": [], "item": "", "coins": 0, "sparks": 0, "xp": 0, "stress": 0.0, "comm": 0.0}
	var stress_before: float = state.stress
	var comm_before: float = state.comm
	var team_roles := []
	for aid in run.team:
		team_roles.append(DB.alters[aid].role)
	if success:
		res.coins = rw.coins
		res.sparks = rw.sparks
		res.xp = rw.xp
		state.coins += rw.coins
		state.sparks += rw.sparks
		var ds: float = float(c.get("stress", 0))
		if ds == 0 and c.area != "selfcare":
			ds = int(c.tier) * 1.5
		state.stress += ds
		if "little" in team_roles:
			state.stress -= 3
		state.comm += float(c.get("comm", 0)) + 0.5
		# item drop
		if rng.randf() < 0.08 + 0.04 * int(c.tier):
			var pool := []
			for iid in DB.comfort_order:
				if int(DB.comfort[iid].rarity) <= int(c.tier) + 1:
					pool.append(iid)
			var iid: String = pool[rng.randi() % pool.size()]
			give_item(iid)
			res.item = iid
	else:
		res.xp = int(rw.xp / 2)
		var gain := 8.0
		if "caretaker" in team_roles:
			gain *= 0.5
		state.stress += gain
	if "soother" in team_roles:
		state.stress -= 4
	state.stress = clamp(state.stress, 0.0, 100.0)
	state.comm = clamp(state.comm, 0.0, 100.0)
	for aid in run.team:
		var amt: int = int(res.xp * (1.5 if aid == run.fronter else 1.0))
		if add_xp(aid, amt):
			res.levels.append(aid)
	add_bonds(run.team)
	res.stress = state.stress - stress_before
	res.comm = state.comm - comm_before
	state.active.erase(run)
	if not cid in state.daily.done:
		state.daily.done.append(cid)
	state.stats.chores += 1
	log_line(("✓ " if success else "✗ ") + c.name)
	mark()
	return res

# ======================================================================
# Self-care actions (headspace)
# ======================================================================
func rest_ready_in() -> float:
	return max(0.0, state.rest_at + REST_COOLDOWN_SEC - now())

func rest() -> bool:
	if rest_ready_in() > 0:
		return false
	state.rest_at = now()
	var amt := REST_AMOUNT + decor_effect("rest_bonus")
	state.stress = max(0.0, state.stress - amt)
	state.spoons = min(float(spoons_max()), state.spoons + 1)
	mark()
	return true

func system_meeting() -> bool:
	if state.daily.meeting:
		return false
	state.daily.meeting = true
	state.comm = min(100.0, state.comm + 3)
	state.stress = max(0.0, state.stress - 5)
	mark()
	return true

# ======================================================================
# Gacha ("Discovery")
# ======================================================================
func featured() -> Dictionary:
	# rotates weekly
	var week := int(now() / (7 * 86400))
	var r5 := DB.alters_by_rarity(5)
	var r4 := DB.alters_by_rarity(4)
	return {"r5": r5[week % r5.size()], "r4": r4[week % r4.size()]}

func roll_rarity() -> int:
	state.pity5 += 1
	state.pity4 += 1
	if state.pity5 >= PITY_5:
		return 5
	var x := rng.randf() * 100.0
	var acc := 0.0
	var r := 1
	for i in range(5, 0, -1):
		acc += GACHA_RATES[i]
		if x < acc:
			r = i
			break
	if r < 4 and state.pity4 >= PITY_4:
		r = 4
	return r

func _pick_alter(rarity: int) -> String:
	var pool := DB.alters_by_rarity(rarity)
	var f := featured()
	if rarity == 5 and rng.randf() < 0.5:
		return f.r5
	if rarity == 4 and rng.randf() < 0.5:
		return f.r4
	return pool[rng.randi() % pool.size()]

func _grant_alter(aid: String) -> Dictionary:
	var r := int(DB.alters[aid].rarity)
	if r >= 5:
		state.pity5 = 0
	if r >= 4:
		state.pity4 = 0
	if not owns(aid):
		_add_alter(aid)
		if state.headspace_residents.size() < 8:
			state.headspace_residents.append(aid)
		return {"id": aid, "new": true, "star_up": false, "shards": 0}
	var ros: Dictionary = state.roster[aid]
	if ros.stars < max_stars(aid):
		ros.stars += 1
		return {"id": aid, "new": false, "star_up": true, "shards": 0}
	state.shards += DUPE_SHARDS[r]
	return {"id": aid, "new": false, "star_up": false, "shards": DUPE_SHARDS[r]}

func pull(n: int) -> Array:
	var cost := PULL10_COST if n == 10 else PULL_COST * n
	if state.sparks < cost:
		return []
	state.sparks -= cost
	var out := []
	for i in n:
		out.append(_grant_alter(_pick_alter(roll_rarity())))
	state.stats.pulls += n
	mark()
	return out

func shard_buy(aid: String) -> bool:
	var price: int = SHARD_PRICE[int(DB.alters[aid].rarity)]
	if state.shards < price or int(DB.alters[aid].rarity) >= 5:
		return false
	state.shards -= price
	_grant_alter(aid)
	mark()
	return true

# ======================================================================
# Story events (away-mission style)
# ======================================================================
func event_unlocked(ev_id: String) -> bool:
	var ch := DB.chapter_of_event(ev_id)
	if ch > int(state.story.chapter):
		return false
	var evs: Array = DB.chapters[ch - 1].events
	var idx := evs.find(ev_id)
	return idx == 0 or state.story.done.has(evs[idx - 1])

func event_stars(ev_id: String) -> int:
	return int(state.story.done.get(ev_id, 0))

func event_node_difficulty(ev_id: String, node_idx: int) -> float:
	var ev: Dictionary = DB.events[ev_id]
	return EVENT_DIFFICULTY[int(ev.tier)] * (0.9 + 0.06 * node_idx)

func event_check_value(team: Array, fronter: String, s: String, roll := false) -> float:
	var v := skill_roll(fronter, s) if roll else skill_avg(fronter, s)
	for aid in team:
		if aid != fronter:
			v += skill_avg(aid, s) * EVENT_SUPPORT_WEIGHT
	v *= team_skill_mult(team, s)
	var tags := []
	if DB.alters[fronter].role == "memory" and _event_is_memory():
		tags.append("memory")
	var b := team_bonus(team, fronter, tags, [])
	return v * (1.0 + b.pct / 100.0)

func _event_is_memory() -> bool:
	return state.event_run.get("id", "") in ["ev_lost_time", "ev_doctor", "ev_therapy", "ev_bank_call"]

func event_choice_chance(team: Array, fronter: String, s: String) -> float:
	var run: Dictionary = state.event_run
	var d := event_node_difficulty(run.id, run.node)
	return chance_from_ratio(event_check_value(team, fronter, s) / d, 0.97)

func switch_cost(team: Array, from: String, to: String) -> float:
	if from == "" or from == to:
		return 0.0
	for aid in team:
		if DB.alters[aid].role == "gatekeeper":
			return 0.0
	if DB.alters[to].role == "host":
		return 0.0
	return 3.0

func start_event(ev_id: String, team: Array) -> String:
	var ev: Dictionary = DB.events[ev_id]
	if not event_unlocked(ev_id):
		return "Locked."
	if team.is_empty() or team.size() > 4:
		return "Pick 1–4 alters."
	for aid in team:
		if busy(aid):
			return "%s is busy with a task." % alter_name(aid)
	if state.spoons < float(ev.spoons):
		return "Not enough spoons."
	state.spoons -= float(ev.spoons)
	state.event_run = {"id": ev_id, "team": team.duplicate(), "node": 0, "fronter": "", "fails": 0, "log": []}
	mark()
	return ""

## Attempt the current node's choice with the given fronter. Returns {"ok", "text", "stress"}.
func event_attempt(choice_idx: int, fronter: String) -> Dictionary:
	var run: Dictionary = state.event_run
	var ev: Dictionary = DB.events[run.id]
	var node: Dictionary = ev.nodes[run.node]
	var ch: Dictionary = node.choices[choice_idx]
	var stress_gain := switch_cost(run.team, run.fronter, fronter)
	run.fronter = fronter
	var chance := event_choice_chance(run.team, fronter, ch.skill)
	var ok := rng.randf() < chance
	if not ok:
		var g := 6.0
		for aid in run.team:
			if DB.alters[aid].role == "caretaker":
				g = 3.0
				break
		stress_gain += g
		run.fails += 1
	state.stress = clamp(state.stress + stress_gain, 0.0, 100.0)
	add_xp(fronter, 10 + 5 * int(ev.tier))
	var text: String = ch.ok if ok else ch.fail
	run.log.append({"node": run.node, "ok": ok, "fronter": fronter, "text": text})
	if ok:
		run.node += 1
	mark()
	return {"ok": ok, "text": text, "stress": stress_gain, "chance": chance}

## After a fail: push through (advance, costs nothing extra) or retry (1 spoon).
func event_push_through() -> void:
	state.event_run.node += 1
	mark()

func event_retry_cost() -> int:
	return 1

func event_can_retry() -> bool:
	return state.spoons >= event_retry_cost()

func event_retry() -> bool:
	if not event_can_retry():
		return false
	state.spoons -= event_retry_cost()
	mark()
	return true

func event_finished() -> bool:
	var run: Dictionary = state.event_run
	return not run.is_empty() and run.node >= DB.events[run.id].nodes.size()

func event_abandon() -> void:
	state.event_run = {}
	mark()

func complete_event() -> Dictionary:
	var run: Dictionary = state.event_run
	var ev_id: String = run.id
	var ev: Dictionary = DB.events[ev_id]
	var tier := int(ev.tier)
	var stars: int = max(1, 3 - int(run.fails))
	var first: bool = not state.story.done.has(ev_id)
	var mult := 1.0 if first else 0.3
	var res := {"id": ev_id, "stars": stars, "first": first,
		"sparks": int(100 * tier * mult), "coins": int(80 * tier * mult), "xp": int(40 * tier * mult),
		"levels": [], "chapter_unlocked": 0, "item": ""}
	state.sparks += res.sparks
	state.coins += res.coins
	for aid in run.team:
		if add_xp(aid, res.xp):
			res.levels.append(aid)
	add_bonds(run.team)
	state.comm = min(100.0, state.comm + 2)
	state.story.done[ev_id] = max(event_stars(ev_id), stars)
	if first and stars == 3:
		var pool := []
		for iid in DB.comfort_order:
			if int(DB.comfort[iid].rarity) == clampi(tier, 2, 4):
				pool.append(iid)
		if not pool.is_empty():
			res.item = pool[rng.randi() % pool.size()]
			give_item(res.item)
	# chapter progression
	var ch := DB.chapter_of_event(ev_id)
	if ch == int(state.story.chapter) and ch < DB.chapters.size():
		var all_done := true
		for e in DB.chapters[ch - 1].events:
			if not state.story.done.has(e):
				all_done = false
		if all_done:
			state.story.chapter = ch + 1
			res.chapter_unlocked = ch + 1
			state.sparks += 300
	state.stats.events += 1
	state.event_run = {}
	log_line("★ " + ev.name)
	mark()
	return res

# ======================================================================
# Headspace decor
# ======================================================================
func buy_decor(did: String) -> bool:
	var price := int(DB.decor[did].price)
	if state.coins < price or did in state.decor_owned:
		return false
	state.coins -= price
	state.decor_owned.append(did)
	mark()
	return true

func place_decor(cell: String, did: String) -> void:
	# a decor piece can only be placed once
	for k in state.layout.keys():
		if state.layout[k] == did:
			state.layout.erase(k)
	if did == "":
		state.layout.erase(cell)
	else:
		state.layout[cell] = did
	mark()

func decor_placed(did: String) -> bool:
	return did in state.layout.values()

# ======================================================================
func log_line(s: String) -> void:
	state.log.push_front(s)
	if state.log.size() > 30:
		state.log.resize(30)
