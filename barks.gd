## What the mobsters shout (2026-11-16): every man has a name, and the others use it. When one goes
## down, the man nearest him says so ("HE GOT VINNIE!"); the last of a group calls for the ones who are
## gone; the one giving the orders sends a man round by name. In-game text is English, all capitals,
## short enough for one line over a hat (24 characters or so).
##
## {n} = the man it is about (the dead one, or the one sent round), {p} = the hero's surname as they
## know him (MALONE, DOYLE in the prologue). A line with {n} is only used when there is a name for it.


# New York, 1939: Italian, Irish and Jewish hoods, each name recorded in every voice (two lines, gen/bark_voices.py). None of the story's own people (Frank, Eddie,
# Mickey, Briggs, Kessler, Rourke, Vail, Rosie) so a bark never sounds like the plot.
const NAMES := ["SAL", "VINNIE", "JOHNNY", "FINN", "NICKY", "JOEY", "PAULIE", "CARMINE", "SONNY", "LOU",
	"BENNY", "MOE", "IZZY", "AUGIE", "DUTCH", "RED", "LEFTY", "SEAMUS", "ROCCO", "MAX", "DANNY", "JIMMY",
	"CHARLIE", "KNUCKLES"]

# The voices the men shout in (Artlist, Eleven v3, gen/bark_voices.py): each man gets one. A line's file is
# voice/barks/<voice>_<md5 of the line as shown, 10 chars>.mp3; lines without one are only a bubble.
const VOICES := ["adam", "james", "shadow"]


static func path(voice: String, text: String) -> String:
	return "res://voice/barks/%s_%s.mp3" % [voice, text.md5_text().substr(0, 10)]


const LINES := {
	# one of them has just been shot, the nearest one saw it
	"down": ["HE GOT {n}!", "{n}'S DOWN!", "{n}! NO!", "THEY SHOT {n}!", "{p} GOT {n}!", "{n}'S HIT!",
		"{n}, GET UP!", "AW, {n}...", "YOU KILLED {n}, YOU RAT!", "WHO TELLS {n}'S MA?", "{n}! SON OF A--",
		"MAN DOWN!", "WE LOST ONE!", "HE'S PICKING US OFF!"],
	# the one giving the orders went down
	"lead_down": ["{n}'S DOWN! NOW WHAT?", "THEY GOT {n}!", "WHO'S CALLING IT NOW?", "{n}! AW, HELL..."],
	# the last of a group, the others gone
	"alone": ["{n}? ANYBODY?", "{n}? YOU THERE?", "IT'S JUST ME NOW...", "AIN'T NOBODY LEFT...", "THIS AIN'T WORTH IT..."],
	# he has seen the hero
	"spot": ["THERE HE IS!", "IT'S {p}!", "HE'S HERE!", "THE GUMSHOE!", "GOT EYES ON HIM!", "THAT'S HIM!", "{p}! GET HIM!"],
	# the lead sends a man round by name, and the general call
	"flank": ["{n}, GO AROUND!", "{n}, FLANK HIM!", "{n}, MOVE UP!", "HE'S PINNED, MOVE!", "FLANK HIM!", "GO AROUND!"],
	"round": ["{n}, GET BEHIND HIM!", "{n}, TAKE THE ALLEY!", "{n}, ROUND THE BACK!", "GET BEHIND HIM!"],
	"behind": ["BEHIND YOU, {p}!", "GOT YOU NOW!", "OVER HERE!", "SURPRISE, {p}!"],
	"cover": ["COVER!", "GET DOWN!", "IT'S {p}!", "FIND COVER!"],
	"crate": ["CHEW THROUGH IT!", "CUT THAT CRATE DOWN!", "IT'S ONLY WOOD!", "SPLINTER IT!"],
	"reload": ["RELOADING!", "COVER ME, I'M OUT!", "I'M EMPTY!", "RELOADING, COVER ME!"],
	# the hero is reloading: they push
	"empty": ["HE'S RELOADING!", "HE'S EMPTY! GO!", "NOW! PUSH HIM!", "HE'S OUT! MOVE!"],
	# his own last breath, only sometimes (a sound, no bubble)
	"death": ["Agh!", "Ugh...", "No, no, no...", "Ma...", "Not like this...", "Aaargh!", "Oh God...", "Damn you..."],
	# he has hidden a long time
	"taunt": ["COME OUT, {p}!", "CAN'T HIDE ALL NIGHT!", "WE GOT ALL NIGHT, {p}!", "COME ON OUT, SHAMUS!"],
}
