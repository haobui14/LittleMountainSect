class_name SimRng
extends RefCounted
## Deterministic random numbers for the rules engine.
##
## Every random roll in game/sim goes through one SimRng, so a saved game
## resumes with exactly the same luck. Store [method to_dict] in the save and
## rebuild with [method from_dict]. Seed and state are written as strings
## because JSON numbers are doubles and would lose the low bits of a 64-bit
## state.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Returns an integer between [param from] and [param to], inclusive.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Returns a float between 0.0 and 1.0, inclusive.
func randf() -> float:
	return _rng.randf()


## Returns true with the given probability (0.0 to 1.0).
## Always consumes exactly one roll, so tuning a probability later does not
## shift every roll that comes after it.
func chance(probability: float) -> bool:
	var roll := _rng.randf()
	if probability >= 1.0:
		return true
	return roll < probability


## Returns one element of a non-empty array.
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "SimRng.pick() needs at least one item")
	return items[_rng.randi_range(0, items.size() - 1)]


func to_dict() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


static func from_dict(data: Dictionary) -> SimRng:
	var restored := SimRng.new(String(data["seed"]).to_int())
	restored._rng.state = String(data["state"]).to_int()
	return restored
