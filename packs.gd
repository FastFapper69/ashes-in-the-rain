extends RefCounted
## The story's drawings come in packs, one per part of it (gen/packs.py decides what goes where): a
## phone's browser keeps every pack it has loaded in memory, so the page only ever holds the base
## and the pack of the chapter being played. Another part of the story means a fresh page.

const List = preload("res://packs_list.gen.gd")
static var mounted := ""   # the group whose pack this page has loaded


static func group(chapter: int, map := -1) -> String:
	var key := "%d:%d" % [chapter, map]
	if List.GROUP_OF_MAP.has(key):   # a map with a pack of its own (THE DREAM, 18. 11.)
		return String(List.GROUP_OF_MAP[key])
	return String(List.GROUP_OF_CHAPTER.get(chapter, ""))


## True when the chapter's drawings can be loaded right now (always, outside a split web build).
static func has(chapter: int, map := -1) -> bool:
	var g := group(chapter, map)
	return g == "" or not List.PROBE.has(g) or ResourceLoader.exists(String(List.PROBE[g]))


## The page already holds another part of the story: only a fresh page can drop it.
static func needs_fresh_page(chapter: int, map := -1) -> bool:
	return not has(chapter, map) and mounted != "" and mounted != group(chapter, map)


## Where the pack is: next to the page, named after this build (ashes-<hash>-<group>.pck), or for
## desktop tests in the folder given with --packs=.
static func url(chapter: int, map := -1) -> String:
	var g := group(chapter, map)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--packs="):
			return arg.trim_prefix("--packs=").path_join("pack_%s.pck" % g)
	if OS.has_feature("web"):
		var exe = JavaScriptBridge.eval("(typeof GODOT_CONFIG!=='undefined'&&GODOT_CONFIG.executable)||''", true)
		return "%s-%s.pck" % [String(exe), g]
	return ""


static func mount(path: String, chapter: int, map := -1) -> bool:
	var ok := ProjectSettings.load_resource_pack(path, true)
	if ok:
		mounted = group(chapter, map)
	return ok


## Start again on a fresh page, then go straight to chapter:map (or the title with map < 0).
static func fresh_page(chapter: int, map: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('ashes_resume','%d:%d');localStorage.setItem('ashes_alive','0');location.reload();" % [chapter, map], true)


## A resume asked for by the last page (fresh_page), once.
static func take_resume() -> Vector2i:
	if not OS.has_feature("web"):
		return Vector2i(-1, -1)
	var v = JavaScriptBridge.eval("(function(){var r=localStorage.getItem('ashes_resume');localStorage.removeItem('ashes_resume');return r||'';})()", true)
	var s := String(v) if v != null else ""
	if s.count(":") != 1:
		return Vector2i(-1, -1)
	return Vector2i(int(s.get_slice(":", 0)), int(s.get_slice(":", 1)))
