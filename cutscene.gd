extends CanvasLayer
## The story between the maps, told as a comic that comes to life: one drawn panel after another,
## the camera drifting slowly over each, rain falling across the page, and Frank's narration typed
## into cream caption boxes. A tap finishes the line being typed or turns to the next; SKIP ends it.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const TYPE_STEP := 0.032   # seconds per letter

## Every cutscene: a list of panels. A panel: its picture (art/cut/<img>.jpg); where the camera starts
## and ends ([x, y] of the picture to centre on, as fractions, and a zoom where 1.0 just fills the
## screen); the lines (a line in quotes is somebody speaking); and its weather and sounds.
## A Frank who has shot men with their hands up tells it harder: "hard" swaps a panel's lines
## ([index, line]) once the ash (menu.gd guilt) has reached this much.
const HARD_AT := 3

const SCENES := {
	# before the prologue (2026-11-15): who Eddie was, and why he walked into that alley
	"opening": [
		{"img": 82, "from": [0.5, 0.35, 1.18], "to": [0.5, 0.5, 1.0], "rain": 1.2, "stamp": "NEW YORK  ·  DECEMBER, 1947",
			"lines": ["New York, the winter of 1947. The war was over. The city still hadn't come home.", "It rained like it meant to wash something away. It never did."]},
		{"img": 83, "from": [0.3, 0.5, 1.12], "to": [0.62, 0.5, 1.0], "rain": 0.3, "at": ["tl", "tl"],
			"lines": ["The docks fed the city, and the city fed on the docks. Every morning men stood in the rain and waited to be picked.", "Cornelius Vail owned the ships, the piers and most of the men who worked them. The papers called him the Saint. He built churches."]},
		{"img": 84, "from": [0.45, 0.4, 1.0], "to": [0.32, 0.55, 1.2], "rain": 0.0, "hit": 1, "stamp": "PIER 17  ·  AUGUST 14, 1939  ·  2:10 A.M.",
			"lines": ["In the summer of '39 the longshoremen on Pier 17 voted to strike. That night the pier burned with eleven of them inside.", "The report said bad wiring. A young cop signed it. Nobody ever asked him how he slept."]},
		{"img": 78, "from": [0.4, 0.45, 1.1], "to": [0.58, 0.5, 1.0], "rain": 0.6, "stamp": "NEW YORK  ·  DECEMBER 17, 1947  ·  11:40 P.M.",
			"lines": ["Eddie Doyle wrote crime for the Evening Ledger. Nobody read past the second paragraph.", "Eight years on, he was the only man in New York still asking about Pier 17."]},
		{"img": 79, "from": [0.5, 0.45, 1.0], "to": [0.45, 0.4, 1.2], "rain": 0.6, "at": ["tl", "tl", "br"],
			"lines": ["Somebody called the paper and asked for him by name. Said he'd sell him the man who paid.", "\"Behind the Blue Note. Half past one. Come alone.\"", "He didn't call me. He wanted to be wrong first."]},
		{"img": 80, "from": [0.55, 0.55, 1.2], "to": [0.5, 0.5, 1.0], "rain": 0.0, "hit": 1,
			"lines": ["Eddie carried a rifle across Guadalcanal. He came home and swore he'd never carry a gun again.", "That night he carried one."]},
		{"img": 81, "from": [0.45, 0.5, 1.0], "to": [0.6, 0.55, 1.18], "rain": 1.2,
			"lines": ["He was early. He was always early.", "They were earlier."]},
	],
	"eddie": [
		{"img": 49, "from": [0.5, 0.4, 1.12], "to": [0.62, 0.5, 1.0], "rain": 1.0, "stamp": "NEW YORK  ·  DECEMBER 18, 1947  ·  2:10 A.M.",
			"lines": ["Eleven days of rain. The city had forgotten what dry felt like.", "Somewhere under it, a phone was about to ring."]},
		{"img": 50, "from": [0.45, 0.45, 1.0], "to": [0.66, 0.42, 1.18], "rain": 0.0, "sound": "phone_ring",
			"lines": ["Ten past two. Nobody calls at ten past two with good news.", "I knew before I picked it up. You always know."]},
		{"img": 51, "from": [0.3, 0.5, 1.15], "to": [0.5, 0.62, 1.02], "rain": 1.0,
			"lines": ["They had him under a tarp behind the Blue Note, like something the club forgot to take out.", "Eddie Doyle. Reporter. My friend, when he remembered to be."]},
		{"img": 52, "from": [0.5, 0.5, 1.0], "to": [0.5, 0.56, 1.22], "rain": 0.6,
			"lines": ["Somebody had to look. Somebody always does.", "The man in the puddle looked like he owed somebody money."]},
		{"img": 53, "from": [0.35, 0.45, 1.05], "to": [0.66, 0.58, 1.3], "rain": 0.7, "hit": 1,
			"lines": ["In his fist, a matchbook from the Blue Note.", "His notebook lay open in the rain, one word on the page. My name. They took it before I could ask it anything."]},
	],
	# THE LAUNDRY's street fills (user 18. 11., rule 30): a page in the middle of the map
	"horde": [
		{"img": 324, "from": [0.45, 0.45, 1.0], "to": [0.6, 0.55, 1.18], "rain": 1.1, "hit": 1,
			"lines": ["Three cars. Fifteen men. Somebody had made a phone call about the man asking questions in the laundry.", "Too many for one gun. Across the street a tenement door stood open."]},
	],
	"interlude": [
		{"img": 54, "from": [0.62, 0.45, 1.0], "to": [0.52, 0.52, 1.2], "rain": 0.0,
			"lines": ["A laundry receipt. Two hundred dollars for shirts nobody would ever wear.", "Signed M. T. Mickey Teague signed everything. Even his fights."]},
		{"img": 55, "from": [0.5, 0.5, 1.12], "to": [0.42, 0.45, 1.0], "rain": 0.0,
			"lines": ["Two weeks ago Eddie bought the coffee. Eddie never bought the coffee.", "\"Frank, I need to tell you something. Tomorrow.\"", "Tomorrow was a long time coming. Then it didn't come at all."]},
		{"img": 325, "from": [0.4, 0.5, 1.15], "to": [0.62, 0.45, 1.0], "rain": 0.9, "hit": 1, "at": ["tl", "bl"],   # (the window and its line on the right stay clear)
			"lines": ["Top floor, a stranger's flat. The door wouldn't hold long. The stairs were full of boots.", "Behind me a window, and a washing line strung across to the next house. My mother always said I'd break my neck on one."]},
	],
	"teague": [
		{"img": 56, "from": [0.3, 0.6, 1.15], "to": [0.55, 0.5, 1.0], "rain": 0.0, "at": ["tl", "tl", "br"],
			"lines": ["Mickey went down on cue, like always.", "\"They said sell the kid a name. Then they said take care of him. I never could say no, Frank.\"", "\"Feed my birds... Pier Seventeen. Ask your boss.\""],
			"hard": [[0, "Mickey went down. This time nobody had paid him to."]]},
		{"img": 57, "from": [0.5, 0.42, 1.0], "to": [0.47, 0.38, 1.16], "rain": 0.0,
			"lines": ["Rosie Kowalski came down off the stage like it was the last song of the night.", "Eddie's girl. She'd been holding something for him."]},
		{"img": 58, "from": [0.45, 0.5, 1.0], "to": [0.52, 0.48, 1.2], "rain": 0.0,
			"lines": ["\"He said if anything happened, you'd know what to do.\""]},
		{"img": 59, "from": [0.4, 0.5, 1.0], "to": [0.62, 0.45, 1.55], "rain": 0.0, "hit": 1,
			"lines": ["Pier 17. Eleven dead. Who signed the report?", "Everybody on the West Side remembered that fire. I remembered it as well as anybody."],
			"hard": [[1, "Everybody on the West Side remembered that fire. I'd spent eight years learning how not to."]]},
	],
	"dream": [
		{"img": 70, "from": [0.72, 0.5, 1.25], "to": [0.5, 0.45, 1.0], "rain": 0.0, "hit": 1,
			"lines": ["Pier 17, August 1939. In the dream I'm twenty-six again, with a new badge and a clean conscience.", "The doors are chained. Somebody on the other side keeps knocking. I count the knocks.", "I always count them. I never get to the door."],
			"hard": [[2, "Lately there are more hands on that door. I've been adding them all week."]]},
	],
	"memory": [
		{"img": 88, "from": [0.62, 0.5, 1.2], "to": [0.45, 0.45, 1.0], "rain": 0.0, "at": ["bl", "bl"],
			"lines": ["Rourke drove me himself. The wipers counted for both of us.", "He watched me in the mirror all the way uptown. The last time I sat behind him like that I was seventeen, and the whole block was burning."]},
		{"img": 87, "from": [0.4, 0.5, 1.0], "to": [0.62, 0.42, 1.35], "rain": 0.0, "at": ["tl", "bl"],
			"lines": ["March 1931. I came running from the pool hall when I heard the bells.", "Engine 54 was already there. My father went up the ladder for the Kowalczyk kids on the fourth floor."]},
	],
	"kessler": [
		{"img": 64, "from": [0.35, 0.45, 1.05], "to": [0.55, 0.62, 1.4], "rain": 0.0, "hit": 1, "at": ["tr", "br", "br"],
			"lines": ["Second drawer, like Eddie said. PIER 17. FIRE. CAUSE: ACCIDENTAL.", "At the bottom, in ink gone brown: Ptl. F. Malone. My hand. My two hundred dollars.", "Kessler had kept the original for eight years. Insurance against the Saint, he called it. Against men like me."]},
		{"img": 65, "from": [0.7, 0.4, 1.2], "to": [0.4, 0.45, 1.0], "rain": 0.8, "sound": "door",
			"lines": ["\"Frank Malone. You're under arrest for the murder of Eddie Doyle.\"", "Declan Rourke taught me how to tie a tie. He coughed into my mother's handkerchief and wouldn't look me in the eye."]},
	],
	"underground": [
		{"img": 74, "from": [0.62, 0.5, 1.15], "to": [0.45, 0.5, 1.0], "rain": 1.2, "sound": "door",
			"lines": ["They put me in the back of a radio car with my own cuffs on.", "The kid up front had a mother who prayed for him. I made sure she'd still have him in the morning. Then I went for the stairs."]},
		{"img": 75, "from": [0.4, 0.4, 1.0], "to": [0.68, 0.35, 1.25], "rain": 0.0, "hit": 1,
			"lines": ["Lieutenant Harlan Briggs. Four Bronze Stars and not one bent dollar.", "He counted every shell out loud. In the war they said he never had to count past one."]},
	],
	"briggs": [
		{"img": 76, "from": [0.3, 0.42, 1.2], "to": [0.62, 0.5, 1.25], "rain": 0.0,
			"lines": ["I had him. Eight years of guilt and one finger on a trigger.", "\"Go on, Malone. I've seen what you signed. I've also seen what they paid you. Two hundred. It doesn't add up.\""],
			"hard": [[0, "I had him. Men had put their hands up for me all week. Not all of them walked away."]]},
		{"img": 76, "from": [0.62, 0.5, 1.25], "to": [0.5, 0.5, 1.0], "rain": 0.0, "when": ["briggs", "spared"],
			"lines": ["I put the gun down. He gave me the other half of the truth, out of Rourke's own desk, like a man handing back a wallet."]},
		{"img": 76, "from": [0.62, 0.5, 1.25], "to": [0.5, 0.5, 1.0], "rain": 0.0, "when": ["briggs", "killed"], "hit": 1,
			"lines": ["The only honest man who ever hunted me. Eddie would have written that down.", "I didn't."]},
		{"img": 77, "from": [0.3, 0.45, 1.15], "to": [0.55, 0.45, 1.0], "rain": 1.4,
			"lines": ["Up in the Saint's tower, two old men were drinking to me.", "\"He'll come,\" Rourke said. \"He always comes. He's his father's son.\""]},
	],
	# (QUEUE §16 E, 18. 11.) one establishing panel before each dock map after the first: where he is, in a line or two
	"cranes": [
		{"img": 320, "from": [0.35, 0.4, 1.15], "to": [0.55, 0.55, 1.0], "rain": 1.2, "at": ["tl", "bl"],   # (Frank is low in the middle)
			"lines": ["The cranes stood over the quay like gallows waiting for a hanging.", "Somebody up there was working the night shift. Nobody unloads honest cargo at four in the morning."]},
	],
	"lucia": [
		{"img": 321, "from": [0.6, 0.6, 1.15], "to": [0.45, 0.4, 1.0], "rain": 1.0,
			"lines": ["The Santa Lucia, out of Palermo. Registered to a company with no office and no telephone.", "Vail's ships always came in at night. Honest freight doesn't mind the sun."]},
	],
	"hold": [
		{"img": 322, "from": [0.62, 0.3, 1.0], "to": [0.5, 0.6, 1.25], "rain": 0.4,
			"lines": ["Below decks the air was older than the ship.", "Whatever Vail was shipping, he didn't want it counted."]},
	],
	"harbor": [
		{"img": 323, "from": [0.35, 0.55, 1.1], "to": [0.68, 0.3, 1.2], "rain": 1.1,
			"lines": ["The harbor master's office. One light on upstairs.", "Kessler had kept that light burning for eight years. Like a man waiting for a knock."]},
	],
	"docks": [
		{"img": 60, "from": [0.3, 0.55, 1.12], "to": [0.6, 0.45, 1.0], "rain": 1.2,
			"lines": ["The waterfront at four in the morning. The ash was thicker down here.", "Pier 17 had been dead for eight years. Nobody told the smoke."],
			"hard": [[0, "The waterfront at four in the morning. The ash was thicker down here, or I was carrying more of it."]]},
		{"img": 61, "from": [0.5, 0.4, 1.0], "to": [0.5, 0.3, 1.25], "rain": 0.0, "sound": "match",
			"lines": ["Bruno Kessler. Dock master since '38. Sleeps with every door open.", "A man who sleeps like that knows what a locked door costs."]},
	],
}

