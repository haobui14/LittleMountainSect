extends GutTest
## Day plans: what is allowed, and the defaults that make a day quick to plan.


func _team(ids: Array) -> Array[String]:
	var team: Array[String] = []
	team.assign(ids)
	return team


func test_a_simple_plan_is_valid() -> void:
	var sect := SimFixtures.sect()
	var plan := SimFixtures.plan_all(sect, "train")
	assert_eq(plan.validate(sect), [] as Array[String])


func test_injured_disciples_can_only_rest() -> void:
	var sect := SimFixtures.sect()
	sect.disciple("a").injure(2)
	var plan := DayPlan.new()
	plan.tasks["a"] = "work"
	assert_eq(plan.validate(sect), ["injured_must_rest:a"] as Array[String])
	plan.tasks.clear()
	plan.add_mission("gather_herbs", _team(["a"]))
	assert_has(plan.validate(sect), "injured_must_rest:a")


func test_teams_need_one_to_four_disciples_and_a_real_mission() -> void:
	var sect := SimFixtures.sect([
		SimFixtures.disciple("a"), SimFixtures.disciple("b"), SimFixtures.disciple("c"),
		SimFixtures.disciple("d"), SimFixtures.disciple("e"),
	])
	var plan := DayPlan.new()
	plan.missions.append({"mission": "hunt_monster", "team": ["a", "b", "c", "d", "e"]})
	plan.missions.append({"mission": "find_dragon", "team": []})
	var errors := plan.validate(sect)
	assert_has(errors, "team_size:hunt_monster")
	assert_has(errors, "unknown_mission:find_dragon")
	assert_has(errors, "team_size:find_dragon")


func test_nobody_can_be_in_two_places() -> void:
	var sect := SimFixtures.sect()
	var plan := DayPlan.new()
	plan.tasks["a"] = "train"
	plan.missions.append({"mission": "gather_herbs", "team": ["a"]})
	assert_has(plan.validate(sect), "double_booked:a")


func test_adding_a_mission_moves_the_team_off_their_tasks() -> void:
	var sect := SimFixtures.sect()
	var plan := SimFixtures.plan_all(sect, "work")
	plan.add_mission("gather_herbs", _team(["a", "b"]))
	assert_eq(plan.validate(sect), [] as Array[String])
	assert_eq([plan.task_of("a"), plan.task_of("c")], ["mission", "work"])
	plan.set_task("a", "rest")
	assert_eq(plan.missions[0]["team"], ["b"])


func test_disciples_away_or_unknown_cannot_be_planned() -> void:
	var sect := SimFixtures.sect()
	var away := ActiveMission.new()
	away.mission = "gather_herbs"
	away.team = _team(["a"])
	away.return_day = 5
	sect.missions.append(away)
	var plan := DayPlan.new()
	plan.tasks["a"] = "train"
	plan.tasks["ghost"] = "train"
	plan.tasks["b"] = "dance"
	var errors := plan.validate(sect)
	assert_has(errors, "away:a")
	assert_has(errors, "unknown_disciple:ghost")
	assert_has(errors, "bad_task:b")


func test_defaults_repeat_yesterday_and_rest_the_injured() -> void:
	var sect := SimFixtures.sect()
	sect.last_tasks = {"a": "train", "b": "work"}
	sect.disciple("b").injure(1)
	var plan := DayPlan.defaults(sect)
	assert_eq(plan.tasks, {"a": "train", "b": "rest", "c": "rest"})


func test_joining_a_mission_builds_one_team_per_mission() -> void:
	var sect := SimFixtures.sect()
	var plan := SimFixtures.plan_all(sect, "train")
	plan.join_mission("hunt_monster", "a")
	plan.join_mission("hunt_monster", "b")
	plan.join_mission("gather_herbs", "c")
	assert_eq(plan.missions, [
		{"mission": "hunt_monster", "team": ["a", "b"]},
		{"mission": "gather_herbs", "team": ["c"]},
	])
	assert_eq([plan.mission_of("b"), plan.mission_of("c")], ["hunt_monster", "gather_herbs"])
	plan.join_mission("gather_herbs", "b")
	assert_eq(plan.missions[0]["team"], ["a"])
	assert_eq(plan.validate(sect), [] as Array[String])
