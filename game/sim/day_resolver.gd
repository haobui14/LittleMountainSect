class_name DayResolver
extends RefCounted
## Runs one day of the rules, in a fixed order:
##   1. the morning's facts, then departures   2. training   3. breakthroughs
##   4. study   5. work   6. rest and injuries   7. missions return
##   8. food (and the Kitchen's meals)   9. drift: Mood, Loyalty, side effects,
##   homecomings   10. limits, then the day number goes up, and tomorrow's
##   gate candidate and surprise event are rolled.
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
	# 1. What happened this morning (an event, a recruit, pills) comes first.
	for fact in sect.pending_facts:
		report.facts.append(fact)
	sect.pending_facts.clear()

	# Teams leave next, so they skip the home tasks.
	for entry in plan.missions:
		MissionResolver.depart(sect, String(entry["mission"]), entry["team"], report)

	var by_task := {"train": [], "work": [], "rest": [], "study": [], "breakthrough": []}
	for d in sect.disciples:
		if sect.is_away(d.id):
			continue
		var task := "rest" if d.is_injured() else String(plan.tasks.get(d.id, "rest"))
		if not d.is_injured():
			sect.last_tasks[d.id] = task
		by_task[task if by_task.has(task) else "rest"].append(d)

	# 2. Training.
	for d: Disciple in by_task["train"]:
		var gain := mini(BuildingRules.training_gain(sect, d), Balance.PROGRESS_MAX - d.progress)
		d.progress += gain
		d.mood += Balance.TRAIN_MOOD
		report.add("trained", {"disciple": d.id, "gain": gain, "ready": CultivationRules.can_break_through(d)})

	# 3. Breakthroughs.
	for d: Disciple in by_task["breakthrough"]:
		CultivationRules.attempt(sect, d, report)

	# 4. Study in the Library.
	for d: Disciple in by_task["study"]:
		CultivationRules.study(sect, d, report)

	# 5. Work in the Spirit Field (or foraging on the slopes before it is built).
	var workers: Array = by_task["work"]
	if not workers.is_empty():
		var food := 0
		var herbs := 0
		for d: Disciple in workers:
			food += BuildingRules.worker_food(sect, d)
			herbs += BuildingRules.worker_herbs(sect, d)
			d.mood += Balance.WORK_MOOD
		food = sect.add_resource("food", food)
		herbs = sect.add_resource("herbs", herbs)
		report.add("worked", {"disciples": workers.map(func(d: Disciple) -> String: return d.id), "food": food, "herbs": herbs})

	# 6. Rest, and injuries heal.
	for d: Disciple in by_task["rest"]:
		var mood_before := d.mood
		d.mood += BuildingRules.rest_mood(sect, d)
		d.clamp_values()
		if d.is_injured():
			for effect in d.effects:
				if effect.kind == "injured":
					effect.days_left -= BuildingRules.heal_per_day(sect)
			d.clamp_values()
			if not d.is_injured():
				report.add("healed", {"disciple": d.id})
		report.add("rested", {"disciple": d.id, "mood": d.mood - mood_before})

	# 7. Teams due home tonight return.
	var still_away: Array[ActiveMission] = []
	for m in sect.missions:
		if m.return_day <= sect.day:
			MissionResolver.complete(sect, m, report)
		else:
			still_away.append(m)
	sect.missions = still_away

	# 8. Everyone at home eats; teams on the road (and the lost) feed
	# themselves. With a Kitchen, a little more Food makes better meals.
	var home: Array[Disciple] = []
	home.assign(sect.disciples.filter(func(d: Disciple) -> bool: return not sect.is_away(d.id)))
	var need := home.size() * Balance.FOOD_PER_DISCIPLE
	var eaten := -sect.add_resource("food", -need)
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
	else:
		var extra := BuildingRules.kitchen_food(sect, home.size())
		if extra > 0 and int(sect.resources["food"]) >= extra:
			eaten += -sect.add_resource("food", -extra)
			for d in home:
				d.mood += BuildingRules.kitchen_mood(sect)
	if eaten > 0:
		report.add("ate", {"food": eaten})

	# 9. Drift: high spirits settle, Mood moves Loyalty, side effects wear off,
	# and the lost and the departed come home on their day. Tomorrow's chats
	# start fresh.
	for d in sect.disciples:
		if d.mood > Balance.MOOD_DRIFT_ABOVE:
			d.mood -= 1
		if d.mood >= Balance.LOYALTY_UP_MOOD:
			d.loyalty += Balance.LOYALTY_STEP
		elif d.mood <= Balance.LOYALTY_DOWN_MOOD:
			d.loyalty -= Balance.LOYALTY_STEP
		CultivationRules.tick_effects(d, report)
		d.talked_today = false
		d.chat_mood_today = 0
		# A wish from chat lasts for the next day's plan, then fades.
		if d.wants_day < sect.day:
			d.wants = ""
	MissionResolver.bring_home(sect, report)

	# 10. Limits, then tomorrow.
	for d in sect.disciples:
		d.clamp_values()
	for name in Balance.RESOURCES:
		report.resource_changes[name] = int(sect.resources[name]) - int(before[name])
	sect.last_report = report
	sect.brews_today = 0
	sect.day += 1
	Decisions.expire(sect)
	Recruiting.roll(sect)
	EventRules.roll(sect)
	return report
