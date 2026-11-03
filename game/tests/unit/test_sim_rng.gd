extends GutTest
## SimRng must give the same rolls for the same seed, and a saved game must
## continue with exactly the rolls it would have had without saving.


func _rolls(rng: SimRng, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for i in count:
		rolls.append(rng.randi_range(0, 1_000_000))
	return rolls


func test_same_seed_gives_same_rolls() -> void:
	assert_eq(_rolls(SimRng.new(42), 20), _rolls(SimRng.new(42), 20))


func test_different_seeds_give_different_rolls() -> void:
	assert_ne(_rolls(SimRng.new(1), 20), _rolls(SimRng.new(2), 20))


func test_saved_state_resumes_after_json_round_trip() -> void:
	var rng := SimRng.new(123456789)
	_rolls(rng, 7) # play a few days before saving
	var saved_json := JSON.stringify(rng.to_dict())
	var expected := _rolls(rng, 20)

	var restored := SimRng.from_dict(JSON.parse_string(saved_json))

	assert_eq(_rolls(restored, 20), expected)


func test_randi_range_stays_inside_bounds() -> void:
	var rng := SimRng.new(7)
	var out_of_bounds := 0
	for i in 500:
		var roll := rng.randi_range(-3, 3)
		if roll < -3 or roll > 3:
			out_of_bounds += 1
	assert_eq(out_of_bounds, 0)


func test_chance_of_zero_never_happens_and_one_always_happens() -> void:
	var rng := SimRng.new(99)
	var zero_hits := 0
	var one_hits := 0
	for i in 200:
		if rng.chance(0.0):
			zero_hits += 1
		if rng.chance(1.0):
			one_hits += 1
	assert_eq(zero_hits, 0)
	assert_eq(one_hits, 200)


func test_chance_uses_one_roll_whatever_the_probability() -> void:
	var a := SimRng.new(5)
	var b := SimRng.new(5)
	a.chance(1.0)
	b.chance(0.3)
	assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000))


func test_pick_returns_an_item_from_the_list() -> void:
	var rng := SimRng.new(11)
	var spirit_roots := ["Metal", "Wood", "Water", "Fire", "Earth"]
	var strangers := 0
	for i in 100:
		if rng.pick(spirit_roots) not in spirit_roots:
			strangers += 1
	assert_eq(strangers, 0)
