extends SceneTree
## Balance sim: plays many seeds headless with automatic players and reports
## resource curves, mission results and building timing. Exits with code 1 when
## any run breaks a rule of the game:
##   - a resource is negative or a disciple's value is out of range;
##   - a day plan is rejected;
##   - more disciples than the Main Hall holds, more Elders than its level,
##     or pills out of range;
##   - a rival's Attitude or Trust, or the sect's land, out of range (M6);
##   - a lost or departed disciple stays away more than AWAY_LIMIT days, or
##     a traveller more than TRAVEL_LIMIT days;
##   - a war lasts more than WAR_LIMIT days after it is declared, a season
##     ends without its tournament, or a player leaves a morning decision
##     open (the day plan would wait for it forever);
##   - with the sensible player, Food stays at 0 for 5 days in a row, no
##     disciple can be planned for 5 days in a row (a softlock), or someone
##     stays ready to break through for READY_LIMIT days.
##
## Run from the repo root:
##   godot --headless --path game -s res://tools/balance_sim.gd -- --seeds 100 --days 60
## Options: --seeds N, --days N, --players sensible,random, --first-seed N,
##          --out PATH (also write the Markdown report to PATH)

const STREAK_LIMIT := 5
const AWAY_LIMIT := 20
const TRAVEL_LIMIT := 40
const WAR_LIMIT := 5
const READY_LIMIT := 45
const REPORT_DAYS: Array[int] = [1, 5, 10, 20, 30, 45, 60, 90, 120]
## Facts counted across all seeds, for the report.
const COUNTED: Array[String] = [
	"breakthrough", "breakthrough_failed", "learned", "recruited", "event", "lost", "left", "found_item", "rank_up",
]
## The world's facts (M6), counted for their own table.
const WORLD_COUNTED: Array[String] = [
	"tournament", "tournament_skipped", "gift", "trade", "alliance", "alliance_ended", "betrayal",
	"war_declared", "war_result", "peace", "promoted", "ascended", "ascension_failed", "travel_left", "letter",
]


func _init() -> void:
	var options := _options(OS.get_cmdline_user_args())
	var lines: Array[String] = []
	var failures := 0
	lines.append("# Balance sim")
	lines.append("")
	lines.append("%d seeds × %d days, starting at seed %d." % [options["seeds"], options["days"], options["first_seed"]])
	for player: String in options["players"]:
		var result := _run_player(player, options)
		failures += int(result["failures"].size())
		lines.append_array(_report(player, result, options))
	lines.append("")
	lines.append("**Result: %s**" % ("PASS" if failures == 0 else "FAIL (%d problems)" % failures))
	var text := "\n".join(lines)
	print(text)
	if options["out"] != "":
		_write(options["out"], text + "\n")
	quit(0 if failures == 0 else 1)


func _options(args: PackedStringArray) -> Dictionary:
	var options := {"seeds": 100, "days": 60, "first_seed": 1, "players": ["sensible", "random"], "out": ""}
	var i := 0
	while i < args.size():
		var value := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seeds":
				options["seeds"] = value.to_int()
			"--days":
				options["days"] = value.to_int()
			"--first-seed":
				options["first_seed"] = value.to_int()
			"--players":
				options["players"] = Array(value.split(","))
			"--out":
				options["out"] = value
		i += 2
	return options


