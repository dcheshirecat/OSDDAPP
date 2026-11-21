extends Node
## Static game data (loaded once from res://data/*.json) and texture caches.

const SKILLS := ["SOC", "ORG", "PHY", "REG", "FOC", "CRE"]
const SKILL_NAMES := {"SOC": "Social", "ORG": "Organization", "PHY": "Physical", "REG": "Regulation", "FOC": "Focus", "CRE": "Creativity"}
const SKILL_ICONS := {"SOC": "conversation", "ORG": "notebook", "PHY": "muscle-up", "REG": "meditation", "FOC": "magnifying-glass", "CRE": "palette"}
const SKILL_COLORS := {"SOC": Color("e07a9a"), "ORG": Color("6d9bc3"), "PHY": Color("e0875a"), "REG": Color("5fae9c"), "FOC": Color("8b7cc8"), "CRE": Color("e6b54a")}
const RARITY_NAMES := ["", "Common", "Uncommon", "Rare", "Super Rare", "Legendary"]
const RARITY_COLORS := [Color.WHITE, Color("9aa3ad"), Color("5fb36b"), Color("4f8fd6"), Color("a66bd6"), Color("e8b13a")]
const AREA_NAMES := {"home": "Home", "selfcare": "Self-care", "work": "Work & School", "errands": "Errands", "social": "Social"}
const AREA_ICONS := {"home": "vacuum-cleaner", "selfcare": "heart-plus", "work": "briefcase", "errands": "shopping-cart", "social": "party-popper"}

var alters: Dictionary = {}      # id -> def
var alter_order: Array = []      # ids in file order
var chores: Dictionary = {}
var chore_order: Array = []
var chapters: Array = []
var events: Dictionary = {}
var comfort: Dictionary = {}
var comfort_order: Array = []
var decor: Dictionary = {}
var decor_order: Array = []
var roles: Dictionary = {}
var looks: Array = []            # alternate full-body looks for customization
var credits_art: Array = []

var _tex_cache: Dictionary = {}

func _ready() -> void:
	load_all()

func _json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file " + path)
		return null
	return JSON.parse_string(f.get_as_text())

func load_all() -> void:
	if not alters.is_empty():
		return
	for a in _json("res://data/alters.json"):
		alters[a.id] = a
		alter_order.append(a.id)
	for c in _json("res://data/chores.json"):
		chores[c.id] = c
		chore_order.append(c.id)
	var story = _json("res://data/story.json")
	chapters = story.chapters
	events = story.events
	var items = _json("res://data/items.json")
	for i in items.comfort:
		comfort[i.id] = i
		comfort_order.append(i.id)
	for d in items.decor:
		decor[d.id] = d
		decor_order.append(d.id)
	roles = _json("res://data/roles.json")
	looks = _json("res://data/looks.json")
	credits_art = _json("res://data/credits_art.json")

func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

func icon(name: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % name)

func portrait_tex(portrait_id: String) -> Texture2D:
	return tex("res://assets/portraits/%s.png" % portrait_id)

## Full-body art (400x600, transparent, feet at bottom edge). Accepts an alter id or a look id.
## Headshots (portrait_tex) are cropped from these same bodies, so they always match.
func body_tex(aid: String) -> Texture2D:
	return tex("res://assets/bodies/%s.png" % aid)

func chapter_of_event(ev_id: String) -> int:
	for ch in chapters:
		if ev_id in ch.events:
			return int(ch.id)
	return 0

func alters_by_rarity(r: int) -> Array:
	var out := []
	for id in alter_order:
		if int(alters[id].rarity) == r:
			out.append(id)
	return out
