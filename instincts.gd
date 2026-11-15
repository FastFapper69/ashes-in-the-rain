## Frank's instincts: the upgrade board. Frank earns experience from how he fights (main.gd _score:
## style points for every man taken down, disarmed or sent off without his hat, plus men let go),
## levels up as it grows, and every level is one point to pin a card with. Three rows: FRANK (how much
## he can take), REVOLVER (his own gun, up to a second one in the other hand) and INSTINCT (tricks).
## A row is pinned left to right. Cards can be taken down and pinned again for free between maps.
extends RefCounted

const MenuScript = preload("res://menu.gd")
const Levels = preload("res://levels.gd")

const BRANCHES := ["frank", "gun", "instinct"]
const BRANCH_NAMES := {"frank": "FRANK", "gun": "GUN", "instinct": "TRICKS"}
const FROM_CHAPTER := [1, 1, 2, 2, 3]   # a tier opens once the story has reached this chapter
# name, text, effect id (main.gd _perk), icon (art/ui/instincts/icon_<icon>.png)
const CARDS := {
	"frank": [
		["TOUGH", "He takes one more hit.", "tough1", "mercy0"],
		["LONG WATCH", "Slowed time lasts a quarter longer.", "longwatch", "time0"],
		["TOUGHER", "He takes one more hit.", "tough2", "time1"],
		["LAST CHANCE", "With one hit left, time slows on its own.", "lastchance", "time3"],
		["IRON", "He takes one more hit.", "tough3", "mercy4"],
	],
	"gun": [
		["FAST HANDS", "Reloads a third faster.", "fasthands", "lead0"],
		["HEAVY LOADS", "A body shot hits twice as hard.", "heavy", "lead3"],
		["STEADY HAND", "Tighter shots and a longer aim help.", "steady", "lead1"],
		["LAST ROUND", "The last round always kills, in slowed time.", "lastround", "lead3"],
		["TWO GUNS", "A second revolver in the other hand.", "twoguns", "time2"],
	],
	"instinct": [
		["OPEN HAND", "Shoot a gun out of a hand without slowed time.", "openhand", "mercy1"],
		["HOT STREAK", "A combo of three puts a round back in the gun.", "hotstreak", "lead4"],
		["SPLINTERS", "Wooden cover goes to pieces in a few shots.", "splinters", "lead2"],
		["ACROBAT", "A kill in the air gives back slowed time.", "acrobat", "time4"],
		["SECOND WIND", "Letting a man go gives back a hit.", "secondwind", "mercy3"],
	],
}
const BASE_HITS := 3
const DRAIN := 0.36    # slowed time used per second
const REFILL := 0.12   # and won back per second


static func _arg(name: String) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name):
			return int(a.trim_prefix(name))
	return -1


## Experience: everything Frank has earned. Tests: --xp=N.
static func xp() -> int:
	var t := _arg("--xp=")
	if t >= 0:
		return t
	return int(MenuScript.story("xp")) if MenuScript.story("xp") != "" else 0


static func add_xp(n: int) -> void:
	if _arg("--xp=") >= 0:
		return
	MenuScript.set_story("xp", str(xp() + n))


## Experience needed to reach `lvl` (level 1 at nothing): each level a little further off.
static func xp_for(lvl: int) -> int:
	var n := lvl - 1
	return 2500 * n + 250 * n * n


static func level_at(x: int) -> int:
	var l := 1
	while x >= xp_for(l + 1):
		l += 1
	return l


static func level() -> int:
	return level_at(xp())


static func points() -> int:
	return level() - 1


static func spent() -> int:
	var n := 0
	for b in BRANCHES:
		for t in 5:
			if owned(b, t):
				n += 1
	return n


static func unspent() -> int:
	return maxi(0, points() - spent())


static func owned(branch: String, tier: int) -> bool:
	return MenuScript.story("perk_%s_%d" % [branch, tier]) == "yes"


static func cost(_branch: String, _tier: int) -> int:
	return 1


## Is the card with this effect pinned? Tests: --perks=all or a list of effect ids.
## Asked many times a second during play, so read once per map (forget() when the board changes).
static var _cache := {}

static func has_fx(fx: String) -> bool:
	if not _cache.has(fx):
		var v := false
		for b in BRANCHES:
			for t in 5:
				if String(CARDS[b][t][2]) == fx:
					v = owned(b, t)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--perks="):
				var arg := a.trim_prefix("--perks=")
				v = arg == "all" or fx in arg.split(",")
		_cache[fx] = v
	return _cache[fx]


static func forget() -> void:
	_cache.clear()


## [hits, drain per second, refill per second]
static func rank() -> Array:
	var hits := BASE_HITS
	for f in ["tough1", "tough2", "tough3"]:
		hits += 1 if has_fx(f) else 0
	return [hits, DRAIN * (0.8 if has_fx("longwatch") else 1.0), REFILL]


static func reached(chapter: int) -> bool:
	var p := MenuScript.progress()
	return p[0] < 0 or int(p[0]) >= chapter


## Why a card cannot be pinned, or "" if it can (or already is).
static func why_locked(branch: String, tier: int) -> String:
	if owned(branch, tier):
		return ""
	var ch: int = FROM_CHAPTER[tier]
	if not reached(ch) or not Levels.CAMPAIGN[mini(ch, Levels.CAMPAIGN.size() - 1)]["ready"]:
		return "OPENS IN " + String(Levels.CAMPAIGN[mini(ch, Levels.CAMPAIGN.size() - 1)]["title"])
	if tier > 0 and not owned(branch, tier - 1):
		return "PIN THE CARD BEFORE IT"
	if unspent() < 1:
		return "NEEDS A POINT: LEVEL %d" % (level() + 1)
	return ""


static func pin(branch: String, tier: int) -> bool:
	if why_locked(branch, tier) != "" or owned(branch, tier):
		return false
	MenuScript.set_story("perk_%s_%d" % [branch, tier], "yes")
	forget()
	return true


## Taking a card down takes the ones after it in its row down too.
static func unpin(branch: String, tier: int) -> void:
	for t in range(tier, 5):
		MenuScript.set_story("perk_%s_%d" % [branch, t], "")
	forget()