## The piano under each story: Satie's first Gnossienne for Eddie, a slow lament for the guilt,
## a smoky jazz for the nights on the move.
const PIANO := {"opening": "gnossienne", "eddie": "gnossienne", "interlude": "broken_trust", "horde": "broken_trust", "teague": "melancholia",
	"dream": "melancholia", "memory": "melancholia", "kessler": "melancholia", "docks": "broken_trust", "cranes": "broken_trust", "lucia": "broken_trust", "hold": "broken_trust", "harbor": "melancholia", "underground": "broken_trust", "briggs": "gnossienne"}

## What lives in each picture, so no panel is a still: [x, y, radius (fractions of the picture), kind].
## neon: buzzes and now and then stutters; lamp: breathes; fire: flickers fast; siren: turns on and
## off; storm: lightning in the windows now and then; smoke: drifts up from there; fog: rolls along the bottom.
const LIVE := {
	78: [[0.437, 0.388, 0.06, "lamp"]],
	79: [[0.279, 0.336, 0.07, "lamp"]],
	80: [[0.224, 0.02, 0.07, "lamp"]],
	81: [[0.829, 0.283, 0.05, "lamp"], [0.985, 0.13, 0.05, "neon"], [0.5, 0.95, 0.0, "fog"]],
	82: [[0.5, 0.95, 0.0, "fog"], [0.4, 0.55, 0.05, "smoke"], [0.7, 0.6, 0.05, "smoke"]],
	83: [[0.5, 0.95, 0.0, "fog"]],
	84: [[0.25, 0.3, 0.16, "fire"], [0.5, 0.25, 0.2, "fire"], [0.7, 0.42, 0.15, "fire"], [0.6, 0.08, 0.08, "smoke"]],
	49: [[0.405, 0.68, 0.07, "neon"], [0.6, 0.47, 0.06, "lamp"], [0.06, 0.4, 0.04, "lamp"], [0.2, 0.05, 0.05, "smoke"], [0.85, 0.08, 0.05, "smoke"]],
	50: [[0.83, 0.45, 0.11, "lamp"], [0.5, 0.95, 0.0, "fog"]],
	51: [[0.55, 0.13, 0.11, "neon"], [0.57, 0.55, 0.05, "lamp"], [0.66, 0.5, 0.05, "lamp"], [0.5, 0.95, 0.0, "fog"]],
	52: [[0.48, 0.18, 0.13, "neon"]],
	54: [[0.12, 0.2, 0.08, "neon"]],
	55: [[0.44, 0.13, 0.06, "lamp"]],
	56: [[0.6, 0.2, 0.12, "lamp"], [0.5, 0.6, 0.06, "smoke"]],
	57: [[0.42, 0.2, 0.16, "lamp"], [0.5, 0.5, 0.06, "smoke"]],
	59: [[0.5, 0.3, 0.16, "lamp"]],
	60: [[0.61, 0.79, 0.05, "neon"], [0.5, 0.95, 0.0, "fog"]],
	61: [[0.68, 0.28, 0.08, "neon"], [0.7, 0.46, 0.04, "fire"], [0.5, 0.95, 0.0, "fog"]],
	64: [[0.06, 0.36, 0.09, "lamp"]],
	65: [[0.1, 0.42, 0.1, "siren"], [0.8, 0.55, 0.07, "lamp"]],
	70: [[0.1, 0.5, 0.2, "fire"], [0.93, 0.5, 0.2, "fire"], [0.17, 0.32, 0.16, "fire"], [0.62, 0.84, 0.12, "fire"], [0.66, 0.08, 0.08, "fire"], [0.5, 0.1, 0.08, "smoke"]],
	74: [[0.81, 0.04, 0.09, "siren"], [0.12, 0.24, 0.035, "lamp"], [0.34, 0.24, 0.035, "lamp"], [0.5, 0.95, 0.0, "fog"]],
	75: [[0.51, 0.17, 0.07, "lamp"], [0.2, 0.42, 0.04, "neon"], [0.5, 0.95, 0.0, "fog"]],
	76: [[0.07, 0.6, 0.06, "fire"], [0.6, 0.36, 0.05, "lamp"], [0.42, 0.38, 0.05, "lamp"]],
	77: [[0.11, 0.72, 0.12, "fire"], [0.62, 0.3, 0.2, "storm"]],
}

