extends GutTest
## M4 rules: relationships, the disciples' own decisions, and what chat and
## evening replies may change. Code decides: every value is checked again here,
## even though the server already checked it.


func _reply(overrides: Dictionary = {}) -> Dictionary:
	var reply := {"safety": "ok", "mood_change": 0, "wants_action": null}
	reply.merge(overrides, true)
	return reply


# Relationships ----------------------------------------------------------------

func test_a_pair_has_one_score_whichever_way_round() -> void:
	var sect := SimFixtures.sect()
	assert_eq(Relationships.key("b", "a"), "a|b")
	Relationships.change(sect, "b", "a", 1)
	assert_eq(Relationships.score(sect, "a", "b"), 1)


func test_relationships_move_by_small_steps_within_limits() -> void:
	var sect := SimFixtures.sect()
	assert_eq(Relationships.change(sect, "a", "b", 9), Balance.RELATIONSHIP_STEP)
	sect.relationships[Relationships.key("a", "c")] = Balance.RELATIONSHIP_MAX - 1
	assert_eq(Relationships.change(sect, "a", "c", 2), 1)
	assert_eq(Relationships.change(sect, "a", "a", 2), 0, "nobody befriends themself")
	assert_eq(Relationships.change(sect, "a", "ghost", 2), 0)
	Relationships.change(sect, "a", "b", -2)
	assert_false(sect.relationships.has("a|b"), "a pair back at 0 is forgotten")


func test_relationship_pairs_list_only_current_disciples() -> void:
	var sect := SimFixtures.sect()
	sect.relationships = {"b|c": -3, "a|b": 4, "a|gone": 7}
	assert_eq(Relationships.pairs(sect), [{"a": "a", "b": "b", "score": 4}, {"a": "b", "b": "c", "score": -3}])


# Decisions ------------------------------------------------------------------------

func _decide(sect: Sect, id: String, action: String) -> void:
	EveningRules.apply(sect, {"decisions": [{"disciple_id": id, "action": action, "reason": "Because."}]})


func test_a_decision_becomes_tomorrows_default() -> void:
	var sect := SimFixtures.sect()
	sect.last_tasks = {"a": "train", "b": "train", "c": "train"}
	_decide(sect, "a", "cook")
	assert_eq(DayPlan.defaults(sect).tasks, {"a": "work", "b": "train", "c": "train"})


func test_overruling_a_decision_costs_mood_once() -> void:
	var sect := SimFixtures.sect()
	_decide(sect, "a", "rest")
	assert_eq(Decisions.overrule(sect, "a"), Balance.OVERRULE_MOOD)
	assert_eq(Decisions.overrule(sect, "a"), 0, "only the first time each day")
	assert_eq(sect.disciple("a").mood, Balance.OVERRULE_MOOD)
	assert_eq(Decisions.overrule(sect, "b"), 0, "b made no decision")


func test_decisions_last_one_day() -> void:
	var sect := SimFixtures.sect()
	_decide(sect, "a", "study")
	assert_eq(Decisions.task_for_today(sect, "a"), "train")
	DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_false(sect.decisions.has("a"))
	assert_eq(Decisions.task_for_today(sect, "a"), "")


func test_an_injured_disciple_cannot_follow_a_working_decision() -> void:
	var sect := SimFixtures.sect()
	sect.decisions["a"] = {"action": "cook", "task": "work", "reason": "", "day": sect.day, "overruled": false}
	sect.disciple("a").injure(2)
	assert_eq(Decisions.task_for_today(sect, "a"), "")
	assert_eq(DayPlan.defaults(sect).tasks["a"], "rest")


# Chat -------------------------------------------------------------------------------

func test_the_first_chat_of_the_day_gives_the_talk_bonus() -> void:
	var sect := SimFixtures.sect()
	var d := sect.disciple("a")
	assert_eq(ChatRules.apply(sect, d, _reply()), {"bonus": Balance.TALK_MOOD, "mood": 0})
	assert_eq(ChatRules.apply(sect, d, _reply()), {"bonus": 0, "mood": 0})


func test_chat_mood_is_capped_per_reply_and_per_day() -> void:
	var sect := SimFixtures.sect()
	var d := sect.disciple("a")
	d.talked_today = true
	assert_eq(ChatRules.apply(sect, d, _reply({"mood_change": 9}))["mood"], 2)
	assert_eq(ChatRules.apply(sect, d, _reply({"mood_change": 1}))["mood"], 0, "the day's +2 is used up")
	assert_eq(ChatRules.apply(sect, d, _reply({"mood_change": -9}))["mood"], -2)
	assert_eq(ChatRules.apply(sect, d, _reply({"mood_change": -2}))["mood"], -2)
	assert_eq(ChatRules.apply(sect, d, _reply({"mood_change": -2}))["mood"], 0, "and down to -2 net")
	assert_eq(d.mood, -2)
	DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(d.chat_mood_today, 0, "a new day, a new allowance")


func test_distress_and_boundary_replies_change_nothing() -> void:
	var sect := SimFixtures.sect()
	var d := sect.disciple("a")
	d.talked_today = true
	for safety in ["distress", "boundary"]:
		assert_eq(ChatRules.apply(sect, d, _reply({"safety": safety, "mood_change": 2, "wants_action": "hide"}))["mood"], 0)
	assert_eq(d.wants, "")


