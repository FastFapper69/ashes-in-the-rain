## Frank's instincts: the upgrade board. Frank earns experience from how he fights (main.gd _score:
## style points for every man taken down, disarmed or sent off without his hat, plus men let go),
## levels up as it grows, and every level is one point to pin a card with. Three rows: FRANK (how much
## he can take), REVOLVER (his own gun, up to a second one in the other hand) and INSTINCT (tricks).
## A row is pinned left to right. Cards can be taken down and pinned again for free between maps.
extends RefCounted

const MenuScript = preload("res://menu.gd")
const Levels = preload("res://levels.gd")

const BRANCHES := ["frank", "gun", "instinct", "beretta", "shotgun", "tommy"]   # every row of cards; the guns' rows are shown at the gunsmith
const BOARD := ["frank", "instinct"]   # the rows on the cork board
const GUNS := ["gun", "beretta", "shotgun", "tommy"]   # the gunsmith's: the revolver's row is "gun"
const BRANCH_NAMES := {"frank": "FRANK", "gun": "REVOLVER", "instinct": "TRICKS", "beretta": "BERETTA", "shotgun": "SHOTGUN", "tommy": "TOMMY GUN"}
const GUN_FROM := {"gun": 1, "beretta": 1, "shotgun": 2, "tommy": 3}   # a gun is found from this chapter on (and upgraded from then)
const FROM_CHAPTER := [1, 1, 2, 2, 3]   # a tier opens once the story has reached this chapter
# name, text, effect id (main.gd _perk), icon (art/ui/instincts/icon_<icon>.png)
const CARDS := {
	"frank": [
		["TOUGH", "He takes one more hit.", "tough1", "tough1"],
		["LONG WATCH", "Slowed time lasts a quarter longer.", "longwatch", "time0"],
		["TOUGHER", "He takes one more hit.", "tough2", "tough2"],
		["LAST CHANCE", "With one hit left, time slows on its own.", "lastchance", "time3"],
		["IRON", "He takes one more hit.", "tough3", "tough3"],
	],
	"gun": [
		["FAST HANDS", "Reloads a third faster.", "fasthands", "lead0"],
		["HEAVY LOADS", "A body shot hits twice as hard.", "heavy", "heavy"],
		["STEADY HAND", "Tighter shots and a longer aim help.", "steady", "lead1"],
		["LAST ROUND", "The last round always kills, in slowed time.", "lastround", "lead3"],
		["TWO GUNS", "A second revolver in the other hand.", "twoguns", "twoguns"],
	],
	"beretta": [
		["QUICK MAGS", "Changes magazines a third faster.", "b_fast", "lead0"],
		["HOT LOADS", "Body shots hit half as hard again.", "b_hot", "heavy"],
		["STEADY GRIP", "Tighter shots and a longer aim help.", "b_steady", "lead1"],
		["LONG MAG", "Two more rounds in every magazine.", "b_mag", "lead3"],
		["TWO BERETTAS", "A second Beretta in the other hand.", "b_two", "twoguns"],
	],
	"shotgun": [
		["SHELL TUBE", "Two more shells in the tube.", "sg_tube", "lead0"],
		["BUCKSHOT", "Two more pellets in every shell.", "sg_buck", "lead3"],
	],
	"tommy": [
		["DRUM MAG", "A fifty-round drum instead of the stick.", "tg_drum", "lead0"],
		["COMPENSATOR", "Half the spread as it climbs.", "tg_comp", "lead1"],
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
		for t in tiers(b):
			if owned(b, t):
				n += 1
	return n


static func unspent() -> int:
	return maxi(0, points() - spent())


static func tiers(branch: String) -> int:
	return (CARDS[branch] as Array).size()


## The chapter a card opens in: the revolver's and Frank's by tier, a found gun's with the gun.
static func from_chapter(branch: String, tier: int) -> int:
	if branch in ["shotgun", "tommy"]:
		return int(GUN_FROM[branch])
	return FROM_CHAPTER[tier]


## Can Frank carry this gun yet (the story has reached the chapter it turns up in)?
static func gun_open(kind: String, chapter: int) -> bool:
	return chapter >= int(GUN_FROM.get("gun" if kind == "revolver" else kind, 0))


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
			for t in tiers(b):
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


## The side gun he carries (his choice at the gunsmith, 2026-11-16): "revolver" or "beretta", and one
## or two of it (two only once that row's last card is pinned).
static func side() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--side="):
			return a.trim_prefix("--side=")
	return "beretta" if MenuScript.story("side") == "beretta" else "revolver"


static func side_two() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--two":
			return true
	return MenuScript.story("side_two") == "yes" and has_fx("twoguns" if side() == "revolver" else "b_two")


static func set_side(kind: String, two: bool) -> void:
	MenuScript.set_story("side", kind)
	MenuScript.set_story("side_two", "yes" if two else "")


## The big gun he takes along into a new chapter (2026-11-16): "", "shotgun" or "tommy", once found.
## It comes with few rounds (BIG_START); more are found as ever.
const BIG_START := {"shotgun": 8, "tommy": 40}
static func big() -> String:
	return MenuScript.story("big_gun")


static func set_big(kind: String) -> void:
	MenuScript.set_story("big_gun", kind)


static func reached(chapter: int) -> bool:
	var p := MenuScript.progress()
	return p[0] < 0 or int(p[0]) >= chapter


## Why a card cannot be pinned, or "" if it can (or already is).
static func why_locked(branch: String, tier: int) -> String:
	if owned(branch, tier):
		return ""
	var ch: int = from_chapter(branch, tier)
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
	for t in range(tier, tiers(branch)):
		MenuScript.set_story("perk_%s_%d" % [branch, t], "")
	forget()