## What each panel sounds like, by scene and panel (its place in SCENES): the loops under it (dB),
## the music stems (base, lead, tension, fight), rain and whether we hear it from inside, and cues:
## [seconds after the panel opens, sound, dB]. A cue only plays while its panel is still up.
const TUNE := [-13.0, -12.0, -80.0, -80.0]
const DREAD := [-24.0, -80.0, -12.0, -80.0]
const AUDIO := {
	"opening": [
		{"bed": {"city": -14.0}, "rain": 1.2},
		{"bed": {"city": -18.0, "water": -16.0}, "rain": 0.3},
		{"bed": {"fire": -8.0, "crowd": -20.0, "siren": -24.0}, "rain": 0.0},
		{"bed": {"lamp_hum": -22.0}, "rain": 0.6, "in": true, "cues": [[0.8, "type", -8.0], [3.6, "type", -9.0]]},
		{"bed": {"lamp_hum": -24.0}, "rain": 0.6, "in": true, "cues": [[0.2, "phone_ring", -8.0]]},
		{"bed": {"lamp_hum": -24.0}, "rain": 0.5, "in": true, "cues": [[1.0, "cyl_open", -6.0], [2.0, "shell_in", -6.0], [2.6, "shell_in", -7.0], [3.6, "cyl_spin", -6.0]]},
		{"bed": {"city": -17.0, "neon_hum": -18.0}, "rain": 1.1, "cues": [[1.4, "step1", -10.0], [1.95, "step2", -10.0], [2.5, "step1", -11.0]]},
	],
	"eddie": [
		{"bed": {"city": -14.0, "neon_hum": -20.0}, "rain": 1.0, "cues": [[1.4, "thunder", -7.0]]},
		{"bed": {"lamp_hum": -22.0}, "rain": 0.9, "in": true},
		{"bed": {"city": -17.0, "siren": -24.0}, "rain": 1.0, "cues": [[1.8, "step1", -10.0], [2.35, "step2", -10.0], [2.9, "step1", -11.0]]},
		{"bed": {"city": -19.0}, "rain": 0.6, "cues": [[0.8, "drip", -8.0], [2.4, "drip", -10.0], [4.1, "drip", -9.0]]},
		{"bed": {"city": -20.0}, "rain": 0.7, "cues": [[1.2, "page", -9.0]]},
	],
	"horde": [
		{"bed": {"city": -15.0}, "rain": 1.1, "cues": [[0.3, "car_arrive", -4.0], [1.4, "door", -8.0], [1.9, "door", -9.0], [2.6, "step1", -9.0], [2.9, "step2", -9.0]]},
	],
	"interlude": [
		{"bed": {"steam": -17.0, "lamp_hum": -22.0}, "rain": 0.5, "in": true, "cues": [[1.0, "page", -9.0]]},
		{"bed": {"crowd": -17.0}, "rain": 0.7, "in": true, "cues": [[1.0, "cup", -6.0], [7.5, "cup", -8.0]]},
		{"bed": {"lamp_hum": -24.0}, "rain": 0.9, "in": true, "music": DREAD, "cues": [[0.5, "knock", -2.0], [1.3, "knock", -3.0], [2.4, "step1", -9.0], [2.7, "step2", -9.0], [3.6, "knock", -1.0]]},
	],
	"teague": [
		{"bed": {"lamp_hum": -21.0}, "rain": 0.8, "in": true, "cues": [[0.3, "shot_player", -2.0], [0.8, "body_fall", -3.0], [1.9, "coo", -10.0], [2.6, "wing", -14.0]]},   # the empty club; his pigeons stir in their cage
		{"bed": {"lamp_hum": -22.0}, "rain": 0.8, "in": true, "music": [-12.0, -9.0, -80.0, -80.0]},
		{"bed": {"lamp_hum": -24.0}, "rain": 0.8, "in": true, "cues": [[1.5, "page", -9.0]]},
		{"bed": {"lamp_hum": -22.0}, "rain": 0.5, "in": true, "cues": [[0.6, "page", -8.0]]},
	],
	"dream": [
		{"bed": {"fire": -5.0}, "rain": 0.0, "music": DREAD, "cues": [[0.7, "chain", -5.0], [9.0, "creak", -7.0], [17.0, "creak", -8.0], [21.0, "wood_break", -9.0]]
			+ [[2.4, "knock", -3.0], [4.2, "knock", -4.0], [5.6, "knock", -3.0], [7.6, "knock", -5.0], [9.6, "knock", -3.0], [11.3, "knock", -4.0],
			[13.4, "knock", -6.0], [15.2, "knock", -4.0], [17.6, "knock", -7.0], [20.0, "knock", -8.0], [23.5, "knock", -10.0]]},
	],
	"memory": [
		{"bed": {"city": -20.0}, "rain": 1.0, "in": true, "cues": [[0.4, "cuffs", -9.0]]},
		{"bed": {"fire": -6.0, "siren": -13.0}, "rain": 0.0, "music": DREAD, "cues": [[2.5, "wood_break", -9.0], [6.0, "glass", -12.0]]},
	],
	"kessler": [
		{"bed": {"lamp_hum": -22.0}, "rain": 0.5, "in": true, "cues": [[0.3, "drawer", -4.0], [1.7, "page", -8.0]]},
		{"bed": {"siren": -14.0, "city": -18.0}, "rain": 0.8, "music": DREAD, "cues": [[4.5, "cuffs", -3.0]]},
	],
	"underground": [
		{"bed": {"siren": -11.0, "city": -16.0}, "rain": 1.2, "cues": [[1.6, "cuffs", -5.0], [9.0, "door", -6.0], [9.8, "step1", -8.0], [10.2, "step2", -8.0], [10.6, "step1", -8.0]]},
		{"bed": {"train_loop": -17.0}, "rain": 0.0, "music": DREAD, "cues": [[1.0, "drip", -10.0], [3.0, "shell_in", -4.0], [3.9, "shell_in", -4.0], [4.8, "shell_in", -4.0], [6.3, "cyl_spin", -5.0]]},
	],
	"briggs": [
		{"bed": {"fire": -18.0, "train_loop": -24.0}, "rain": 0.0, "music": DREAD, "cues": [[0.8, "hammer", -3.0], [5.0, "drip", -11.0]]},
		{"bed": {"fire": -20.0}, "rain": 0.0, "music": [-16.0, -14.0, -80.0, -80.0], "cues": [[0.9, "clink", -5.0]]},
		{"bed": {"fire": -20.0}, "rain": 0.0, "music": [-80.0, -80.0, -16.0, -80.0], "cues": [[0.5, "shot_player", -1.0], [1.3, "body_fall", -3.0]]},
		{"bed": {"fire": -15.0}, "rain": 1.4, "in": true, "music": DREAD, "cues": [[1.0, "thunder", -4.0], [3.2, "toast", -4.0]]},
	],
	"cranes": [
		{"bed": {"water": -12.0, "city": -24.0}, "rain": 1.2, "cues": [[1.2, "chain", -9.0], [4.5, "creak", -10.0], [7.0, "foghorn", -12.0]]},
	],
	"lucia": [
		{"bed": {"water": -10.0}, "rain": 1.0, "cues": [[1.5, "creak", -9.0], [5.0, "foghorn", -10.0]]},
	],
	"hold": [
		{"bed": {"water": -20.0}, "rain": 0.4, "in": true, "cues": [[0.8, "drip", -8.0], [2.6, "chain", -12.0], [4.4, "drip", -9.0]]},
	],
	"harbor": [
		{"bed": {"water": -11.0, "lamp_hum": -26.0}, "rain": 1.1, "cues": [[2.0, "foghorn", -9.0]]},
	],
	"docks": [
		{"bed": {"water": -9.0, "city": -24.0}, "rain": 1.2, "cues": [[2.0, "foghorn", -8.0], [13.0, "foghorn", -11.0]]},
		{"bed": {"water": -19.0, "neon_hum": -21.0}, "rain": 0.4, "in": true},
	],
}
var audio = null   # sfx.gd: main.gd hands it over