func _run_player(player: String, options: Dictionary) -> Dictionary:
	var days: int = options["days"]
	var series := {}  # metric -> day -> Array[float] across seeds
	var tiers := {}  # mission -> tier -> count
	var first_build := {}  # "building:level" -> Array[int] days
	var counts := {}  # fact type -> count
	var places := {}  # season number -> Array[int] of places (0: sat out)
	var wars_won := 0
	var failures: Array[String] = []
	for n in options["seeds"]:
		var seed_value: int = options["first_seed"] + n
		var sect := NewGame.create(seed_value)
		var policy_rng := SimRng.new(seed_value * 7919 + 1)
		var food_zero := 0
		var nobody_free := 0
		var away := {}  # disciple id -> days lost or left in a row
		var ready := {}  # disciple id -> days ready at home in a row
		var reached := {}  # "building:level" -> first day, for this seed
		var tournaments := 0
		for day in days:
			var plan := SimPlayers.sensible(sect, policy_rng) if player == "sensible" else SimPlayers.random(sect, policy_rng)
			var open := World.pending(sect).filter(func(p: String) -> bool: return p != "event")
			if not open.is_empty():
				failures.append("seed %d day %d: left open %s" % [seed_value, sect.day, open])
				break
			_note_buildings(sect, reached)
			var report := DayResolver.resolve(sect, plan)
			if report == null:
				failures.append("seed %d day %d: plan rejected %s" % [seed_value, sect.day, plan.validate(sect)])
				break
			for fact in report.of_type("mission_returned"):
				var by_tier: Dictionary = tiers.get_or_add(fact["mission"], {})
				by_tier[fact["tier"]] = int(by_tier.get(fact["tier"], 0)) + 1
			for fact in report.facts:
				if fact["type"] in COUNTED or fact["type"] in WORLD_COUNTED:
					counts[fact["type"]] = int(counts.get(fact["type"], 0)) + 1
				if fact["type"] in ["tournament", "tournament_skipped"]:
					tournaments += 1
					var list: Array = places.get_or_add(Seasons.number(report.day), [])
					list.append(int(fact.get("place", 0)))
				if fact["type"] == "war_result" and fact["won"]:
					wars_won += 1
			if player == "random":
				SimPlayers.random_ai(sect, policy_rng)
			var broken := _broken_values(sect)
			if broken != "":
				failures.append("seed %d day %d: %s" % [seed_value, report.day, broken])
				break
			food_zero = food_zero + 1 if int(sect.resources["food"]) == 0 else 0
			nobody_free = nobody_free + 1 if sect.available_disciples().is_empty() else 0
			if player == "sensible" and food_zero >= STREAK_LIMIT:
				failures.append("seed %d day %d: Food at 0 for %d days" % [seed_value, report.day, food_zero])
				break
			if player == "sensible" and nobody_free >= STREAK_LIMIT:
				failures.append("seed %d day %d: nobody free for %d days" % [seed_value, report.day, nobody_free])
				break
			var stuck := _stuck(sect, away, ready, player == "sensible")
			if stuck != "":
				failures.append("seed %d day %d: %s" % [seed_value, report.day, stuck])
				break
			_record(series, sect, report.day)
		@warning_ignore("integer_division")
		var seasons: int = days / Balance.SEASON_DAYS
		if failures.is_empty() and tournaments != seasons:
			failures.append("seed %d: %d tournaments in %d seasons" % [seed_value, tournaments, seasons])
		for key: String in reached:
			var list: Array = first_build.get_or_add(key, [])
			list.append(reached[key])
	return {
		"series": series, "tiers": tiers, "first_build": first_build, "counts": counts, "failures": failures,
		"places": places, "wars_won": wars_won,
	}


## Disciples away too long, or (for the sensible player) ready to break
## through for too long without trying.
func _stuck(sect: Sect, away: Dictionary, ready: Dictionary, sensible: bool) -> String:
	for d in sect.disciples:
		away[d.id] = int(away.get(d.id, 0)) + 1 if d.status in ["lost", "left", "travel"] else 0
		var limit := TRAVEL_LIMIT if d.status == "travel" else AWAY_LIMIT
		if int(away[d.id]) > limit:
			return "%s %s for %d days" % [d.id, d.status, away[d.id]]
		var waiting := CultivationRules.can_break_through(d) and not sect.is_away(d.id) and not d.is_elder()
		ready[d.id] = int(ready.get(d.id, 0)) + 1 if waiting else 0
		if sensible and int(ready[d.id]) > READY_LIMIT:
			return "%s ready to break through for %d days" % [d.id, ready[d.id]]
	return ""


