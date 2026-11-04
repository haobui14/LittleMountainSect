class_name DayResolver
extends RefCounted
## Runs one day of the rules, in a fixed order:
##   1. departures   2. training   3. work   4. rest and injuries
##   5. missions return   6. food upkeep   7. Mood and Loyalty drift
##   8. limits, then the day number goes up.
## The same sect and plan always give the same result.


## Applies [param plan] to [param sect] and returns what happened. Returns
## null and changes nothing when the plan is invalid (see DayPlan.validate).
static func resolve(sect: Sect, plan: DayPlan) -> DayReport:
	var errors := plan.validate(sect)
	if not errors.is_empty():
		push_error("Invalid day plan: %s" % [errors])
		return null

	var before := sect.resources.duplicate()
	var report := DayReport.new(sect.day)

	# 1. Teams leave first, so they skip the home tasks.
	for entry in plan.missions:
		MissionResolver.depart(sect, String(entry["mission"]), entry["team"], report)

	var trainers: Array[Disciple] = []
	var workers: Array[Disciple] = []
	var resters: Array[Disciple] = []
	for d in sect.disciples:
		if sect.is_away(d.id):
			continue
		var task := "rest" if d.is_injured() else String(plan.tasks.get(d.id, "rest"))
		if not d.is_injured():
			sect.last_tasks[d.id] = task
		match task:
			"train":
				trainers.append(d)
			"work":
				workers.append(d)
			_:
				resters.append(d)

	# 2. Training.
	for d in trainers:
		var gain := mini(BuildingRules.training_gain(sect, d), Balance.PROGRESS_MAX - d.progress)
		d.progress += gain
		d.mood += Balance.TRAIN_MOOD
		report.add("trained", {"disciple": d.id, "gain": gain, "ready": d.progress >= Balance.PROGRESS_MAX})

	# 3. Work in the Spirit Field (or foraging on the slopes before it is built).
	if not workers.is_empty():
		var food := sect.add_resource("food", BuildingRules.work_food(sect) * workers.size())
		var herbs := sect.add_resource("herbs", BuildingRules.work_herbs(sect) * workers.size())
		for d in workers:
			d.mood += Balance.WORK_MOOD
		report.add("worked", {"disciples": workers.map(func(d: Disciple) -> String: return d.id), "food": food, "herbs": herbs})

	# 4. Rest, and injuries heal.
	for d in resters:
		var mood_before := d.mood
		d.mood += BuildingRules.rest_mood(sect)
		d.clamp_values()
		if d.is_injured():
			for effect in d.effects:
				if effect.kind == "injured":
					effect.days_left -= BuildingRules.heal_per_day(sect)
			d.clamp_values()
			if not d.is_injured():
				report.add("healed", {"disciple": d.id})
		report.add("rested", {"disciple": d.id, "mood": d.mood - mood_before})

	# 5. Teams due home tonight return.
	var still_away: Array[ActiveMission] = []
	for m in sect.missions:
		if m.return_day <= sect.day:
			MissionResolver.complete(sect, m, report)
		else:
			still_away.append(m)
	sect.missions = still_away

	# 6. Everyone at home eats. Teams on the road feed themselves.
	var home: Array[Disciple] = []
	home.assign(sect.disciples.filter(func(d: Disciple) -> bool: return not sect.is_away(d.id)))
	var need := home.size() * Balance.FOOD_PER_DISCIPLE
	var eaten := -sect.add_resource("food", -need)
	if eaten > 0:
		report.add("ate", {"food": eaten})
	@warning_ignore("integer_division")
	var unfed := (need - eaten) / Balance.FOOD_PER_DISCIPLE
	if unfed > 0:
		var hungry: Array[String] = []
		var pool := home.duplicate()
		for i in unfed:
			var d: Disciple = pool.pop_at(sect.rng.randi_range(0, pool.size() - 1))
			d.mood += Balance.HUNGRY_MOOD
			hungry.append(d.id)
		report.add("hungry", {"disciples": hungry})

	# 7. Drift: high spirits settle, and Mood moves Loyalty. Tomorrow's chats
	# start fresh.
	for d in sect.disciples:
		if d.mood > Balance.MOOD_DRIFT_ABOVE:
			d.mood -= 1
		if d.mood >= Balance.LOYALTY_UP_MOOD:
			d.loyalty += Balance.LOYALTY_STEP
		elif d.mood <= Balance.LOYALTY_DOWN_MOOD:
			d.loyalty -= Balance.LOYALTY_STEP
		d.talked_today = false

	# 8. Limits.
	for d in sect.disciples:
		d.clamp_values()
	for name in Balance.RESOURCES:
		report.resource_changes[name] = int(sect.resources[name]) - int(before[name])
	sect.last_report = report
	sect.day += 1
	return report