var scene_id := ""
var done := Callable()    # called once the last panel has gone dark (or SKIP)
var sound := Callable()   # func(name: String, db: float)
var shot := Callable()    # tests only: func(name: String) saves a picture
var fast := false         # tests: no waiting to read

var _panels: Array = []
var _i := -1
var _line := 0
var _pic: Sprite2D
var _old: Sprite2D
var _stage: Node2D
var _rain: Control
var _drops: Array = []
var _rain_on := 0.0
var _rain_want := 0.0
var _boxes: Array = []
var _typing: Label
var _type_t := 0.0
var _wait := 0.0     # seconds left to read the line, then the next one comes by itself
var _voiced := 0.0   # how long Frank's recorded voice for this line runs
var _said := 0.0     # how long this line has been on: the voice is never cut short by the next one
var _pan_t := 0.0
var _pan_len := 8.0
var _font_type: Font
var _font_head: FontVariation
var _stamp_box: Control
var _flash: ColorRect
var _black: ColorRect
var _ending := false
var _lives: Array = []   # {node, kind, base, phase}: the lights of the picture on screen
var _clock := 0.0
var _shot_taken := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panels = []
	var all: Array = SCENES.get(scene_id, [])
	for k in all.size():   # a panel that belongs to one of the player's choices only
		var p: Dictionary = all[k]
		if p.has("when") and load("res://menu.gd").story(String(p["when"][0])) != String(p["when"][1]):
			continue
		if p.has("hard") and load("res://menu.gd").guilt() >= HARD_AT:   # the ash shows in how he tells it
			p = p.duplicate()
			var lines: Array = (p["lines"] as Array).duplicate()
			for pair in p["hard"]:
				lines[int(pair[0])] = pair[1]
			p["lines"] = lines
		p = p.duplicate()
		p["_k"] = k
		_panels.append(p)
	_font_type = load("res://fonts/SpecialElite.ttf")
	_font_head = FontVariation.new()
	_font_head.base_font = load("res://fonts/Oswald.ttf")
	_font_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	var vig := TextureRect.new()   # the page darkens toward its edges
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.05, 1.05)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.75))
	grad.add_point(0.55, Color(0, 0, 0, 0.0))
	g.gradient = grad
	vig.texture = g
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var Paper = load("res://paper.gd")   # SKIP is a strip of tape like every other button in the game
	var skip: Control = Paper.button("tape", Vector2(150.0, 52.0), _finish, func(_n: String) -> void: pass)
	Paper.write(skip, "SKIP", _font_head, 22, Paper.INK)
	skip.modulate.a = 0.85
	skip.position = Vector2(get_viewport().get_visible_rect().size.x - 150.0 - 40.0, 22.0)
	skip.rotation = deg_to_rad(1.0)
	skip.name = "Skip"
	add_child(skip)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	for k in 170:
		_drops.append(Vector3(randf(), randf(), randf_range(0.35, 1.0)))
	get_viewport().size_changed.connect(_place_pic)
	get_viewport().size_changed.connect(func() -> void:
		skip.position.x = get_viewport().get_visible_rect().size.x - 150.0 - 40.0)
	_next_panel()


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size