func _broken_values(sect: Sect) -> String:
	for name in Balance.RESOURCES:
		if int(sect.resources[name]) < 0:
			return "%s is negative" % name
	if sect.member_count() > sect.disciple_limit():
		return "%d disciples, the Main Hall holds %d" % [sect.member_count(), sect.disciple_limit()]
	if sect.elder_count() > Generations.max_elders(sect):
		return "%d Elders with Main Hall level %d" % [sect.elder_count(), sect.level("main_hall")]
	for rival in RivalCatalog.ids():
		var a := Rivals.attitude(sect, rival)
		var t := Rivals.trust(sect, rival)
		if a < Balance.ATTITUDE_MIN or a > Balance.ATTITUDE_MAX or t < Balance.TRUST_MIN or t > Balance.TRUST_MAX:
			return "%s attitude %d trust %d" % [rival, a, t]
	if sect.land < Balance.LAND_MIN or sect.land > Balance.LAND_MAX:
		return "%d hills" % sect.land
	if not sect.war.is_empty() and sect.day - int(sect.war["declared_day"]) > WAR_LIMIT:
		return "a war with %s declared on day %d" % [sect.war["rival"], sect.war["declared_day"]]
	for pill in Balance.PILLS:
		if sect.item(pill) < 0 or sect.item(pill) > Balance.PILL_MAX:
			return "%d %s" % [sect.item(pill), pill]
	if not sect.event.is_empty():
		for id in sect.event["disciples"]:
			if sect.disciple(String(id)) == null:
				return "the event names %s" % id
	for d in sect.disciples:
		if d.technique < 0 or d.technique > Balance.TECHNIQUE_MAX or d.study < 0 or d.study > Balance.STUDY_MAX:
			return "%s technique %d study %d" % [d.id, d.technique, d.study]
		if d.mood < Balance.MOOD_MIN or d.mood > Balance.MOOD_MAX:
			return "%s mood %d" % [d.id, d.mood]
		if d.loyalty < Balance.LOYALTY_MIN or d.loyalty > Balance.LOYALTY_MAX:
			return "%s loyalty %d" % [d.id, d.loyalty]
		if d.progress < 0 or d.progress > Balance.PROGRESS_MAX:
			return "%s progress %d" % [d.id, d.progress]
		if absi(d.chat_mood_today) > Balance.CHAT_MOOD_PER_DAY:
			return "%s chat mood %d" % [d.id, d.chat_mood_today]
	for pair: String in sect.relationships:
		var score := int(sect.relationships[pair])
		if score < Balance.RELATIONSHIP_MIN or score > Balance.RELATIONSHIP_MAX:
			return "%s relationship %d" % [pair, score]
	return ""


func _record(series: Dictionary, sect: Sect, day: int) -> void:
	var mood := 0.0
	var loyalty := 0.0
	var progress := 0.0
	var realm := 0.0
	for d in sect.disciples:
		mood += d.mood
		loyalty += d.loyalty
		progress += d.progress
		realm += d.realm_index()
	var n := float(sect.disciples.size())
	var values := {
		"stones": sect.resources["stones"],
		"food": sect.resources["food"],
		"herbs": sect.resources["herbs"],
		"reputation": sect.resources["reputation"],
		"mood": mood / n,
		"loyalty": loyalty / n,
		"progress": progress / n,
		"realm": realm / n,
		"disciples": n,
		"rank": sect.level("main_hall"),
		"land": sect.land,
		"elders": sect.elder_count(),
	}
	for metric: String in values:
		var by_day: Dictionary = series.get_or_add(metric, {})
		var list: Array = by_day.get_or_add(day, [])
		list.append(float(values[metric]))


## Remembers the first day each building level exists (upgrades happen while
## planning, so the level counts for that day).
func _note_buildings(sect: Sect, reached: Dictionary) -> void:
	for building in Balance.BUILDINGS_IN_PLAY:
		for level in range(1, sect.level(building) + 1):
			var key := "%s:%d" % [building, level]
			if not reached.has(key):
				reached[key] = sect.day


func _percentile(values: Array, p: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(ceili(p / 100.0 * sorted.size()) - 1, 0, sorted.size() - 1)])