func test_a_chat_wish_is_a_hint_for_the_next_plan_only() -> void:
	var sect := SimFixtures.sect()
	var d := sect.disciple("a")
	ChatRules.apply(sect, d, _reply({"wants_action": "cook"}))
	ChatRules.apply(sect, sect.disciple("b"), _reply({"wants_action": "explore"}))
	assert_eq(sect.disciple("b").wants, "", "explore can't be planned yet")
	DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(ChatRules.wished_task(sect, d), "work", "shown on the next plan")
	DayResolver.resolve(sect, DayPlan.defaults(sect))
	assert_eq(ChatRules.wished_task(sect, d), "", "then it fades")


func test_chat_requests_match_the_gateway() -> void:
	var sect := SimFixtures.sect()
	var recent := []
	for i in 9:
		recent.append({"from": "player", "text": str(i)})
	var body := ChatRules.request(sect.disciple("a"), recent, "  " + "x".repeat(400), "vi")
	assert_eq(body["kind"], "chat")
	assert_eq(body["disciple"]["name"], "Thử a")
	assert_eq(body["recent"].size(), 6)
	assert_eq(body["message"].length(), 280)
	assert_eq(ChatRules.request(null, [], "Hi", "en"), {"kind": "elder", "locale": "en", "recent": [], "message": "Hi"})


# Evening ----------------------------------------------------------------------------

func test_allowed_actions_follow_the_rules() -> void:
	var sect := SimFixtures.sect()
	assert_eq(EveningRules.allowed_actions(sect, sect.disciple("a")), ["train", "rest", "meditate", "cook", "tend_field", "study", "hide"])
	sect.disciple("b").injure(2)
	assert_eq(EveningRules.allowed_actions(sect, sect.disciple("b")), ["rest", "hide"])
	var away := ActiveMission.new()
	away.mission = "hunt_monster"
	away.team.assign(["c"])
	away.return_day = 9
	sect.missions.append(away)
	assert_eq(EveningRules.allowed_actions(sect, sect.disciple("c")), [] as Array[String])


func test_evening_replies_apply_only_what_the_rules_allow() -> void:
	var sect := SimFixtures.sect()
	sect.disciple("c").injure(2)
	var applied := EveningRules.apply(sect, {
		"decisions": [
			{"disciple_id": "c", "action": "cook", "reason": "injured, so not allowed"},
			{"disciple_id": "a", "action": "explore", "reason": "can't be planned"},
			{"disciple_id": "a", "action": "rest", "reason": "x".repeat(400)},
			{"disciple_id": "a", "action": "train", "reason": "a second one for a"},
			{"disciple_id": "c", "action": "hide", "reason": "allowed"},
			{"disciple_id": "b", "action": "train", "reason": "third decision"},
		],
		"relationship_changes": [
			{"from": "a", "to": "b", "change": 6, "reason": "big"},
			{"from": "b", "to": "a", "change": -1, "reason": "same pair"},
			{"from": "a", "to": "ghost", "change": 1, "reason": "unknown"},
			{"from": "a", "to": "c", "change": 0, "reason": "nothing"},
			{"from": "b", "to": "c", "change": -1, "reason": "spat"},
			{"from": "a", "to": "c", "change": 1, "reason": "made up"},
			{"from": "c", "to": "b", "change": 1, "reason": "a fourth"},
		],
	})
	assert_eq(applied["decisions"].map(func(d: Dictionary) -> String: return d["disciple"] + ":" + d["action"]), ["a:rest", "c:hide"])
	assert_eq(sect.decisions["a"]["reason"].length(), Balance.REASON_CHARS)
	assert_eq(applied["relationships"].map(func(r: Dictionary) -> int: return r["change"]), [2, -1, 1])
	assert_eq(sect.relationships, {"a|b": 2, "b|c": -1, "a|c": 1})


func test_the_evening_request_uses_ids_and_numbers_only() -> void:
	var sect := NewGame.create(77)
	var plan := DayPlan.defaults(sect)
	plan.add_mission("gather_herbs", [sect.disciples[0].id] as Array[String])
	var report := DayResolver.resolve(sect, plan)
	var body := EveningRules.request(sect, report, "vi")
	assert_eq(body["kind"], "evening")
	assert_eq(body["game_day"], 1)
	assert_eq(body["sect"]["rank"], "unknown_mountain")
	assert_eq(body["disciples"].size(), 3)
	assert_eq(body["facts"], report.facts)
	for fact: Dictionary in body["facts"]:
		for value in fact.values():
			assert_true(typeof(value) in [TYPE_STRING, TYPE_INT, TYPE_BOOL, TYPE_ARRAY, TYPE_DICTIONARY], str(fact))


# Saves --------------------------------------------------------------------------------

func test_version_1_saves_load_as_version_2() -> void:
	var sect := NewGame.create(3)
	var old := sect.to_dict()
	old["version"] = 1
	for key in ["relationships", "decisions", "revision"]:
		old.erase(key)
	for d: Dictionary in old["disciples"]:
		for key in ["chat_mood_today", "wants", "wants_day"]:
			d.erase(key)
	var migrated := SaveMigration.migrate(JSON.parse_string(JSON.stringify(old)))
	assert_true(migrated["ok"])
	var loaded := Sect.from_dict(migrated["data"])
	assert_eq(loaded.relationships, {})
	assert_eq(loaded.revision, 0)
	assert_eq(loaded.disciples[0].wants, "")
	assert_eq(loaded.disciples.size(), 3)


func test_relationships_and_decisions_survive_a_save() -> void:
	var sect := SimFixtures.sect()
	_decide(sect, "a", "cook")
	Relationships.change(sect, "a", "b", 2)
	sect.revision = 7
	var copy := Sect.from_dict(SaveMigration.migrate(JSON.parse_string(JSON.stringify(sect.to_dict())))["data"])
	assert_eq(copy.to_dict(), sect.to_dict())