func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT])
	if not tap or _ending:
		return
	var at: Vector2 = event.position if not event is InputEventKey else Vector2.ZERO
	if at.x > _view().x - 190.0 and at.y < 90.0:   # the SKIP button takes its own taps
		return
	get_viewport().set_input_as_handled()
	var left := _voiced - _said   # Frank still speaking this line: a tap shows the words, he finishes the sentence
	if _typing != null and _typing.visible_characters < _typing.text.length():
		_typing.visible_characters = _typing.text.length()   # the whole line at once
		_wait = maxf(2.5, left + 0.3)
	elif left > 0.15 and audio != null and audio.voice_on():
		_wait = minf(_wait, left + 0.3)
	else:
		_advance()


func _process(delta: float) -> void:
	if _ending:
		return
	# the slow drift over the picture
	_pan_t += delta
	_place_pic()
	# the letters of the line being typed
	_said += delta
	if _typing != null and _typing.visible_characters < _typing.text.length():
		_type_t += delta
		# the letters keep pace with the voice: the words come up as he says them, a little ahead
		var step := TYPE_STEP if _voiced <= 0.0 else clampf(_voiced * 0.78 / maxf(1.0, _typing.text.length()), 0.022, 0.085)
		while _type_t > step and _typing.visible_characters < _typing.text.length():
			_type_t -= step
			_typing.visible_characters += 1
			var ch := _typing.text[_typing.visible_characters - 1]
			if ch in ".,?!":
				_type_t = -0.18
			if ch != " " and _typing.visible_characters % 2 == 0 and sound.is_valid():
				sound.call("type", -16.0)
		if fast:
			_typing.visible_characters = _typing.text.length()
		if _typing.visible_characters >= _typing.text.length():
			# time to read the line, counted from when it began, and never before the voice has finished
			_wait = 1.0 if fast else maxf(maxf(0.9, 1.8 + _typing.text.length() * 0.035 - _said), _voiced - _said + 0.6)
	elif _wait > 0.0:
		if fast and not _shot_taken and shot.is_valid() and _line == _panels[_i]["lines"].size() - 1 and _wait < 0.6:   # once the last box is in
			_shot_taken = true
			shot.call("cut_%s_%d" % [scene_id, _i])
		_wait -= delta
		# on the web a voice can start a moment late: hold the page until it has really stopped (a cap,
		# in case the audio never reports its end)
		var talking: bool = audio != null and _voiced > 0.0 and audio.voice_on() and _said < _voiced + 2.0
		if _wait <= 0.0:
			if talking:
				_wait = 0.05   # check again next moment
			else:
				_advance()
	_clock += delta
	_tick_live(delta)
	# the rain over the page
	_rain_on = move_toward(_rain_on, _rain_want, delta * 0.8)
	for k in _drops.size():
		var d: Vector3 = _drops[k]
		d.y += delta * (0.9 + d.z * 1.6)
		d.x -= delta * (0.08 + d.z * 0.12)
		if d.y > 1.1:
			d = Vector3(randf() * 1.2, -0.1 - randf() * 0.2, d.z)
		_drops[k] = d
	_rain.queue_redraw()
	pass