func _report(player: String, result: Dictionary, options: Dictionary) -> Array[String]:
	var lines: Array[String] = ["", "## Player: %s" % player, ""]
	var failures: Array = result["failures"]
	if failures.is_empty():
		lines.append("No problems.")
	else:
		lines.append("**%d problems**, first ones:" % failures.size())
		for f in failures.slice(0, 10):
			lines.append("- %s" % f)
	lines.append("")
	lines.append("Median (10th–90th percentile) across seeds, at the end of each day:")
	lines.append("")
	var metrics := ["stones", "food", "herbs", "reputation", "mood", "loyalty", "progress", "realm", "disciples", "rank"]
	lines.append("| Day | " + " | ".join(metrics) + " |")
	lines.append("|---" .repeat(metrics.size() + 1) + "|")
	var series: Dictionary = result["series"]
	for day in REPORT_DAYS:
		if day > int(options["days"]) or not series.get("stones", {}).has(day):
			continue
		var cells: Array[String] = [str(day)]
		for metric: String in metrics:
			var values: Array = series[metric][day]
			var digits := 0 if metric in ["stones", "food", "herbs", "reputation"] else 1
			cells.append("%s (%s–%s)" % [
				String.num(_percentile(values, 50), digits),
				String.num(_percentile(values, 10), digits),
				String.num(_percentile(values, 90), digits),
			])
		lines.append("| " + " | ".join(cells) + " |")
	lines.append("")
	lines.append("Realm is the average realm (0 Qi Refining to 3 Nascent Soul); rank is the Main Hall level.")
	lines.append("")
	lines.append("Events across all seeds (per seed in brackets):")
	lines.append("")
	var counts: Dictionary = result["counts"]
	var seeds := maxi(1, int(options["seeds"]))
	var parts: Array[String] = []
	for type in COUNTED:
		parts.append("%s %d (%.1f)" % [type, int(counts.get(type, 0)), float(counts.get(type, 0)) / seeds])
	lines.append(", ".join(parts) + ".")
	lines.append("")
	lines.append_array(_world_report(result, options))
	lines.append("")
	lines.append("Mission results:")
	lines.append("")
	lines.append("| Mission | " + " | ".join(Balance.TIERS) + " |")
	lines.append("|---" .repeat(Balance.TIERS.size() + 1) + "|")
	var tiers: Dictionary = result["tiers"]
	for mission: String in tiers:
		var total := 0
		for tier: String in tiers[mission]:
			total += int(tiers[mission][tier])
		var cells: Array[String] = [mission]
		for tier in Balance.TIERS:
			cells.append("%d%%" % roundi(100.0 * int(tiers[mission].get(tier, 0)) / maxi(1, total)))
		lines.append("| " + " | ".join(cells) + " |")
	lines.append("")
	lines.append("Buildings: share of seeds that reach each level, and the median day:")
	lines.append("")
	lines.append("| Building | Level 1 | Level 2 | Level 3 |")
	lines.append("|---|---|---|---|")
	var first_build: Dictionary = result["first_build"]
	for building in Balance.BUILDINGS_IN_PLAY:
		var cells: Array[String] = [building]
		for level in range(1, Balance.MAX_LEVEL + 1):
			var days: Array = first_build.get("%s:%d" % [building, level], [])
			if days.is_empty():
				cells.append("—")
			else:
				cells.append("%d%%, day %d" % [roundi(100.0 * days.size() / int(options["seeds"])), roundi(_percentile(days, 50))])
		lines.append("| " + " | ".join(cells) + " |")
	return lines


## The world (M6): tournament places by season, the world's events, and the
## land and Elders at the end.
func _world_report(result: Dictionary, options: Dictionary) -> Array[String]:
	var seeds := maxi(1, int(options["seeds"]))
	var lines: Array[String] = ["The world (M6):", ""]
	lines.append("| Season | 1st | 2nd | 3rd | 4th | Sat out |")
	lines.append("|---|---|---|---|---|---|")
	var places: Dictionary = result["places"]
	var numbers := places.keys()
	numbers.sort()
	for number: int in numbers:
		var list: Array = places[number]
		var cells: Array[String] = [str(number)]
		for place in [1, 2, 3, 4, 0]:
			cells.append("%d%%" % roundi(100.0 * list.count(place) / maxi(1, list.size())))
		lines.append("| " + " | ".join(cells) + " |")
	lines.append("")
	var counts: Dictionary = result["counts"]
	var parts: Array[String] = []
	for type in WORLD_COUNTED:
		parts.append("%s %d (%.2f)" % [type, int(counts.get(type, 0)), float(counts.get(type, 0)) / seeds])
	lines.append("World events across all seeds (per seed in brackets): " + ", ".join(parts) + ".")
	var battles := int(counts.get("war_result", 0))
	lines.append("")
	lines.append("Battles won: %d of %d." % [int(result["wars_won"]), battles])
	var series: Dictionary = result["series"]
	var last := int(options["days"])
	if series.has("land") and series["land"].has(last):
		lines.append("")
		lines.append("On day %d: land %s hills (10th–90th %s–%s), Elders %s (90th %s)." % [
			last,
			String.num(_percentile(series["land"][last], 50), 0),
			String.num(_percentile(series["land"][last], 10), 0),
			String.num(_percentile(series["land"][last], 90), 0),
			String.num(_percentile(series["elders"][last], 50), 0),
			String.num(_percentile(series["elders"][last], 90), 0),
		])
	return lines


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	file.store_string(text)
