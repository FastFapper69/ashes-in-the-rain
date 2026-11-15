## Frank's instincts: the skill tree. Three branches of five cards. LEAD and TIME are bought with leads:
## the stars on Frank's closed cases, earned by how he shoots (style points, combos, main.gd _score).
## MERCY is bought only with statements: men let go who talked. A gunman and a man with a conscience,
## two ways to grow, and the game never pays for the first with the second. Everything earned
## (spent or not) is his experience: more hits he can take, longer slowed time.
## The cards can be taken down and pinned again for free between maps.
extends RefCounted

const MenuScript = preload("res://menu.gd")
const Levels = preload("res://levels.gd")

const BRANCHES := ["lead", "time", "mercy"]
const BRANCH_NAMES := {"lead": "LEAD", "time": "TIME", "mercy": "MERCY"}
const COST := [2, 3, 4, 5, 6]
const MERCY_COST := [1, 2, 2, 3, 3]   # in statements: at most one man talks on each map
const FROM_CHAPTER := [1, 1, 2, 3, 3]   # a tier opens once the story has reached this chapter (ALLY: chapter IV)
const SPARED_NEEDED := [3, 6, 10, 15, 20]   # the Conscience cards also want men let go
const ASH_LOCK := 6   # this much ash and the last two Conscience cards stay down
const CARDS := {
	"lead": [
		["FAST HANDS", "Reloads a third faster."],
		["STEADY HAND", "Tighter shots and a longer aim help."],
		["SPLINTERS", "Wooden cover goes to pieces in a few shots."],
		["LAST ROUND", "The last round always kills, in slowed time."],
		["HOT STREAK", "A combo of three puts a round back in the gun."],
	],
	"time": [
		["LONG WATCH", "Slowed time lasts a quarter longer."],
		["BLOOD FOR TIME", "A kill gives back half as much time again."],
		["LONG DIVE", "Dives fly further and land in a roll."],
		["LAST CHANCE", "With one hit left, time slows on its own."],
		["ACROBAT", "A kill in the air gives back slowed time."],
	],
	"mercy": [
		["VOICE OF THE LAW", "A shaken crew gives up sooner."],
		["OPEN HAND", "Disarm a man without slowed time."],
		["QUESTIONING", "A man let go says where Eddie's page is."],
		["SECOND WIND", "Letting a man go gives back a hit."],
		["ALLY", "Men let go may fight beside him."],
	],
}
# hits Frank can take, and how fast slowed time drains and comes back, by leads earned
const RANKS := [[0, 3, 0.4, 0.1], [10, 4, 0.34, 0.12], [24, 5, 0.3, 0.13]]


static func _test_leads() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--leads="):
			return int(a.trim_prefix("--leads="))
	return -1


## All Frank has earned, both kinds: his experience (rank).
static func earned() -> int:
	var t := _test_leads()
	if t >= 0:
		return t
	return leads_earned() + statements_earned()


## Leads: the stars on his cases (not Eddie's).
static func leads_earned() -> int:
	var t := _test_leads()
	if t >= 0:
		return t
	var n := 0
	for c in range(1, Levels.CAMPAIGN.size()):
		for m in (Levels.CAMPAIGN[c]["maps"] as Array).size():
			n += MenuScript.stars(c, m)
	return n


## Statements: men let go who talked.
static func statements_earned() -> int:
	var t := _test_leads()
	if t >= 0:
		return t / 2
	var n := 0
	for c in Levels.CAMPAIGN.size():
		for m in (Levels.CAMPAIGN[c]["maps"] as Array).size():
			n += 1 if MenuScript.story("testimony_%d-%d" % [c, m]) == "yes" else 0
	return n


static func cost(branch: String, tier: int) -> int:
	return MERCY_COST[tier] if branch == "mercy" else COST[tier]


static func spent(kind := "") -> int:
	var n := 0
	for b in BRANCHES:
		if kind == "leads" and b == "mercy" or kind == "statements" and b != "mercy":
			continue
		for t in 5:
			if owned(b, t):
				n += cost(b, t)
	return n


## What is left to pin: leads (LEAD, TIME) and statements (MERCY) are kept apart.
static func unspent(kind := "leads") -> int:
	if kind == "statements":
		return maxi(0, statements_earned() - spent("statements"))
	return maxi(0, leads_earned() - spent("leads"))


static func owned(branch: String, tier: int) -> bool:
	return MenuScript.story("instinct_%s_%d" % [branch, tier]) == "yes"


## Tests: --instincts=all or a list like lead0,lead1,time0
## Asked many times a second during play, so read once per map (forget() when the board changes).
static var _cache := {}

static func has(branch: String, tier: int) -> bool:
	var k := "%s%d" % [branch, tier]
	if not _cache.has(k):
		var v := owned(branch, tier)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--instincts="):
				var arg := a.trim_prefix("--instincts=")
				v = arg == "all" or k in arg.split(",")
		_cache[k] = v
	return _cache[k]


static func forget() -> void:
	_cache.clear()


## Frank's rank by experience: [hits, drain per second, refill per second].
static func rank() -> Array:
	var e := earned()
	var best: Array = RANKS[0]
	for r in RANKS:
		if e >= int(r[0]):
			best = r
	return [int(best[1]), float(best[2]), float(best[3])]


## The next rank: [leads needed, hits it gives], or [] at the top.
static func next_rank() -> Array:
	var e := earned()
	for r in RANKS:
		if e < int(r[0]):
			return [int(r[0]), int(r[1])]
	return []


static func reached(chapter: int) -> bool:
	var p := MenuScript.progress()
	return p[0] < 0 or int(p[0]) >= chapter


## Why a card cannot be pinned, or "" if it can (or already is).
static func why_locked(branch: String, tier: int) -> String:
	if owned(branch, tier):
		return ""
	var ch: int = 4 if branch == "mercy" and tier == 4 else FROM_CHAPTER[tier]
	if not reached(ch) or not Levels.CAMPAIGN[mini(ch, Levels.CAMPAIGN.size() - 1)]["ready"]:
		return "OPENS IN " + String(Levels.CAMPAIGN[mini(ch, Levels.CAMPAIGN.size() - 1)]["title"])
	if branch == "mercy":
		if tier >= 3 and MenuScript.guilt() >= ASH_LOCK:
			return "NOT FOR A MAN LIKE YOU, FRANK."
		var need: int = SPARED_NEEDED[tier]
		if MenuScript.spared_total() < need:
			return "LET %d MEN GO FIRST" % need
	if tier > 0 and not owned(branch, tier - 1):
		return "PIN THE CARD BEFORE IT"
	if branch == "mercy":
		if unspent("statements") < cost(branch, tier):
			return "NEEDS %d STATEMENTS" % cost(branch, tier)
	elif unspent() < cost(branch, tier):
		return "NEEDS %d LEADS" % cost(branch, tier)
	return ""


static func pin(branch: String, tier: int) -> bool:
	if why_locked(branch, tier) != "" or owned(branch, tier):
		return false
	MenuScript.set_story("instinct_%s_%d" % [branch, tier], "yes")
	forget()
	return true


## Taking a card down takes the ones after it in its branch down too.
static func unpin(branch: String, tier: int) -> void:
	for t in range(tier, 5):
		MenuScript.set_story("instinct_%s_%d" % [branch, t], "")
	forget()