func _draw_rain() -> void:
	if _rain_on <= 0.01:
		return
	var view := _view()
	for d in _drops:   # far drops thin and faint, near ones long and brighter: depth in the rain itself
		var p := Vector2(d.x * view.x, d.y * view.y)
		var ln: float = 18.0 + d.z * d.z * 70.0
		_rain.draw_line(p, p + Vector2(-0.14, 1.0).normalized() * ln, Color(0.85, 0.87, 0.92, (0.06 + 0.16 * d.z) * _rain_on), 0.8 + d.z * 1.4)
		if d.z > 0.8 and d.y > 0.93:   # the nearest ones break on the bottom of the frame
			_rain.draw_line(p + Vector2(-8.0, 0.0), p + Vector2(8.0, -6.0), Color(0.85, 0.87, 0.92, 0.12 * _rain_on), 1.2)


## The picture's own lights, laid over it and moving with it.
func _make_live(pic: Sprite2D, img: int) -> void:
	var size: Vector2 = pic.texture.get_size()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var blob: Texture2D = load("res://art/light_blob.png")
	for l in LIVE.get(img, []):
		var at := (Vector2(l[0], l[1]) - Vector2(0.5, 0.5)) * size
		var kind: String = l[3]
		var r: float = float(l[2]) * size.x
		match kind:
			"smoke", "fog":
				var pt := CPUParticles2D.new()
				pt.texture = blob
				pt.position = at
				pt.local_coords = true
				if kind == "fog":   # low mist rolling across the bottom of the picture
					pt.position = Vector2(0.0, size.y * 0.42)
					pt.amount = 14
					pt.lifetime = 9.0
					pt.preprocess = 9.0
					pt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
					pt.emission_rect_extents = Vector2(size.x * 0.6, size.y * 0.06)
					pt.direction = Vector2(1.0, 0.0)
					pt.spread = 10.0
					pt.gravity = Vector2.ZERO
					pt.initial_velocity_min = 20.0
					pt.initial_velocity_max = 45.0
					pt.scale_amount_min = 3.0
					pt.scale_amount_max = 5.0
				else:   # a thin column drifting up and away
					pt.amount = 10
					pt.lifetime = 6.0
					pt.preprocess = 6.0
					pt.direction = Vector2(0.15, -1.0)
					pt.spread = 12.0
					pt.gravity = Vector2(8.0, -6.0)
					pt.initial_velocity_min = 25.0
					pt.initial_velocity_max = 50.0
					pt.scale_amount_min = 0.6
					pt.scale_amount_max = 1.4
				var g := Gradient.new()
				g.set_color(0, Color(0.8, 0.8, 0.82, 0.0))
				g.add_point(0.25, Color(0.8, 0.8, 0.82, 0.13 if kind == "fog" else 0.18))
				g.set_color(g.get_point_count() - 1, Color(0.8, 0.8, 0.82, 0.0))
				pt.color_ramp = g
				pic.add_child(pt)
			_:
				var col: Color = {"neon": Color(1.0, 0.18, 0.12), "lamp": Color(1.0, 0.8, 0.5), "fire": Color(1.0, 0.5, 0.15),
						"siren": Color(1.0, 0.1, 0.08), "storm": Color(0.75, 0.85, 1.0)}[kind]
				var glow := Sprite2D.new()
				glow.texture = blob
				glow.material = add
				glow.position = at
				glow.scale = Vector2.ONE * r * 2.2 / 256.0
				glow.modulate = Color(col, 0.0)
				pic.add_child(glow)
				_lives.append({"node": glow, "kind": kind, "base": {"neon": 0.45, "lamp": 0.3, "fire": 0.5, "siren": 0.7, "storm": 0.0}[kind],
						"phase": randf() * TAU, "next": randf_range(1.5, 4.0), "dip": 0.0})


func _tick_live(delta: float) -> void:
	for l in _lives:
		var n: Sprite2D = l["node"]
		if not is_instance_valid(n):
			continue
		var a: float = l["base"]
		var ph: float = l["phase"]
		l["next"] = float(l["next"]) - delta
		match String(l["kind"]):
			"neon":   # a steady buzz; every few seconds it stutters off and catches again
				a *= 0.92 + 0.08 * sin(_clock * 60.0 + ph)
				if float(l["next"]) <= 0.0:
					l["next"] = randf_range(2.5, 6.0)
					l["dip"] = randf_range(0.18, 0.4)
				if float(l["dip"]) > 0.0:
					l["dip"] = float(l["dip"]) - delta
					a *= 0.15 if fmod(float(l["dip"]), 0.12) < 0.06 else 1.0
			"lamp":
				a *= 0.85 + 0.15 * sin(_clock * 1.3 + ph) * sin(_clock * 0.7 + ph * 2.0)
			"fire":
				a *= 0.6 + 0.4 * absf(sin(_clock * 9.0 + ph) * sin(_clock * 13.7 + ph * 3.0)) + randf() * 0.15
			"siren":
				a *= 1.0 if fmod(_clock + ph, 1.0) < 0.5 else 0.08
			"storm":   # far lightning in the glass: a double flicker every so often
				if float(l["next"]) <= 0.0:
					l["next"] = randf_range(4.0, 8.0)
					l["dip"] = 0.5
				if float(l["dip"]) > 0.0:
					l["dip"] = float(l["dip"]) - delta
					var d: float = l["dip"]
					a = 0.55 if (d > 0.42 or (d > 0.2 and d < 0.32)) else 0.0
		n.modulate.a = a   # under the picture: its fade carries the lights too


## Where the camera is over the current picture: from its start to its end, eased, over the time the
## panel is up, always covering the whole screen.
func _place_pic() -> void:
	if _pic == null:
		return
	var p: Dictionary = _panels[_i]
	var k := clampf(_pan_t / _pan_len, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var a: Array = p["from"]
	var b: Array = p["to"]
	var f := Vector2(lerpf(a[0], b[0], k), lerpf(a[1], b[1], k))
	var zoom := lerpf(a[2], b[2], k)
	_frame(_pic, f, zoom)


func _frame(s: Sprite2D, focus: Vector2, zoom: float) -> void:
	var view := _view()
	var tex := s.texture.get_size()
	var sc: float = maxf(view.x / tex.x, view.y / tex.y) * zoom
	s.scale = Vector2(sc, sc)
	var size := tex * sc
	var pos := view * 0.5 - (focus - Vector2(0.5, 0.5)) * size
	pos.x = clampf(pos.x, view.x - size.x * 0.5, size.x * 0.5)
	pos.y = clampf(pos.y, view.y - size.y * 0.5, size.y * 0.5)
	s.position = pos


var _log_voice := str(OS.get_cmdline_user_args()).contains("--test=voice")
func _advance() -> void:
	if _log_voice:
		print("ADVANCE after %.2f voiced %.2f still_speaking %s" % [_said, _voiced, audio != null and audio.voice_on()])
	var lines: Array = _panels[_i]["lines"]
	if _line + 1 < lines.size():
		_line += 1
		_show_line()
	else:
		_next_panel()


func _next_panel() -> void:
	_i += 1
	if _i >= _panels.size():
		_finish()
		return
	var p: Dictionary = _panels[_i]
	for b in _boxes:   # the old captions leave with their picture
		if is_instance_valid(b):
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "modulate:a", 0.0, 0.3)
			tw.tween_callback(b.queue_free)
	_boxes.clear()
	_typing = null
	if _stamp_box != null:
		_stamp_box.queue_free()
		_stamp_box = null
	if _old != null:
		_old.queue_free()
	_old = _pic
	_pic = Sprite2D.new()
	_pic.texture = BigTex.get_tex("res://art/cut/%d.jpg" % int(p["img"]))
	_pic.modulate.a = 0.0
	_stage.add_child(_pic)
	_lives.clear()
	_make_live(_pic, int(p["img"]))
	_pan_t = 0.0
	_line = 0
	_shot_taken = false
	var chars := 0
	for l in p["lines"]:
		chars += String(l).length()
	_pan_len = 3.0 + p["lines"].size() * 2.2 + chars * 0.07
	_place_pic()
	var tw := create_tween()
	tw.tween_property(_pic, "modulate:a", 1.0, 0.7 if _i > 0 else 1.4)
	if _i == 0:
		create_tween().tween_property(_black, "color:a", 0.0, 1.2)
	elif sound.is_valid():
		sound.call("page", -6.0)
	_rain_want = float(p.get("rain", 0.0))
	_panel_audio(p)
	if p.has("sound") and sound.is_valid():
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
			if is_inside_tree():
				sound.call(String(p["sound"]), -4.0))
	if p.has("hit"):   # the key picture lands with a low chord and a flash
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			if sound.is_valid():
				sound.call("sting", -3.0)
			_flash.color.a = 0.35
			create_tween().tween_property(_flash, "color:a", 0.0, 0.9))
	if p.has("stamp"):   # where and when: the comic's location caption, on paper like every other box
		var Paper = load("res://paper.gd")
		_stamp_box = Paper.caption(Paper.place_time(String(p["stamp"])).to_upper(), _cap_font(), 20)
		var vs := _view()
		_stamp_box.position = Vector2(vs.x - 48.0 - _stamp_box.size.x, 112.0)   # top right, under SKIP: the captions step down the left and bottom
		_stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stamp_box.modulate.a = 0.0
		add_child(_stamp_box)
		create_tween().tween_property(_stamp_box, "modulate:a", 1.0, 0.5)
	get_tree().create_timer(0.9 if _i == 0 else 0.5, true, false, true).timeout.connect(func() -> void:
		if is_inside_tree() and not _ending and _line == 0 and _typing == null:
			_show_line())


## One caption box: the first of a panel at the top left, the next at the bottom right, like boxes
## stepping down a page. Spoken lines are white, with their quotes.
func _show_line() -> void:
	var text := String(_panels[_i]["lines"][_line])
	if _typing != null:
		_typing.visible_characters = _typing.text.length()
	var speech := text.begins_with("\"")
	var view := _view()
	# a comic caption box sized to its words; a spoken line is a spoken caption, on whiter paper
	var Paper = load("res://paper.gd")
	var box: Control = Paper.caption(text.to_upper(), _cap_font(), 26, minf(view.x * 0.42, 620.0))
	if speech:
		(box.get_node("Drawing") as TextureRect).modulate = Color(1.06, 1.06, 1.1)
	var l: Label
	for c in box.get_children():
		if c is Label:
			l = c
	l.visible_characters = 0
	add_child(box)
	move_child(box, _black.get_index())
	var n := _boxes.size()
	box.modulate.a = 0.0
	_place_box.call_deferred(box, n)
	_boxes.append(box)
	_typing = l
	_type_t = 0.0
	_wait = 0.0
	_voiced = audio.voice(text) if audio != null and not fast else 0.0   # (speech too, in the speaker's own voice, 2026-11-16)
	_said = 0.0
	if _log_voice:
		print("VOICE line '%s' voiced %.2f" % [text.substr(0, 30), _voiced])


## Once the box knows how tall its wrapped text is: where it goes on the page.
func _place_box(box: Control, n: int) -> void:
	if not is_instance_valid(box):
		return
	var view := _view()
	var margin := Vector2(48.0, 44.0)
	const GAP := 16.0
	# Each box has a corner: the panel can name them ("at": "tl", "bl", "tr", "br"), clear of what the
	# picture is about; otherwise the first of a pair goes top left, the next bottom right. Boxes in one
	# corner share its edge and stack with even gaps, read top to bottom: at the top a new box goes
	# under the last one, at the bottom it takes the bottom and lifts the ones before it.
	var corner := _corner(n)
	var x := margin.x if corner.ends_with("l") else view.x - box.size.x - margin.x
	var same: Array = []
	for j in n:
		if j < _boxes.size() and is_instance_valid(_boxes[j]) and _corner(j) == corner:
			same.append(_boxes[j])
	if corner.begins_with("t"):
		var y := margin.y if corner == "tl" else 104.0   # top right starts under the SKIP tape
		for o in same:
			y = maxf(y, (o as Control).position.y + (o as Control).size.y + GAP)
		box.position = Vector2(x, y)
	else:
		box.position = Vector2(x, view.y - box.size.y - margin.y)
		var lift := box.size.y + GAP
		for o in same:
			var c := o as Control
			c.create_tween().tween_property(c, "position:y", c.position.y - lift, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.25)


func _corner(n: int) -> String:
	var at: Array = _panels[_i].get("at", []) if _i < _panels.size() else []
	if n < at.size():
		return String(at[n])
	return "tl" if n % 2 == 0 else "br"


var _cap_f: Font
func _cap_font() -> Font:
	if _cap_f == null:
		_cap_f = load("res://fonts/ComicNeue-BoldItalic.woff")
	return _cap_f


## The panel's sound: its loops, its music, its rain (or none), and its cues on their clock.
func _panel_audio(p: Dictionary) -> void:
	var list: Array = AUDIO.get(scene_id, [])
	var a: Dictionary = list[int(p["_k"])] if int(p["_k"]) < list.size() else {}
	if audio == null:
		return
	audio.bed(a.get("bed", {"lamp_hum": -24.0}))
	audio.music_want = (a.get("music", TUNE) as Array).duplicate()
	if not audio.story or audio.melody != String(PIANO.get(scene_id, "gnossienne")):
		audio.story = true
		audio.melody_from_start(String(PIANO.get(scene_id, "gnossienne")))
	audio.rain_want = float(a.get("rain", p.get("rain", 0.0)))
	audio.indoor = 1.0 if a.get("in", false) else 0.0
	var me := _i
	for c in a.get("cues", []):
		get_tree().create_timer(float(c[0]) * (0.25 if fast else 1.0), true, false, true).timeout.connect(func() -> void:
			if is_inside_tree() and _i == me and not _ending:
				audio.play(String(c[1]), float(c[2]), INF, 0.04))


func _finish() -> void:
	if _ending:
		return
	_ending = true
	if audio != null:   # the street comes back as the page goes dark
		audio.bed({})
		audio.story = false
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		if done.is_valid():
			done.call()
		queue_free())
